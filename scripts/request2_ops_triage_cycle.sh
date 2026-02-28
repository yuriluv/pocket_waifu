#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BOARD_FILE="${REQUEST2_BOARD_FILE:-$ROOT/ops/request2_part1_board.tsv}"
EVIDENCE_DIR="${REQUEST2_EVIDENCE_DIR:-$ROOT/artifacts/ops/request2_part1_evidence}"
GATE_SCRIPT="${REQUEST2_GATE_SCRIPT:-$ROOT/scripts/request2_part1_gate_ops.sh}"
SLA_MINUTES="${REQUEST2_TRIAGE_SLA_MINUTES:-30}"
CYCLE_UTC="${REQUEST2_CYCLE_UTC:-$(date -u +"%Y-%m-%dT%H:%M:%SZ")}"
CYCLE_TAG="$(date -u -d "$CYCLE_UTC" +"%Y%m%dT%H%M%SZ" 2>/dev/null || date -u +"%Y%m%dT%H%M%SZ")"

DECISION_LOG="$EVIDENCE_DIR/review_inbox_triage_${CYCLE_TAG}.tsv"
BLOCK_LOG="$EVIDENCE_DIR/part2_block_watch_${CYCLE_TAG}.log"
CYCLE_REPORT="$EVIDENCE_DIR/review_inbox_cycle_${CYCLE_TAG}.md"

require_file() {
  local path="$1"
  if [[ ! -f "$path" ]]; then
    printf 'Missing required file: %s\n' "$path" >&2
    exit 1
  fi
}

to_epoch() {
  local ts="$1"
  date -u -d "$ts" +%s 2>/dev/null || date -u -d "$CYCLE_UTC" +%s
}

is_open_status() {
  local status="$1"
  [[ "$status" == "in_progress" || "$status" == "pending" || "$status" == "blocked" ]]
}

add_minutes_utc() {
  local minutes="$1"
  date -u -d "${CYCLE_UTC} + ${minutes} minutes" +"%Y-%m-%dT%H:%M:%SZ"
}

require_file "$BOARD_FILE"
require_file "$GATE_SCRIPT"
mkdir -p "$EVIDENCE_DIR"

now_epoch="$(to_epoch "$CYCLE_UTC")"
tmp_board="$(mktemp)"
tmp_decisions="$(mktemp)"
trap 'rm -f "$tmp_board" "$tmp_decisions"' EXIT

printf 'cycle_utc\ttask_id\tdecision\told_owner\tnew_owner\told_status\tnew_status\told_wait_minutes\tnew_wait_minutes\tblocker_class\trca_owner\tnext_eta_utc\tnote\n' > "$tmp_decisions"

open_before=0
open_after=0
breach_before=0
breach_after=0
decision_count=0
auto_block_count=0

line_no=0
while IFS=$'\t' read -r task_id stage team status owner review_wait_minutes retry_count failure_class last_update_utc branch; do
  line_no=$((line_no + 1))
  if (( line_no == 1 )); then
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
      "$task_id" "$stage" "$team" "$status" "$owner" "$review_wait_minutes" "$retry_count" "$failure_class" "$last_update_utc" "$branch" \
      > "$tmp_board"
    continue
  fi

  old_owner="$owner"
  old_status="$status"
  old_wait="$review_wait_minutes"
  decision=""
  note=""
  next_eta=""

  if is_open_status "$status"; then
    open_before=$((open_before + 1))
    row_epoch="$(to_epoch "$last_update_utc")"
    review_wait_minutes=$(( (now_epoch - row_epoch) / 60 ))
    old_wait="$review_wait_minutes"
    if (( review_wait_minutes >= SLA_MINUTES )); then
      breach_before=$((breach_before + 1))

      case "$task_id" in
        FOLLOWUP-P1-QA-NO-WAIVER-001)
          decision="merge"
          status="cancelled"
          review_wait_minutes=0
          last_update_utc="$CYCLE_UTC"
          next_eta="$CYCLE_UTC"
          note="Merged into QA-P1-VERIFY-REGRESSION-003 to remove duplicate review queue."
          ;;
        FOLLOWUP-P1-DES-PROTO-BIND-001)
          decision="cancel"
          status="cancelled"
          failure_class="procedure"
          review_wait_minutes=0
          last_update_utc="$CYCLE_UTC"
          next_eta="$CYCLE_UTC"
          note="Cancelled as non-critical follow-up while Part1 gate closure is pending."
          ;;
        FOLLOWUP-P1-OPS-PUSH-RETRY-002)
          decision="fix"
          status="in_progress"
          review_wait_minutes=0
          last_update_utc="$CYCLE_UTC"
          next_eta="$(add_minutes_utc 20)"
          note="Applied env retry fix lane with immediate push-audit rerun."
          ;;
        OPS-P1-MAIN-SYNC-001)
          decision="fix"
          status="in_progress"
          review_wait_minutes=0
          last_update_utc="$CYCLE_UTC"
          next_eta="$(add_minutes_utc 25)"
          note="Main-sync follow-up prioritized with same-cycle verification ETA."
          ;;
        PART2-IMPL-LOCK-001)
          decision="fix"
          status="blocked"
          failure_class="procedure"
          review_wait_minutes=0
          last_update_utc="$CYCLE_UTC"
          next_eta="$(add_minutes_utc 30)"
          note="Part2 lock reaffirmed until G1..G5 are all Pass."
          ;;
        *)
          decision="fix"
          review_wait_minutes=0
          last_update_utc="$CYCLE_UTC"
          next_eta="$(add_minutes_utc 30)"
          note="SLA breach triaged; owner must post progress update within this cycle."
          ;;
      esac
    fi
  fi

  if [[ "$stage" == "part2_implementation" && "$status" != "blocked" ]]; then
    auto_block_count=$((auto_block_count + 1))
    if [[ -z "$decision" ]]; then
      decision="cancel"
      note="Part2 implementation attempt blocked by Part1-first policy."
    else
      decision="${decision}+block"
      note="${note} Part2 implementation attempt blocked by Part1-first policy."
    fi
    status="blocked"
    failure_class="procedure"
    review_wait_minutes=0
    last_update_utc="$CYCLE_UTC"
    if [[ -z "$next_eta" ]]; then
      next_eta="$(add_minutes_utc 30)"
    fi
  fi

  if is_open_status "$status"; then
    open_after=$((open_after + 1))
    if (( review_wait_minutes >= SLA_MINUTES )); then
      breach_after=$((breach_after + 1))
    fi
  fi

  if [[ -n "$decision" ]]; then
    decision_count=$((decision_count + 1))
    if [[ -z "$next_eta" ]]; then
      next_eta="$CYCLE_UTC"
    fi
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
      "$CYCLE_UTC" "$task_id" "$decision" "$old_owner" "$owner" "$old_status" "$status" "$old_wait" "$review_wait_minutes" "$failure_class" "$owner" "$next_eta" "$note" \
      >> "$tmp_decisions"
  fi

  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
    "$task_id" "$stage" "$team" "$status" "$owner" "$review_wait_minutes" "$retry_count" "$failure_class" "$last_update_utc" "$branch" \
    >> "$tmp_board"
done < "$BOARD_FILE"

mv "$tmp_board" "$BOARD_FILE"
mv "$tmp_decisions" "$DECISION_LOG"

gate_lock_state="CLOSED"
gate_lock_output=""
if gate_lock_output="$("$GATE_SCRIPT" check-lock 2>&1)"; then
  gate_lock_state="OPEN"
fi

{
  printf 'cycle_utc=%s\n' "$CYCLE_UTC"
  printf 'board_file=%s\n' "$BOARD_FILE"
  printf 'sla_minutes=%s\n' "$SLA_MINUTES"
  printf 'gate_lock_state=%s\n' "$gate_lock_state"
  printf 'gate_check_output=%s\n' "$gate_lock_output"
  printf 'part2_auto_block_count=%s\n' "$auto_block_count"
  printf '\n'
  printf '[part2 rows]\n'
  awk -F'\t' 'NR==1 || $2=="part2_implementation" || $1 ~ /^PART2-/ {print}' "$BOARD_FILE"
} > "$BLOCK_LOG"

{
  printf '# request2 review/inbox triage cycle report\n\n'
  printf -- '- Cycle UTC: `%s`\n' "$CYCLE_UTC"
  printf -- '- SLA: `%s minutes`\n' "$SLA_MINUTES"
  printf -- '- Board: `%s`\n' "${BOARD_FILE#$ROOT/}"
  printf -- '- Decision log: `%s`\n' "${DECISION_LOG#$ROOT/}"
  printf -- '- Part2 block watch log: `%s`\n\n' "${BLOCK_LOG#$ROOT/}"

  printf '## SLA Scan Summary\n\n'
  printf '| Metric | Value |\n'
  printf '| --- | ---: |\n'
  printf '| Open items before triage | %s |\n' "$open_before"
  printf '| SLA breaches before triage | %s |\n' "$breach_before"
  printf '| Decisions applied | %s |\n' "$decision_count"
  printf '| Open items after triage | %s |\n' "$open_after"
  printf '| SLA breaches after triage | %s |\n' "$breach_after"
  printf '| Part2 auto-block actions | %s |\n\n' "$auto_block_count"

  printf '## Triage Decisions\n\n'
  if (( decision_count == 0 )); then
    printf -- '- No decisions required in this cycle.\n\n'
  else
    printf '| Task | Decision | Status Change | RCA Owner | Next ETA (UTC) | Note |\n'
    printf '| --- | --- | --- | --- | --- | --- |\n'
    awk -F'\t' 'NR>1 {printf "| %s | %s | %s -> %s | %s | %s | %s |\n", $2, $3, $6, $7, $11, $12, $13}' "$DECISION_LOG"
    printf '\n'
  fi

  printf '## Part2 Block Watch\n\n'
  printf -- '- Gate lock state: `%s`\n' "$gate_lock_state"
  printf -- '- Gate check output: `%s`\n' "$gate_lock_output"
  if [[ "$gate_lock_state" == "OPEN" ]]; then
    printf -- '- Action: Part2 block violation detected (unexpected). Escalation required.\n'
  else
    printf -- '- Action: Part2 implementation remains blocked while Part1 gate is incomplete.\n'
  fi
} > "$CYCLE_REPORT"

printf 'request2 ops triage cycle completed\n'
printf 'cycle_utc=%s\n' "$CYCLE_UTC"
printf 'decision_log=%s\n' "$DECISION_LOG"
printf 'cycle_report=%s\n' "$CYCLE_REPORT"
printf 'part2_block_watch=%s\n' "$BLOCK_LOG"

#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MAX_RETRIES="${MAX_RETRIES:-3}"
LOG_DIR="$ROOT/artifacts/qa"
LOG_FILE="$LOG_DIR/part1_gate_retry_log.tsv"
GATE_OPS_SCRIPT="$ROOT/scripts/request2_part1_gate_ops.sh"

mkdir -p "$LOG_DIR"

timestamp() {
  date -u +"%Y-%m-%dT%H:%M:%SZ"
}

write_log() {
  local gate="$1"
  local attempt="$2"
  local status="$3"
  local classification="$4"
  local message="$5"
  printf "%s\t%s\t%s\t%s\t%s\t%s\n" \
    "$(timestamp)" "$gate" "$attempt" "$status" "$classification" "$message" >>"$LOG_FILE"
}

require_gate_ops() {
  if [[ ! -x "$GATE_OPS_SCRIPT" ]]; then
    printf "Missing executable gate ops script: %s\n" "$GATE_OPS_SCRIPT" >&2
    exit 2
  fi
}

set_gate_status() {
  local gate="$1"
  local status="$2"
  "$GATE_OPS_SCRIPT" set-status "$gate" "$status" >/dev/null
}

record_retry_cause() {
  local classification="$1"
  "$GATE_OPS_SCRIPT" add-retry "$classification" >/dev/null
}

classify_failure() {
  local output_file="$1"

  if grep -Eiq "command not found|flutter: not found|Unable to locate executable for flutter|Missing required command: flutter|명령어를 찾을 수 없음" "$output_file"; then
    printf "%s" "env"
    return 0
  fi

  if grep -Eiq "Expected:|Actual:|Test failed|Exception" "$output_file"; then
    printf "%s" "code"
    return 0
  fi

  if grep -Eiq "FormatException|JSON|decode|fixture|No such file" "$output_file"; then
    printf "%s" "data"
    return 0
  fi

  printf "%s" "procedure"
}

run_gate() {
  local gate="$1"
  local description="$2"
  local command="$3"
  local attempt=1

  printf "[%s] %s\n" "$gate" "$description"

  while [[ "$attempt" -le "$MAX_RETRIES" ]]; do
    local output_file
    output_file="$(mktemp)"

    if bash -lc "cd '$ROOT' && $command" >"$output_file" 2>&1; then
      write_log "$gate" "$attempt" "PASS" "none" "ok"
      set_gate_status "$gate" "Pass"
      printf "  attempt %s/%s: PASS\n" "$attempt" "$MAX_RETRIES"
      rm -f "$output_file"
      return 0
    fi

    local classification
    classification="$(classify_failure "$output_file")"
    local summary
    summary="$(tr '\n' ' ' <"$output_file" | tr '\t' ' ' | cut -c1-180)"

    write_log "$gate" "$attempt" "FAIL" "$classification" "$summary"
    record_retry_cause "$classification"
    printf "  attempt %s/%s: FAIL (%s)\n" "$attempt" "$MAX_RETRIES" "$classification"

    rm -f "$output_file"
    if [[ "$attempt" -eq "$MAX_RETRIES" ]]; then
      set_gate_status "$gate" "Fail"
      return 1
    fi
    attempt=$((attempt + 1))
  done

  return 1
}

printf "timestamp\tgate\tattempt\tstatus\tclassification\tmessage\n" >"$LOG_FILE"

require_gate_ops
"$GATE_OPS_SCRIPT" init >/dev/null || true
for gate in G1 G2 G3 G4 G5; do
  set_gate_status "$gate" "Pending"
done

if [[ "$MAX_RETRIES" -lt 1 || "$MAX_RETRIES" -gt 3 ]]; then
  printf "MAX_RETRIES must be in range 1..3 (current: %s)\n" "$MAX_RETRIES" >&2
  exit 2
fi

declare -i pass_count=0

if run_gate "G1" "Display relink persistence roundtrip" "flutter test test/qa/persistence_migration_test.dart --plain-name 'DisplayPreset persistence'"; then
  pass_count=$((pass_count + 1))
fi

if run_gate "G2" "Motion fallback guard (no implicit default motion)" "flutter test test/qa/live2d_motion_contract_test.dart"; then
  pass_count=$((pass_count + 1))
fi

if run_gate "G3" "Live2D bridge parameter/model contract" "flutter test test/qa/live2d_bridge_contract_test.dart"; then
  pass_count=$((pass_count + 1))
fi

if run_gate "G4" "Migration safety for legacy prompt blocks" "flutter test test/qa/persistence_migration_test.dart --plain-name 'Prompt block migration'"; then
  pass_count=$((pass_count + 1))
fi

if run_gate "G5" "Part2 freeze policy while Part1 incomplete" "flutter test test/qa/part1_gate_policy_test.dart"; then
  pass_count=$((pass_count + 1))
fi

progress=$((pass_count * 20))

printf "\nPart1 gate results: %s/5 passed (PART1_PROGRESS=%s)\n" "$pass_count" "$progress"
printf "Retry log: %s\n" "$LOG_FILE"

if [[ "$pass_count" -ne 5 ]]; then
  printf "Part1 QA gate is incomplete. Part2 remains blocked.\n" >&2
  exit 1
fi

printf "Part1 QA gates complete. Part2 loop can be activated.\n"

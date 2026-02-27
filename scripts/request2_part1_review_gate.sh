#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MODE="pre-merge"
PR_BODY_FILE=""
REVIEWER_COUNT=""

log() {
  printf '%s\n' "$*"
}

fail() {
  log "PART1 REVIEW GATE: FAIL - $*"
  exit 1
}

usage() {
  cat <<EOF
Usage:
  $(basename "$0") --pr-body-file <path> [--mode pre-merge|post-merge] [--reviewer-count <n>]

Validation targets:
  1) Review comment triage table (CRITICAL/FUNCTIONAL/STYLE)
  2) Reviewer SLA table (2 reviewers, each <= 30 minutes)
  3) Commit evidence order (fix -> review-reflect -> main merge)
  4) Root cause tags (code/env/data/procedure)
EOF
}

trim() {
  printf '%s' "$1" | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//'
}

normalize_text() {
  printf '%s' "$1" | tr '[:upper:]' '[:lower:]'
}

extract_field_value() {
  local field="$1"
  local file="$2"
  local line
  line="$(grep -Eim1 "^[[:space:]-]*${field}[[:space:]]*:" "$file" || true)"
  if [[ -z "$line" ]]; then
    printf ''
    return 0
  fi
  printf '%s' "$line" | sed -E "s/^[[:space:]-]*${field}[[:space:]]*:[[:space:]]*//I" | tr -d '\r'
}

require_section() {
  local header="$1"
  local file="$2"
  grep -Fxq "## ${header}" "$file" || fail "Missing section header: ## ${header}"
}

extract_section() {
  local header="$1"
  local file="$2"
  awk -v target="$header" '
    BEGIN { in_section = 0 }
    $0 == "## " target { in_section = 1; next }
    in_section && $0 ~ /^## / { exit }
    in_section { print }
  ' "$file" | sed 's/\r$//'
}

validate_sha_exists() {
  local label="$1"
  local sha="$2"
  if [[ ! "$sha" =~ ^[0-9a-fA-F]{7,40}$ ]]; then
    fail "${label} must be a git commit SHA (7-40 hex chars). Current: '${sha}'"
  fi
  if ! git -C "$ROOT" rev-parse --verify "${sha}^{commit}" >/dev/null 2>&1; then
    fail "${label} does not exist in local git graph: ${sha}"
  fi
}

validate_reviewer_sla() {
  local pr_file="$1"
  local section
  section="$(extract_section "Reviewer SLA (2 reviewers, <=30m)" "$pr_file")"
  [[ -n "$section" ]] || fail "Reviewer SLA section content is empty."

  local table_rows
  table_rows="$(printf '%s\n' "$section" | awk -F'|' '
    /^\|/ {
      if ($0 ~ /Reviewer/ || $0 ~ /-[-[:space:]]+\|/) { next }
      print
    }'
  )"
  [[ -n "$table_rows" ]] || fail "Reviewer SLA table has no reviewer rows."

  local row_count
  row_count="$(printf '%s\n' "$table_rows" | sed '/^[[:space:]]*$/d' | wc -l | tr -d ' ')"
  if (( row_count < 2 )); then
    fail "Reviewer SLA table must include at least 2 reviewers. Current: ${row_count}"
  fi

  local bad=0
  local seen=0
  while IFS= read -r row; do
    [[ -z "$(trim "$row")" ]] && continue
    seen=$((seen + 1))

    local reviewer request_at approved_at sla_min
    reviewer="$(trim "$(printf '%s' "$row" | awk -F'|' '{print $2}')")"
    request_at="$(trim "$(printf '%s' "$row" | awk -F'|' '{print $3}')")"
    approved_at="$(trim "$(printf '%s' "$row" | awk -F'|' '{print $4}')")"
    sla_min="$(trim "$(printf '%s' "$row" | awk -F'|' '{print $5}')")"

    if [[ -z "$reviewer" || "$reviewer" == "TBD" ]]; then
      log "Invalid reviewer row: reviewer is empty/TBD"
      bad=1
    fi
    if [[ -z "$request_at" || "$request_at" == "TBD" || -z "$approved_at" || "$approved_at" == "TBD" ]]; then
      log "Invalid reviewer row (${reviewer}): missing request/approval timestamp"
      bad=1
    fi
    if [[ ! "$sla_min" =~ ^[0-9]+$ ]]; then
      log "Invalid reviewer row (${reviewer}): SLA must be integer minutes"
      bad=1
      continue
    fi
    if (( sla_min > 30 )); then
      log "Invalid reviewer row (${reviewer}): SLA ${sla_min} > 30 minutes"
      bad=1
    fi
  done <<< "$table_rows"

  if (( bad != 0 || seen < 2 )); then
    fail "Reviewer SLA validation failed."
  fi
}

validate_triage_table() {
  local pr_file="$1"
  local section
  section="$(extract_section "Review Comment Triage" "$pr_file")"
  [[ -n "$section" ]] || fail "Review Comment Triage section content is empty."

  for category in CRITICAL FUNCTIONAL STYLE; do
    if ! printf '%s\n' "$section" | grep -Eqi "\|[[:space:]]*${category}[[:space:]]*\|"; then
      fail "Review Comment Triage table must include '${category}' row."
    fi
  done
}

validate_root_cause_tags() {
  local pr_file="$1"
  local section
  section="$(extract_section "Root Cause Tags" "$pr_file")"
  [[ -n "$section" ]] || fail "Root Cause Tags section content is empty."

  local selected
  selected="$(printf '%s\n' "$section" | grep -Eio '^[[:space:]-]*\[[xX]\][[:space:]]*(code|env|data|procedure)[[:space:]]*$' || true)"
  [[ -n "$selected" ]] || fail "At least one root cause tag must be selected among code/env/data/procedure."
}

validate_commit_evidence() {
  local pr_file="$1"
  local fix_sha review_sha merge_sha

  fix_sha="$(trim "$(extract_field_value "Fix commit SHA" "$pr_file")")"
  review_sha="$(trim "$(extract_field_value "Review-reflect commit SHA" "$pr_file")")"
  merge_sha="$(trim "$(extract_field_value "Main merge SHA" "$pr_file")")"

  [[ -n "$fix_sha" ]] || fail "Fix commit SHA is required."
  [[ -n "$review_sha" ]] || fail "Review-reflect commit SHA is required."
  [[ -n "$merge_sha" ]] || fail "Main merge SHA is required. Use PENDING only in pre-merge mode."

  validate_sha_exists "Fix commit SHA" "$fix_sha"
  validate_sha_exists "Review-reflect commit SHA" "$review_sha"

  if ! git -C "$ROOT" merge-base --is-ancestor "$fix_sha" "$review_sha"; then
    fail "Commit order violation: fix commit must be an ancestor of review-reflect commit."
  fi

  local merge_sha_lc
  merge_sha_lc="$(normalize_text "$merge_sha")"
  if [[ "$merge_sha_lc" == "pending" ]]; then
    if [[ "$MODE" == "post-merge" ]]; then
      fail "Main merge SHA cannot be PENDING in post-merge mode."
    fi
    return 0
  fi

  validate_sha_exists "Main merge SHA" "$merge_sha"
  if ! git -C "$ROOT" merge-base --is-ancestor "$review_sha" "$merge_sha"; then
    fail "Commit order violation: review-reflect commit must be an ancestor of main merge SHA."
  fi
}

main() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --mode)
        MODE="${2:-}"
        shift 2
        ;;
      --pr-body-file)
        PR_BODY_FILE="${2:-}"
        shift 2
        ;;
      --reviewer-count)
        REVIEWER_COUNT="${2:-}"
        shift 2
        ;;
      help|-h|--help)
        usage
        exit 0
        ;;
      *)
        usage
        fail "Unknown argument: $1"
        ;;
    esac
  done

  [[ "$MODE" == "pre-merge" || "$MODE" == "post-merge" ]] || fail "Invalid --mode '${MODE}'. Use pre-merge or post-merge."
  [[ -n "$PR_BODY_FILE" ]] || fail "--pr-body-file is required."
  [[ -f "$PR_BODY_FILE" ]] || fail "PR body file not found: $PR_BODY_FILE"

  require_section "Part1 Scope Lock" "$PR_BODY_FILE"
  require_section "Review Comment Triage" "$PR_BODY_FILE"
  require_section "Reviewer SLA (2 reviewers, <=30m)" "$PR_BODY_FILE"
  require_section "Commit Evidence" "$PR_BODY_FILE"
  require_section "Root Cause Tags" "$PR_BODY_FILE"
  require_section "QA Gate Evidence (G1~G5, max 3 retries)" "$PR_BODY_FILE"

  grep -Eqi 'single[[:space:]-]*pr' "$PR_BODY_FILE" || fail "Part1 Scope Lock must explicitly state Single PR path."

  validate_triage_table "$PR_BODY_FILE"
  validate_reviewer_sla "$PR_BODY_FILE"
  validate_root_cause_tags "$PR_BODY_FILE"
  validate_commit_evidence "$PR_BODY_FILE"

  if [[ -n "$REVIEWER_COUNT" ]]; then
    if [[ ! "$REVIEWER_COUNT" =~ ^[0-9]+$ ]]; then
      fail "--reviewer-count must be an integer."
    fi
    if (( REVIEWER_COUNT < 2 )); then
      fail "Requested reviewer count must be at least 2. Current: ${REVIEWER_COUNT}"
    fi
  fi

  log "PART1 REVIEW GATE: PASS"
}

main "$@"

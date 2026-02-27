#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STEP="${1:-all}"

log() {
  printf '%s\n' "$*"
}

require_cmd() {
  local cmd="$1"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    log "Missing required command: $cmd"
    return 1
  fi
  return 0
}

run_profile() {
  log "Profile: capture environment baseline and stability signals."
  "$ROOT/scripts/stabilization_checklist.sh" --summary
  if command -v flutter >/dev/null 2>&1; then
    flutter --version
  else
    log "Flutter not found. Install Flutter to run profiling and tests."
  fi
}

run_plan() {
  log "Plan: update docs/PART2_ITERATION_LOOP.md with scope and targets."
  log "Plan: record risks and intended metrics before refactor."
}

run_refactor() {
  log "Refactor: implement targeted changes and keep scope contained."
}

run_test() {
  log "Test: running Flutter test suite."
  require_cmd flutter
  (cd "$ROOT" && flutter test)
}

run_validate() {
  log "Validate: run stabilization checklist automation."
  "$ROOT/scripts/stabilization_checklist.sh"
}

case "$STEP" in
  profile)
    run_profile
    ;;
  plan)
    run_plan
    ;;
  refactor)
    run_refactor
    ;;
  test)
    run_test
    ;;
  validate)
    run_validate
    ;;
  all)
    run_profile
    run_plan
    run_refactor
    run_test
    run_validate
    ;;
  *)
    log "Usage: $0 [profile|plan|refactor|test|validate|all]"
    exit 2
    ;;
esac

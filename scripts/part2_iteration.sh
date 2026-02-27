#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STEP="${1:-all}"
GATE_OPS_SCRIPT="$ROOT/scripts/request2_part1_gate_ops.sh"

log() {
  printf '%s\n' "$*"
}

usage() {
  cat <<EOF
Usage:
  $(basename "$0") [profile|plan|refactor|test|validate|all|board|help]

Part2 Hard Lock:
  This script is locked until Part1 gates G1..G5 are all Pass.
  Gate automation script: scripts/request2_part1_gate_ops.sh

Examples:
  $(basename "$0") all
  $(basename "$0") test
  $(basename "$0") board
EOF
}

require_gate_ops_script() {
  if [[ ! -x "$GATE_OPS_SCRIPT" ]]; then
    log "Missing executable gate ops script: $GATE_OPS_SCRIPT"
    log "Run: chmod +x $GATE_OPS_SCRIPT"
    return 1
  fi
  return 0
}

require_part2_unlock() {
  require_gate_ops_script

  if ! "$GATE_OPS_SCRIPT" check-lock >/dev/null 2>&1; then
    log "Part2 hard lock is active: G1..G5 must all be Pass."
    "$GATE_OPS_SCRIPT" show-board
    return 1
  fi
  return 0
}

show_gate_board() {
  require_gate_ops_script
  "$GATE_OPS_SCRIPT" show-board
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
    require_part2_unlock
    run_profile
    ;;
  plan)
    require_part2_unlock
    run_plan
    ;;
  refactor)
    require_part2_unlock
    run_refactor
    ;;
  test)
    require_part2_unlock
    run_test
    ;;
  validate)
    require_part2_unlock
    run_validate
    ;;
  all)
    require_part2_unlock
    run_profile
    run_plan
    run_refactor
    run_test
    run_validate
    ;;
  board)
    show_gate_board
    ;;
  help|-h|--help)
    usage
    ;;
  *)
    usage
    exit 2
    ;;
esac

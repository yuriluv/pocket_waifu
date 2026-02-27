#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MODE="${1:-full}"
FAIL=0

log() {
  printf '%s\n' "$*"
}

check_file() {
  local path="$1"
  if [[ ! -f "$ROOT/$path" ]]; then
    log "Missing file: $path"
    FAIL=1
  elif [[ "$MODE" == "--summary" ]]; then
    log "OK file: $path"
  fi
}

check_rg() {
  local path="$1"
  local pattern="$2"
  if ! grep -q "$pattern" "$ROOT/$path"; then
    log "Missing pattern: $pattern in $path"
    FAIL=1
  elif [[ "$MODE" == "--summary" ]]; then
    log "OK pattern: $pattern in $path"
  fi
}

check_file "lib/features/live2d/data/services/live2d_native_bridge.dart"
check_rg "lib/features/live2d/data/services/live2d_native_bridge.dart" "stateSync"
check_rg "lib/features/live2d/data/services/live2d_native_bridge.dart" "setStateSyncCallback"

check_file "android/app/src/main/kotlin/com/example/flutter_application_1/live2d/overlay/Live2DOverlayService.kt"
check_rg "android/app/src/main/kotlin/com/example/flutter_application_1/live2d/overlay/Live2DOverlayService.kt" "stateSync"

check_file "android/app/src/main/kotlin/com/example/flutter_application_1/live2d/renderer/Live2DGLRenderer.kt"
check_rg "android/app/src/main/kotlin/com/example/flutter_application_1/live2d/renderer/Live2DGLRenderer.kt" "Fallback"

check_file "android/app/src/main/kotlin/com/example/flutter_application_1/live2d/cubism/CubismFrameworkManager.kt"

if [[ $FAIL -ne 0 ]]; then
  log "Stabilization checklist failed."
  exit 1
fi

if [[ "$MODE" != "--summary" ]]; then
  log "Stabilization checklist passed."
fi

#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  scripts/adb_wireless_setup.sh <device-ip> [wireless-port]

Examples:
  scripts/adb_wireless_setup.sh 100.88.10.25
  scripts/adb_wireless_setup.sh 100.88.10.25 5555

Notes:
- Run once with USB attached to enable TCP mode:
    adb tcpip 5555
- Then connect over Tailscale IP from dev machine:
    adb connect <device-ip>:5555
EOF
}

if ! command -v adb >/dev/null 2>&1; then
  echo "[ERROR] adb not found in PATH"
  echo "Install Android platform-tools first."
  exit 2
fi

if [[ ${1:-} == "" ]]; then
  usage
  exit 1
fi

DEVICE_IP="$1"
PORT="${2:-5555}"
TARGET="${DEVICE_IP}:${PORT}"

echo "[INFO] Restarting adb server"
adb start-server >/dev/null

echo "[INFO] Attempting wireless connect -> ${TARGET}"
adb connect "$TARGET"

echo "[INFO] Connected devices"
adb devices -l

echo "[OK] Wireless ADB setup completed for ${TARGET}"
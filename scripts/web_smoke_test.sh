#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

if ! command -v flutter >/dev/null 2>&1; then
  echo "[ERROR] flutter not found in PATH"
  echo "Install Flutter SDK first, then re-run."
  exit 2
fi

echo "[1/4] flutter pub get"
flutter pub get

echo "[2/4] flutter analyze"
flutter analyze

echo "[3/4] dart tests"
flutter test

echo "[4/4] web build smoke"
flutter build web --release

echo "[OK] Web smoke test finished successfully."
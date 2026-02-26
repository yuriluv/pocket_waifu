#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 <json_payload_file>"
  exit 2
fi

PAYLOAD_FILE="$1"
MAX_RETRIES="${MAX_RETRIES:-4}"
BASE_DELAY_SECONDS="${BASE_DELAY_SECONDS:-3}"

if [[ ! -f "$PAYLOAD_FILE" ]]; then
  echo "[ERROR] Payload file not found: $PAYLOAD_FILE"
  exit 2
fi

if [[ -z "${RELEASE_LOG_ENDPOINT:-}" ]]; then
  echo "[ERROR] RELEASE_LOG_ENDPOINT is required"
  exit 2
fi

if [[ -z "${RELEASE_LOG_TOKEN:-}" ]]; then
  echo "[ERROR] RELEASE_LOG_TOKEN is required"
  exit 2
fi

if grep -Eqi '(AKIA|ASIA|BEGIN PRIVATE KEY|storePassword|keyPassword)' "$PAYLOAD_FILE"; then
  echo "[ERROR] Potential secret detected in payload. Refusing upload."
  exit 3
fi

TMP_RESPONSE="$(mktemp)"
trap 'rm -f "$TMP_RESPONSE"' EXIT

attempt=1
while [[ "$attempt" -le "$MAX_RETRIES" ]]; do
  status_code="$(curl -sS -o "$TMP_RESPONSE" -w '%{http_code}' \
    -X POST "$RELEASE_LOG_ENDPOINT" \
    -H "Authorization: Bearer $RELEASE_LOG_TOKEN" \
    -H 'Content-Type: application/json' \
    --connect-timeout 10 \
    --max-time 30 \
    --data-binary "@$PAYLOAD_FILE")"

  if [[ "$status_code" =~ ^2[0-9][0-9]$ ]]; then
    echo "[OK] Release log uploaded (status=$status_code)"
    exit 0
  fi

  if [[ "$status_code" =~ ^4[0-9][0-9]$ && "$status_code" != "429" ]]; then
    echo "[ERROR] Non-retryable client error from log endpoint (status=$status_code)"
    cat "$TMP_RESPONSE"
    exit 1
  fi

  if [[ "$attempt" -eq "$MAX_RETRIES" ]]; then
    echo "[ERROR] Release log upload failed after $MAX_RETRIES attempts (status=$status_code)"
    cat "$TMP_RESPONSE"
    exit 1
  fi

  sleep_seconds=$((BASE_DELAY_SECONDS * attempt))
  echo "[WARN] Upload attempt $attempt failed (status=$status_code). Retrying in ${sleep_seconds}s..."
  sleep "$sleep_seconds"
  attempt=$((attempt + 1))
done

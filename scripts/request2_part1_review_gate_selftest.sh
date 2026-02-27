#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GATE_SCRIPT="$ROOT/scripts/request2_part1_review_gate.sh"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

cat > "$TMP_DIR/ok.md" <<'EOF'
## Part1 Scope Lock
- [x] This PR is part of **Part1** only (Part2 신규 금지).
- [x] Delivery path is **Single PR** (`fix -> review-reflect -> merge`).

## Review Comment Triage
| Category | Count | Disposition | Notes |
|---|---:|---|---|
| CRITICAL | 1 | Fixed in this PR | crash path |
| FUNCTIONAL | 1 | Fixed in this PR | state restore |
| STYLE | 2 | Warning only (no code change) | naming |

## Reviewer SLA (2 reviewers, <=30m)
| Reviewer | Request Time (UTC) | Approval Time (UTC) | SLA (min) | Notes |
|---|---|---|---:|---|
| reviewer-1 | 2026-02-27T19:00:00Z | 2026-02-27T19:18:00Z | 18 | ok |
| reviewer-2 | 2026-02-27T19:01:00Z | 2026-02-27T19:20:00Z | 19 | ok |

## Commit Evidence
- Fix commit SHA: 671b418
- Review-reflect commit SHA: 6b6fd26
- Main merge SHA: PENDING

## Root Cause Tags
- [x] env
- [ ] code
- [ ] data
- [ ] procedure

## QA Gate Evidence (G1~G5, max 3 retries)
| Gate | Attempt(1-3) | Result | Cause Tag | Evidence Log |
|---|---:|---|---|---|
| G1 | 1 | PASS | env | artifacts/qa/part1_gate_retry_log.tsv |
| G2 | 1 | PASS | env | artifacts/qa/part1_gate_retry_log.tsv |
| G3 | 1 | PASS | env | artifacts/qa/part1_gate_retry_log.tsv |
| G4 | 1 | PASS | env | artifacts/qa/part1_gate_retry_log.tsv |
| G5 | 1 | PASS | env | artifacts/qa/part1_gate_retry_log.tsv |
EOF

cat > "$TMP_DIR/bad_sla.md" <<'EOF'
## Part1 Scope Lock
- [x] This PR is part of **Part1** only (Part2 신규 금지).
- [x] Delivery path is **Single PR** (`fix -> review-reflect -> merge`).

## Review Comment Triage
| Category | Count | Disposition | Notes |
|---|---:|---|---|
| CRITICAL | 0 | Fixed in this PR | |
| FUNCTIONAL | 0 | Fixed in this PR | |
| STYLE | 0 | Warning only (no code change) | |

## Reviewer SLA (2 reviewers, <=30m)
| Reviewer | Request Time (UTC) | Approval Time (UTC) | SLA (min) | Notes |
|---|---|---|---:|---|
| reviewer-1 | 2026-02-27T19:00:00Z | 2026-02-27T19:45:00Z | 45 | too late |
| reviewer-2 | 2026-02-27T19:01:00Z | 2026-02-27T19:10:00Z | 9 | ok |

## Commit Evidence
- Fix commit SHA: 671b418
- Review-reflect commit SHA: 6b6fd26
- Main merge SHA: PENDING

## Root Cause Tags
- [x] env

## QA Gate Evidence (G1~G5, max 3 retries)
| Gate | Attempt(1-3) | Result | Cause Tag | Evidence Log |
|---|---:|---|---|---|
| G1 | 1 | PASS | env | log |
EOF

chmod +x "$GATE_SCRIPT"
"$GATE_SCRIPT" --mode pre-merge --pr-body-file "$TMP_DIR/ok.md" --reviewer-count 2

if "$GATE_SCRIPT" --mode pre-merge --pr-body-file "$TMP_DIR/bad_sla.md" --reviewer-count 2; then
  echo "Expected bad_sla.md validation to fail."
  exit 1
fi

echo "request2_part1_review_gate selftest: PASS"

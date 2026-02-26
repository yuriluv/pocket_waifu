# APK Release and Logging QA Test Matrix (2026-02-26)

## Scope and Goal

- Validate that release APK artifacts are reproducible, traceable, and promotable.
- Validate that app logs are delivered reliably under normal and failure conditions.
- Block merge/release for any Critical or High severity defect in this matrix.

## Exit Criteria

1. No open Critical/High defects for release automation or log delivery.
2. All required release evidence is present and internally consistent.
3. Logging reliability scenarios (offline queue/retry/network flap) pass on target devices.
4. PII redaction checks pass for all enabled log paths.

## Environment Matrix

| ID | Axis | Values |
|---|---|---|
| ENV-01 | Build runner | Local runner, CI runner |
| ENV-02 | Device OS | Android 10, 12, 14 |
| ENV-03 | Network | Stable Wi-Fi, LTE, Offline -> Online recovery |
| ENV-04 | Build type | Debug (sanity), Release (gating) |

## Release Artifact Verification

| ID | Category | Test | Method | Expected Result | Severity |
|---|---|---|---|---|---|
| REL-01 | APK build | Deterministic output metadata | Build same commit twice in clean env | Version metadata and signing identity match policy | High |
| REL-02 | APK integrity | Checksum generation and storage | Compute SHA-256 and compare recorded value | Artifact checksum matches evidence record | Critical |
| REL-03 | Signing | Keystore/signature validation | Verify signature block and cert fingerprint | Signature is valid and fingerprint matches approved list | Critical |
| REL-04 | Traceability | Commit SHA provenance | Compare APK metadata and workflow artifact metadata | Artifact points to exact source commit | High |
| REL-05 | Promotion package | Evidence bundle completeness | Inspect release bundle | Bundle contains workflow URL, SHA, checksum, QA report, security sign-off slot | High |

## Logging Reliability and Safety

| ID | Category | Test | Method | Expected Result | Severity |
|---|---|---|---|---|---|
| LOG-01 | Delivery | Baseline successful upload | Generate test events online | Server receives all events with valid schema | High |
| LOG-02 | Queueing | Offline queue persistence | Generate events while offline, restart app, reconnect | Queued events persist and flush after reconnect | Critical |
| LOG-03 | Retry | Backoff and retry behavior | Force transient 5xx responses | Retries follow policy, no tight retry loop | High |
| LOG-04 | Idempotency | Duplicate prevention | Replay identical upload batch | No duplicate final records beyond allowed key policy | High |
| LOG-05 | Ordering | Event ordering tolerance | Burst events under unstable network | Sequence metadata remains analyzable and monotonic per session | Medium |
| LOG-06 | PII | Sensitive data redaction | Inject known sensitive strings in app flow | PII fields are masked or dropped before upload | Critical |
| LOG-07 | Fail-safe | Permanent failure handling | Force repeated 4xx rejection | App does not crash; quarantines invalid batch with diagnostics | High |

## Failure Injection Playbook (Aligned for QA)

| ID | Scenario | Injection | Primary Assertion | Severity |
|---|---|---|---|---|
| F1 | Build pipeline interruption | Stop workflow mid-build | Partial artifacts are not promoted | High |
| F2 | Signature mismatch | Use non-approved test signing config | Release gate blocks package | Critical |
| F3 | Logging endpoint outage | Return 503 for upload endpoint | Queue grows within cap and drains after recovery | Critical |
| F4 | Schema drift | Upload with missing required field | Rejected payload is quarantined; error observable | High |

## Required QA Evidence per Release Candidate

1. Test execution record with pass/fail for REL-* and LOG-* cases.
2. APK checksum report (sha256) and signature verification output.
3. Log delivery validation record (offline queue and retry scenarios included).
4. PII redaction validation screenshots/log excerpts with timestamp and device ID (masked).
5. Defect list with severity, owner, and disposition (fixed/deferred/rejected).

## Defect Triage Rules

- Critical/High: block release and require fix + re-test.
- Medium: release allowed only with explicit QA waiver and mitigation note.
- Low: can ship with backlog ticket and owner/date commitment.

## Automation Hooks (CI Recommendation)

- Gate 1: fail if checksum/signature verification step fails.
- Gate 2: fail if release evidence bundle is incomplete.
- Gate 3: fail if automated PII redaction test reports any hit.
- Gate 4: fail if log upload contract tests fail.

## Sign-off Template

- QA Owner:
- Candidate Version:
- Candidate Commit SHA:
- Test Window:
- Critical/High Open Defects: 0 (required)
- Decision: APPROVE / REJECT
- Notes:

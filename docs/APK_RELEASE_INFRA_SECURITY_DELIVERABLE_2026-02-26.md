# APK Release and Logging - Infra Security Deliverable (2026-02-26)

## Scope

- Define a minimum-secure APK release automation path for GitHub Actions.
- Define a secure release-log forwarding path to an external log server.
- Provide CRITICAL/HIGH control items that must be fixed immediately.

## Current State Review

### CRITICAL

1. No dedicated APK release workflow exists with signing, checksum generation, and immutable artifact packaging.
2. No enforced log upload gate with retry policy and payload secret screening.

### HIGH

1. Existing QA workflow did not explicitly set least-privilege token permissions.
2. Existing QA workflow had no job timeout guard.

### MEDIUM/LOW (warning only)

1. Action pinning by commit SHA is not yet enforced repository-wide.
2. Environment approval gate for production release is not yet enabled in repository settings.

## Immediate Fixes Implemented in This Task

1. Added secure release workflow: `.github/workflows/android-release-secure.yml`
   - Manual release trigger with typed inputs (`build_name`, `build_number`, `upload_logs`).
   - Android signing material loaded from GitHub Secrets at runtime only.
   - Release APK checksum (`sha256`) and build report artifact generated together.
   - Optional log upload stage with dedicated script and retry logic.
   - Cleanup stage to remove signing files after execution.
2. Added release-log uploader: `scripts/upload_release_logs.sh`
   - Requires endpoint and token env vars.
   - Rejects payload if potential secret patterns are detected.
   - Retries transient failures and 429 responses.
3. Hardened existing QA workflow: `.github/workflows/qa-quality-gates.yml`
   - Added `permissions: contents: read`.
   - Added `timeout-minutes: 20`.

## Security Control Matrix

| Control Area | Required Control | Implementation Status |
|---|---|---|
| Secrets handling | Keystore and signing credentials from encrypted CI secrets only | Implemented |
| Artifact integrity | SHA-256 checksum generated and archived with APK | Implemented |
| Token scope | Least-privilege `GITHUB_TOKEN` permissions | Implemented |
| Runtime bounds | Job timeout to prevent hung runners | Implemented |
| Log exfiltration guard | Secret-pattern check before log upload | Implemented |
| Retry resilience | Backoff retry for transient log endpoint failures | Implemented |
| Release approvals | Protected environment reviewers | Pending (repo setting) |
| Action immutability | Pin actions by full commit SHA | Pending |

## Required GitHub Secrets

- `ANDROID_KEYSTORE_BASE64`
- `ANDROID_STORE_PASSWORD`
- `ANDROID_KEY_PASSWORD`
- `ANDROID_KEY_ALIAS`
- `RELEASE_LOG_ENDPOINT`
- `RELEASE_LOG_TOKEN`

## Log Payload Contract (Release Build Report)

Uploader currently sends a compact JSON payload with:

- `git_sha`
- `run_id`
- `build_name`
- `build_number`
- `artifact`
- `checksum_file`

Do not include user content, message text, prompt content, API keys, or any PII in this payload.

## Operations Checklist (Infra/Security)

1. Configure all required secrets in GitHub Actions.
2. Enable protected environment for release workflow and require approvers.
3. Restrict log endpoint to TLS-only, allowlisted source ranges, and token rotation policy.
4. Validate each release artifact using `app-release.apk.sha256` before distribution.
5. Store workflow run URL, commit SHA, checksum file, and build report for audit evidence.

## Validation Commands (Local/CI)

```bash
flutter analyze
flutter test test/qa
```

Manual release execution is done from GitHub Actions UI through `Android Release Secure`.

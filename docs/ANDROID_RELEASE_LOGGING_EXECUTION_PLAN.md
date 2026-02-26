# Pocket Waifu Android Release + Log Collection Execution Plan (v0.1)

## 1) Goal and Non-goals

- Goal: automate release APK build/sign/version/artifact retention and add release log shipping path with batching, retry, offline queue, and PII minimization.
- Goal: keep core chat/live2d behavior unchanged; focus on infra/util/ops surfaces.
- Non-goal: app feature redesign or business workflow changes.

## 2) Architecture Draft (Planning/Ops first)

### Release pipeline (GitHub Actions)

1. Trigger: `workflow_dispatch` (manual release) or tag push `v*`.
2. Resolve version:
   - `versionName`: tag value (`v1.2.3` -> `1.2.3`) or dispatch input.
   - `versionCode`: GitHub `run_number` (monotonic).
3. Signing:
   - Decode keystore from GitHub secret (`ANDROID_KEYSTORE_BASE64`).
   - Materialize `android/key.properties` at runtime.
   - Build uses release signing config if signing inputs are present.
4. Build:
   - `flutter build apk --release --build-name --build-number`.
   - Inject log endpoint/token via `--dart-define`.
5. Artifact and integrity:
   - Upload APK + SHA256 checksum + dependency SBOM snapshot (`flutter pub deps --json`).
   - Build provenance attestation (`actions/attest-build-provenance@v2`).
6. Distribution:
   - Tag build publishes GitHub Release assets.

### Release log collection path

1. Event capture points:
   - Global unhandled Flutter errors (`FlutterError.onError`).
   - Platform uncaught errors (`PlatformDispatcher.instance.onError`).
   - API request failures/exceptions (`ApiService`).
2. Client queue:
   - Queue persisted in `SharedPreferences` (offline-safe).
   - Max queue length cap to bound storage.
3. Upload semantics:
   - Batch send (`25` events per request).
   - Exponential backoff retry (`10s` base, max `30m`).
   - Periodic flush timer (`30s`) + immediate flush on enqueue.
4. Privacy and security:
   - Whitelisted payload keys only.
   - Message/payload sanitization and truncation.
   - Token auth header support, TLS endpoint assumed (`https`).

## 3) Implemented Code/Infra Deliverables

- Workflow: `.github/workflows/android-release.yml`
- Android signing config support: `android/app/build.gradle.kts`
- Release log queue/uploader: `lib/services/release_log_service.dart`
- Global error hook wiring: `lib/main.dart`
- API failure logging integration: `lib/services/api_service.dart`

## 4) WBS (Planning/Ops -> Dev/QA split)

| ID | Owner | Task | Output | Status |
|---|---|---|---|---|
| P-01 | Planning/Ops | Architecture draft + release/logging scope freeze | this document v0.1 | Done |
| P-02 | Planning/Ops | Define approval gates before `main` merge | gate checklist section | Done |
| D-01 | Dev | GitHub Actions release automation (build/sign/version/artifact) | `android-release.yml` | Done |
| D-02 | Dev | Android release signing config (key.properties/env fallback) | gradle update | Done |
| D-03 | Dev | Log queue + batch retry + offline persistence | `release_log_service.dart` | Done |
| D-04 | Dev | Error/API instrumentation without core behavior changes | `main.dart`, `api_service.dart` | Done |
| QA-01 | QA | Reproducibility/signing/version monotonicity checks | test evidence (pending) | Pending |
| QA-02 | QA | Offline queue drain/retry/backoff/duplication checks | test evidence (pending) | Pending |
| SEC-01 | Security | Secret policy and OIDC/KMS migration hardening | follow-up backlog | Pending |
| OPS-01 | Ops | Runbook (release/rollback/incident) publishing | below runbook draft | Pending review |

## 5) Required GitHub Secrets

| Secret | Required | Purpose |
|---|---|---|
| `ANDROID_KEYSTORE_BASE64` | Yes | release keystore binary (base64) |
| `ANDROID_KEYSTORE_PASSWORD` | Yes | keystore password |
| `ANDROID_KEY_ALIAS` | Yes | key alias |
| `ANDROID_KEY_PASSWORD` | Yes | key password |
| `CUBISM_SDK_PATH` | Yes | runner path for Cubism native SDK |
| `LOG_INGEST_ENDPOINT` | Optional | app log ingestion endpoint |
| `LOG_INGEST_TOKEN` | Optional | bearer token for ingestion API |

## 6) Ops Runbook Draft

### Release procedure

1. Trigger `Android Release Pipeline` via `workflow_dispatch` with `version_name`.
2. Download artifacts (APK + SHA256 + SBOM) from workflow run.
3. Internal QA install and smoke check.
4. Approval gate sign-off (Planning + QA + Dev owner).
5. Tag `vX.Y.Z` to publish immutable release asset.

### Rollback

1. Select previous approved release artifact from GitHub release assets.
2. Re-distribute prior signed APK directly (no rebuild required).
3. Record rollback reason, impact range, and RTO (target <= 30 min).

### Incident response

1. If build/sign fails: verify secrets + keystore validity + Cubism SDK path.
2. If log ingestion spikes/fails: disable via `LOG_UPLOAD_ENABLED=false` in build, keep local queue active.
3. If ingestion auth failure: rotate token and redeploy with new `LOG_INGEST_TOKEN`.

### Security checklist

- Keystore and tokens only in Actions secrets; never committed.
- Release checksum verification required before external distribution.
- PII whitelist policy enforced in client log payload.
- Artifact attestation generated per release build.

## 7) Verification Procedure

### Dev verification

1. Run `flutter analyze`.
2. Execute local release build with dart-defines:
   - `flutter build apk --release --build-name 1.0.0 --build-number 100 --dart-define=LOG_UPLOAD_ENABLED=true --dart-define=LOG_ENDPOINT=https://example.com/ingest --dart-define=LOG_AUTH_TOKEN=token`
3. Confirm APK output and checksum generation in CI.

### QA verification (handoff)

1. Trigger both manual and tag release flows and compare version metadata.
2. Validate signing certificate fingerprint remains expected.
3. Simulate offline -> online and verify queue drains with retry backoff.
4. Confirm payload excludes non-whitelisted fields and sensitive content.

## 8) Main merge review gates

All of the below are required before `main`:

1. Dev review: workflow + gradle signing + telemetry code LGTM.
2. QA sign-off: release reproducibility + logging reliability cases pass.
3. Security sign-off: secret handling + payload policy + artifact integrity.
4. Ops sign-off: release/rollback/incident runbook published.

## 9) Risks and follow-up backlog

- Risk: `CUBISM_SDK_PATH` dependency on runner environment.  
  Backlog: hosted artifact fetch/bootstrap step for SDK path standardization.
- Risk: token-based ingestion auth only.  
  Backlog: migrate to mTLS or short-lived OIDC-issued token exchange.
- Risk: lightweight SBOM snapshot currently dependency-list based.  
  Backlog: integrate CycloneDX/SPDX generator and policy gate.
- Risk: timer-based flush is app-lifecycle dependent.  
  Backlog: add WorkManager-backed background flush for long-offline devices.

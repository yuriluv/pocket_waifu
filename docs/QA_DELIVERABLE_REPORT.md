# QA Deliverable Report (Round)

## Completed Items

1. Added automated Korean text policy checker with whitelist support.
2. Added regression/contract test suite for critical modules.
3. Added formal QA execution plan and merge checkpoints.

## Artifacts

- Policy checker: `tool/qa/check_korean_policy.dart`
- Allowlist: `tool/qa/korean_text_allowlist.json`
- Command parser contract tests: `test/qa/command_parser_contract_test.dart`
- Prompt builder regression tests: `test/qa/prompt_builder_regression_test.dart`
- Model contract tests: `test/qa/model_contract_test.dart`
- QA plan: `docs/QA_EXECUTION_PLAN.md`
- Part1 gate matrix: `docs/PART1_QA_GATE_MATRIX_2026-02-27.md`
- APK release/logging QA matrix: `docs/APK_RELEASE_QA_TEST_MATRIX_2026-02-26.md`
- APK release/logging bug template: `docs/APK_RELEASE_LOGGING_QA_BUG_REPORT_TEMPLATE.md`
- Part1 gate runner: `scripts/qa_part1_gate.sh`
- Part1 freeze policy test: `test/qa/part1_gate_policy_test.dart`
- Live2D bridge contract test: `test/qa/live2d_bridge_contract_test.dart`

## Added for APK Release/Logging Collaboration Recovery

1. Defined release-gating QA matrix for artifact integrity, signing, traceability, and log reliability.
2. Added failure-injection scenarios for pipeline interruption, signature mismatch, endpoint outage, and schema drift.
3. Added standardized defect report template to speed triage and improve auditability.

## Required Evidence Checkpoints (for PR)

1. Korean comment report is zero:
   - `dart run tool/qa/check_korean_policy.dart`
2. Static checks pass:
   - `flutter analyze`
3. Regression contracts pass:
   - `flutter test test/qa`
4. Part1 gate runbook passes with retry evidence:
   - `./scripts/qa_part1_gate.sh`

## Optional Hardening

- Enforce Korean string hard gate:
  - `dart run tool/qa/check_korean_policy.dart --strict-strings`
- Full test pass:
  - `flutter test`

## Local Execution Status in This Environment

- `dart` and `flutter` binaries are not available in the current isolated runner.
- Validation commands are prepared and documented; execution must run in CI or a developer environment with Flutter SDK installed.

## Added for Newcastle (2026-02-27)

1. Integrated planning/ops-first execution package with full requirement traceability and dependency-ordered WBS.
2. Android real-device validation matrix covering Priority 1-8 plus concurrency regression set.
3. Two-step self-review log and QA pre-validation report for release gating.

### Newcastle Artifacts

- `docs/NEWCASTLE_INTEGRATED_EXECUTION_PLAN_2026-02-27.md`
- `docs/NEWCASTLE_ANDROID_REAL_DEVICE_VALIDATION_MATRIX_2026-02-27.md`
- `docs/NEWCASTLE_SELF_REVIEW_AND_QA_REPORT_2026-02-27.md`

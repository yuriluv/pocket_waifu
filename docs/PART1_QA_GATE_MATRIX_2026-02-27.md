# Part1 QA Gate Matrix (2026-02-27)

## Scope

- Enforce Part1-first execution and block Part2 activation until all Part1 gates pass.
- Fix and unskip critical/high QA contracts for Live2D no-motion fallback and bridge behavior.
- Provide retry and root-cause classification (`code`, `env`, `data`, `procedure`) with max 3 attempts.

## Gate Matrix (G1~G5)

| Gate | Test Command | Pass Criteria | Owner | Evidence |
|---|---|---|---|---|
| G1 | `flutter test test/qa/persistence_migration_test.dart --plain-name 'DisplayPreset persistence'` | Model-linked display preset roundtrip succeeds with no assertion failure. | QA-Hawk | Test log + retry log row |
| G2 | `flutter test test/qa/live2d_motion_contract_test.dart` | Missing motion group does not trigger fallback motion; empty motion inventory handled safely. | QA-Hawk | Test log + retry log row |
| G3 | `flutter test test/qa/live2d_bridge_contract_test.dart` | Parameter/model bridge calls are contract-safe and plugin-missing path does not crash. | QA-Hawk | Test log + retry log row |
| G4 | `flutter test test/qa/persistence_migration_test.dart --plain-name 'Prompt block migration'` | Legacy prompt block migration preserves expected contract fields. | QA-Hawk | Test log + retry log row |
| G5 | `flutter test test/qa/part1_gate_policy_test.dart` | Part2 surface remains frozen while `PART1_COMPLETE != true`. | QA-Hawk | Test log + retry log row |

## Re-execution Policy

- Runner: `scripts/qa_part1_gate.sh`
- Max retries per gate: 3 (`MAX_RETRIES=1..3`)
- Log file: `artifacts/qa/part1_gate_retry_log.tsv`
- Progress formula: `PART1_PROGRESS = (passed_gates * 20)`

## Failure Cause Classification Rules

| Class | Trigger Signal (examples) | Action |
|---|---|---|
| `code` | assertion mismatch, runtime exception, contract violation | Raise defect ticket and request implementation fix, then rerun affected gate. |
| `env` | missing `flutter`/toolchain, runner permission, SDK unavailable | Escalate to ops for environment repair, rerun from failed gate. |
| `data` | invalid fixture/schema decode/input asset mismatch | Fix fixture/input mapping, rerun migration and persistence gates. |
| `procedure` | wrong command sequence, stale state, manual process drift | Reapply runbook and rerun full gate sequence. |

## Execution Command

```bash
./scripts/qa_part1_gate.sh
```

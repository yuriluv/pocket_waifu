# Request2 QA Team Deliverable (2026-02-27)

## Completed Checklist

1. [Done] Added QA supplemental subtasks from the kickoff correction memo.
   - Failure 4-category enforcement and 10-minute reproducibility SLA encoded in gate logic.
   - Part1 completion gate auto-judgment encoded.
   - Document-only completion block encoded.
2. [Done] Produced QA collaboration output package for ongoing autopilot rounds.
   - Automation script + tests.
   - Execution plan doc for quality lane.

## Deliverable Artifacts

- `tool/qa/check_request2_autopilot.dart`
- `test/qa/request2_autopilot_gate_test.dart`
- `docs/REQUEST2_QA_AUTOPILOT_EXECUTION_PLAN_2026-02-27.md`

## Gate Coverage

- Part1-first enforcement when status is not `completed`.
- Part2 loop activation enforcement when Part1 is `completed`.
- Failure category strictness: only `code|environment|data|procedure`.
- Failure reproducibility SLA: repro log capture must be <= 10 minutes.
- Part1 quality gate: functional pass + regression zero + re-run streak >= 2.
- Non-document-only completion: at least one non-`docs/` code change required.
- Main push evidence: branch must be `main`, SHA format validated.

## Validation Command Set

```bash
dart run tool/qa/check_request2_autopilot.dart <status.json>
flutter test test/qa/request2_autopilot_gate_test.dart
```

## Environment Constraint (Current Isolated Runner)

- `dart` and `flutter` are unavailable in this runner, so command execution is blocked here.
- Commands above are ready for CI or any developer machine with Flutter SDK.

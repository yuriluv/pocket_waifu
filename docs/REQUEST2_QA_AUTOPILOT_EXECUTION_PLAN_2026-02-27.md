# Request2 QA Autopilot Execution Plan (2026-02-27)

## Goal

- Operate a 30-minute QA checkpoint loop for `docs/request2.md` with Part1-first enforcement, failure recovery, and non-documentary completion controls.

## QA Supplemental Subtasks (Immediate)

1. Failure taxonomy and 10-minute reproducibility gate
   - Enforce exactly four failure categories: `code`, `environment`, `data`, `procedure`.
   - Require reproducibility log capture within 10 minutes from failure detection.
2. Part1 dedicated validation gate
   - Auto-judge Part1 completion only when all conditions pass:
     - Functional test pass.
     - Regression failures = 0.
     - Re-run success streak >= 2.
3. Document-only completion prevention
   - Require evidence package and code-change records.
   - Block close if all changed paths are under `docs/`.

## Operational QA Rules (Mapped to CEO Mandatory Rules)

- R1 Part1 priority: if Part1 is not completed, require `part1.priority=highest`.
- R2 Part2 loop handover: if Part1 is completed, require `part2.loopActive=true`.
- R3 Multi-agent concurrency: hard gate at 2+, warning/escalation at below 3.
- R4 Failure recovery: on any failure, validate category + reproducibility SLA + rerun trigger readiness.
- R5 Main reflection: require main-branch push evidence and follow-up task evidence.
- R6 Reporting posture: minimize intermediate updates; produce final gate summary centered on evidence.

## Automation Added by QA Team

- Gate script: `tool/qa/check_request2_autopilot.dart`
- Gate tests: `test/qa/request2_autopilot_gate_test.dart`

## Standard Command

```bash
dart run tool/qa/check_request2_autopilot.dart <status.json>
```

Optional strict recommendation mode:

```bash
dart run tool/qa/check_request2_autopilot.dart <status.json> --strict-agents
```

## Required Status Payload Fields

- `cycle.startedAt`, `cycle.checkedAt`
- `part1.status`, `part1.priority`, `part1.gate.*`
- `part2.loopActive`
- `agents.activeCount`
- `failures[]` with timestamps and category
- `evidence.*` with main push branch/SHA
- `codeChanges[]` with path + commit

## Exit Criteria

- Gate returns zero errors.
- Main push proof and follow-up task proof are present.
- At least one non-`docs/` code artifact exists in `codeChanges`.

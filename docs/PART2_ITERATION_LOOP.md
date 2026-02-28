# Part 2 Iteration Loop (Baseline)

This loop is the default execution path for Part 2 changes only after Part 1 is fully complete.

## Entry Guard (Hard)

- Do not start any new Part2 work while Part1 is in progress.
- Required gate state before Part2 start: `G1=Pass`, `G2=Pass`, `G3=Pass`, `G4=Pass`, `G5=Pass`.
- If any Part1 gate regresses to fail, immediately pause Part2 and return to Part1 recovery.

Hard lock: while Part 1 is not fully completed and verified, Part 2 runtime implementation changes are blocked. Only preparation artifacts (planning docs, instrumentation specs, and checklists) are allowed.

## Loop

1. Profile
2. Plan
3. Refactor
4. Test
5. Validate

## Script

Use the automation wrapper:

```bash
./scripts/part2_iteration.sh all
```

## Step Details

Profile
- Capture environment baseline and run stabilization checklist summary.
- Collect performance snapshots and logs if available.

Plan
- Record target surfaces, non-goals, and measurable checks before refactor.
- Note expected risks and rollback plan.

Refactor
- Implement only the planned deltas.
- Avoid unrelated formatting or scope drift.

Test
- Run automated tests.
- Add or update targeted tests for touched areas.

Validate
- Run stabilization checklist automation.
- Confirm no new regressions in the targeted scope.

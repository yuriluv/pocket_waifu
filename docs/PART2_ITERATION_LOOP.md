# Part 2 Iteration Loop (Baseline)

This loop is the default execution path for Part 2 changes. It is intended to keep scope tight and to preserve stability while Part 1 is still in progress.

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

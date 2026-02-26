# Non-Core Lane Coordinator Refresh (Ops Artifact)

Snapshot date: 2026-02-26

## Scope Guard

- This artifact covers only currently running non-core tasks.
- No core domain behavior changes are allowed under this coordination pass.
- Current core-exclusion examples: request/session flow, model pipeline, overlay runtime internals.

## Active Non-Core Lanes (Current)

| Lane | Owner | Branch | Status | Risk | Notes |
| --- | --- | --- | --- | --- | --- |
| Planning/Ops - Active lane rebalance + risk refresh | Lead review | N/A | In review | Medium | Waiting for review sign-off before downstream coordination lock. |
| Utility/Support - Review-stuck triage + fast-fix patchset | Bolt | `climpire/d1a686d1` | In review | Low | Review phase already started. Candidate to merge first if gates pass. |
| Utility/Convenience - Settings and helper UX upgrades | Bolt | `climpire/5ebb7ada` | In progress (restarted) | High | Previous run failed (`exit code: 1`); requires failure-cause note before merge request. |
| UI/Design - Non-core consistency pass | Nova | `climpire/ee2c7979` | In progress (restarted) | High | Previous run failed (`exit code: 1`); needs reduced-scope patch strategy. |

## Blockers and Reassignment Guidance

### Current blockers

- Planning-side blocker analysis/reassignment write-up is still blocked.
- Two non-core execution lanes were restarted after failure and do not yet have verified recovery evidence.

### Reassignment rules (operational)

1. If a lane fails twice with the same class of error, reassign to Utility/Support for a minimal fast-fix slice.
2. If a lane diff touches mixed concerns (UI + utility + refactor), split into two branches and keep one owner per slice.
3. If lead review is pending over 1 business day, assign a secondary reviewer and convert review comments to checklist items.

### Immediate lane actions

1. Utility/Convenience lane (`climpire/5ebb7ada`)
- Keep current owner.
- Require a short failure postmortem note in PR description:
  - failing command
  - first failing file or stack frame
  - fix category (test, lint, compile, runtime)

2. UI/Design lane (`climpire/ee2c7979`)
- Keep current owner.
- Enforce reduced scope: spacing/color/empty-state only.
- Reject any patch that changes core flows or command/session logic.

3. Planning blocked subtask
- Reassign temporary ownership to Ops if still blocked at next sync window.
- Deliverable is documentation-only: blocker matrix + owner mapping + ETA.

## Merge Gating Checklist (Non-Core Running Tasks)

Use all gates below before merge:

1. Scope gate
- Diff must stay non-core.
- No edits to core runtime/domain files.
- If scope boundary is unclear, require manual lead approval.

2. Failure recovery gate
- Restarted lanes must attach failure-cause evidence.
- Must show at least one clean rerun after the fix.

3. Quality gate
- Required checks defined by team QA policy must pass.
- Any skipped check must include explicit reason and follow-up owner.

4. Review gate
- At least one reviewer sign-off.
- All critical/high findings fixed before merge.
- Medium/low findings may remain as explicit warnings only.

5. Merge order gate
- Merge `Utility/Support` first if approved (unblocks review-stuck items).
- Merge `Utility/Convenience` and `UI/Design` after scope and recovery gates pass.
- Merge planning/ops docs independently; no dependency on product code merge.

## Merge Readiness Matrix

| Lane | Scope Gate | Recovery Gate | Quality Gate | Review Gate | Ready |
| --- | --- | --- | --- | --- | --- |
| Utility/Support (`climpire/d1a686d1`) | Pending | N/A | Pending | In review | No |
| Utility/Convenience (`climpire/5ebb7ada`) | Pending | Blocked | Pending | Not started | No |
| UI/Design (`climpire/ee2c7979`) | Pending | Blocked | Pending | Not started | No |

## Ops Commit Note

- This commit adds the operational planning artifact only.
- No production code or design asset changes are included.

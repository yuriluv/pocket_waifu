# request2 Part1 Gate Execution Plan (30m)

## 0. Scope and Immediate Rule

- This plan executes `docs/request2.md` Part1 first and blocks all Part2 new work until Part1 gates are done.
- Current baseline at kickoff: `PART1_PROGRESS=40`, `G1~G5=0`.
- Bottleneck focus: Live2D display edit-mode model relink persistence (container-model relation save/restore).

## 1. Operating Model (Planning/Ops/Dev/QA)

| Lane | Owner | Responsibility | SLA | Evidence |
|---|---|---|---|---|
| Planning Control | Yuri (Planning) | Gate definitions, dependency lock, freeze/unfreeze decisions | 5 min refresh | Gate board + decision log |
| Ops Control | Atlas (Ops) | Parallel queue/lock orchestration, rerun control, runtime logs | 10 min cycle | run logs + retry ledger |
| Dev Lane A | Dev-1 | Persistence schema + repository save/load correctness | continuous | commit + unit/integration output |
| Dev Lane B | Dev-2 | Relink key stability and restore mapping path | continuous | commit + repro video/log |
| Dev Lane C | Dev-3 (recommended) | Edit-mode coordinate normalization + rotation/device restore | continuous | commit + scenario checklist |
| QA Control | Hawk (QA) | Gate test matrix execution and defect triage | 10 min cycle | pass/fail matrix + defect log |

Parallel policy:

1. Minimum two active dev lanes; target three lanes to remove relink bottleneck.
2. Shared files require short lock windows; lock holder must release within 15 minutes.
3. Merge order follows gate dependency, not lane completion time.

## 2. Part1 Gate Board (G1~G5)

| Gate | Objective | Entry | Exit (Done) | Owner |
|---|---|---|---|---|
| G1 | Persistence schema and storage integrity | model config schema drafted | Versioned schema persisted, migration/fallback defined, corrupted data fallback verified | Dev Lane A + QA |
| G2 | Relink persistence reliability | G1 done | Model A/B isolation pass, relaunch restore pass, relink key stable across reload | Dev Lane B + QA |
| G3 | Edit-mode interaction completeness | G1 in progress allowed | Scale/drag/resize/save/reset/edit-indicator complete with persistence hook | Dev Lane C + QA |
| G4 | Cross-device/rotation restoration | G2 and G3 done | Normalized coordinates restore across rotation and density changes | Dev Lane C + QA |
| G5 | Integrated acceptance and main readiness | G1~G4 done | Part1 acceptance criteria full pass, defects closed, merge packet complete | Planning + Ops + QA |

## 3. 30-Minute Execution Sequence

1. Minute 0-5: Freeze Part2, open gate board, assign lanes, publish lock/retry rules.
2. Minute 5-20: Run three-lane implementation + QA shadow validation on each lane output.
3. Minute 20-25: Integrate in dependency order (G1 -> G2/G3 -> G4), run focused regression.
4. Minute 25-30: Execute G5 sign-off, prepare main-merge packet, switch to Part2 loop if and only if all gates pass.

## 4. Failure Classification and Rerun Policy

Every failure is tagged before rerun:

| Type | Definition | Immediate Action | Rerun Limit |
|---|---|---|---|
| code | Logic/schema/relink implementation defect | Fix code + add regression check | up to 3 |
| env | Device/emulator/toolchain/runtime mismatch | Stabilize environment and re-baseline | up to 3 |
| data | Corrupted/legacy/incompatible saved payload | migration/fallback patch + fixture update | up to 3 |
| procedure | Lock/order/handoff rule violation | correct runbook step + re-execute from failed gate | up to 3 |

Escalation rule:

- Same gate fails 3 times or root cause unresolved within cycle: escalate to CEO office with cause log and unblock plan before further retries.

## 5. Evidence Template (Mandatory)

For each gate:

1. Gate status (`Not Started/In Progress/Pass/Fail`).
2. Owner and timestamp.
3. Linked commit(s) and test command output summary.
4. Defect list (if any) with root-cause type (`code/env/data/procedure`).
5. Retry history and final decision.

## 6. Part2 Switch Condition

Part2 loop (`profile -> plan -> refactor -> test -> validate`) starts only when all are true:

1. `G1=Pass`, `G2=Pass`, `G3=Pass`, `G4=Pass`, `G5=Pass`.
2. Part1 acceptance criteria in `docs/request2.md` are fully satisfied.
3. Main-merge packet includes implementation evidence and QA sign-off.

If any condition is false, Part2 remains frozen.

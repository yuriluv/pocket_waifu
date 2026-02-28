# REQUEST2 Part1 Autopilot Execution Control - 2026-02-27

## 1) Goal

Keep project core goal (`GitHub: yuriluv/pocket_waifu (main)`) unchanged while completing this round with Part1-first enforcement, multi-agent parallel execution, and evidence-based closure.

## 2) Hard Constraints

1. Part1 is top priority until complete.
2. Part2 implementation is blocked before Part1 completion.
3. Minimum three agents run in parallel at all times for active execution windows.
4. Review bottleneck triage SLA is 30 minutes.
5. Failure handling is fixed loop: RCA -> fix -> rerun (max 2 retries), then escalation.

## 3) Parallel Lane Decomposition (Planning/Ops -> Implementation -> QA)

| Lane ID | Phase | Scope | Owner | Start Trigger | Done Criteria |
|---|---|---|---|---|---|
| P1-PLAN-OPS-01 | Planning/Ops | Part1 requirement freeze, gate policy, assignment map | Planning + Ops | Round kickoff | Requirement map, gate checklist, assignee log fixed |
| P1-DEV-01 | Implementation | Interface freeze + core code reflection + review unblock patch | Dev | P1-PLAN-OPS-01 baseline ready | PR/commit evidence + review-ready status |
| P1-QA-01 | QA | Part1 gate matrix, failure reproduction, rerun verification | QA | First implementation batch ready | Critical/High unresolved = 0 or escalated with owner |
| P1-OPS-TRIAGE-01 | Ops | 30-minute review queue triage and reassignment | Ops | Any PR/task wait >= 30m | Reassignment log + next ETA captured |

Minimum concurrent activation rule: `P1-PLAN-OPS-01`, `P1-DEV-01`, `P1-QA-01` must overlap during each cycle.

## 4) Review Bottleneck Triage Protocol (30-Min SLA)

1. Scan all open Part1 PR/tasks every 30 minutes.
2. If wait time >= 30 minutes and no actionable review progress:
   - classify blocker (`reviewer unavailable`, `CI failure`, `scope mismatch`, `dependency wait`)
   - reassign owner immediately
   - set new ETA within same cycle
3. Record triage evidence: timestamp, old owner, new owner, reason, ETA.
4. If reassigned task misses ETA twice, escalate to CEO/PM lane.

## 5) Failure Loop Policy (RCA -> Fix -> Rerun)

| Attempt | Required Action | Output |
|---|---|---|
| 1st fail | RCA with reproducible cause | RCA note + patch plan |
| 2nd run | Apply fix and rerun same gate | pass/fail log |
| 2nd fail | second RCA + narrowed fix | delta RCA + rerun plan |
| 3rd run fail | stop auto-retry, escalate | blocker ticket with owner + ETA + risk |

Escalation threshold: more than two failed reruns for same gate/item.

## 6) Part2 Block Gate (Before Part1 Completion)

Part2 implementation must fail-fast when any check below is unmet:

1. `Part1 completion evidence` not attached.
2. `Part1 QA sign-off` absent.
3. `Part1 review gate` incomplete.

Allowed exception while Part1 incomplete:

- Documentation for future Part2 scope.
- Instrumentation or measurement prep that does not change Part2 runtime behavior.

## 7) Code Reflection / Verification / Main Push Audit

Each cycle closes only after all three audits are explicit:

1. Code reflection: required Part1 diffs landed in working branch/PR set.
2. Verification: required QA/validation checks finished and logged.
3. Main push omission check: unmerged but required Part1 changes identified.

If any audit is missing, create follow-up tasks immediately with owner and due time.

## 8) Automatic Follow-up Task Generation Rules

Create follow-up tasks automatically when one of the events occurs:

1. Triage reassignment happened.
2. Failure loop reached second retry.
3. Validation finished but push/merge is still missing.
4. Part2-block violations detected.

Task schema:

`[request2-autopilot-30m][cycle=<UTC>] <phase>-<seq> <action> / owner / ETA / evidence-path`

## 9) Evidence Checklist (Must Attach)

1. Parallel lane activation log (>= 3 agents).
2. Triage logs (timestamp, reassignment, ETA).
3. RCA/fix/rerun chain logs for failed items.
4. Part2-block compliance log.
5. Code reflection + verification + main push audit results.

## 10) Current Round Immediate Actions

1. Keep Part1-only execution mode active until completion proof is attached.
2. Run triage cycle now for all review-blocked Part1 tasks and reassign immediately.
3. For each failed item, execute RCA -> fix -> rerun and stop at 2 retries before escalation.
4. At cycle close, generate follow-up tasks for every open audit gap.

## 11) Runner Collision Decision WBS (2026-02-28 08:17 UTC)

### Stage 1 — Incident Framing and Containment (Planning/Ops)

- **Problem statement:** request2 execution lane is blocked by runner startup failures (`spawnSync ... EAGAIN`, `spawn opencode EAGAIN`) and prior panic/segfault-style termination (`exit code: -11`).
- **Reproduction conditions to lock:**
  1. Parallel launch pressure (multiple opencode spawns in short interval).
  2. OS process/thread/file-descriptor exhaustion window.
  3. Prior orphaned process state causing immediate spawn rejection.
- **Priority:** `P0` (global lane blocker; prevents Dev/QA task throughput).
- **Containment rule:** while unresolved, enforce single active runner per owner/task lane and queue additional launches.
- **Exit criteria:** one signed incident note with reproducible trigger class + containment control applied + owner/ETA.

### Stage 2 — Decision Freeze and Work Split (Planning)

- **Decision outputs (mandatory):**
  1. Root-cause confidence level (`confirmed/probable/unknown`) for `env` vs `procedure` vs `code` path.
  2. Retry budget and escalation gate (`max 2 reruns`, third fail escalates with named blocker owner).
  3. Separation of execution tickets into independent Dev and QA tracks.
- **Governance constraints:**
  - Do not broadcast duplicated user/source wording.
  - Do not start any Part2 implementation.
  - Keep evidence attached per rerun attempt.
- **Exit criteria:** decision log published and board rows created for Dev/QA execution tracks.

### Stage 3 — Dev/QA Execution Tracks (Post-Decision)

| Track | Owner | Scope | Must-Do Outputs | Completion Criteria |
|---|---|---|---|---|
| DEV-RUNNER-HARDEN | Dev (Aria lane) | launcher resilience for EAGAIN/panic window | backoff+jitter spawn retry policy, single-flight lock, panic-safe exit classification (`env/procedure`) | 30 sequential launches pass with zero unclassified crash; blocker status downgraded |
| QA-RUNNER-STRESS | QA (Hawk lane) | deterministic reproduction + stability validation | stress matrix (`1/2/4` parallel launch profiles), evidence log, failure taxonomy verification | 2 consecutive stress cycles pass; no `EAGAIN` and no `exit -11` in captured logs |
| OPS-RUNNER-GUARD | Ops (Atlas lane) | runtime guardrails and triage SLA | launch queue control, orphan cleanup checklist, 30-minute triage snapshots | no queue starvation over one full cycle; all failed runs ticketed with owner+ETA |

### Stage Completion Definition

`request2-2026-02-28T08:17Z` planning decision is considered complete only when:

1. Stage 1 containment evidence exists.
2. Stage 2 decision record is merged into planning docs and board.
3. Stage 3 Dev/QA tracks are split and independently assignable.

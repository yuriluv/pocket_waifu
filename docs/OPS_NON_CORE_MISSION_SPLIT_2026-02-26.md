# [Ops/Planning] Non-core Improvement Mission Split
Date: 2026-02-26
Owner: Planning Team

## 1. Scope and Guardrails
- In scope: utility, support, usability, and design improvements only.
- Out of scope: core domain logic changes (API request flow, prompt composition, chat/session state model, Live2D rendering/runtime behavior).
- Delivery shape: small, low-risk increments that can be reviewed independently.

## 2. Current Backlog Snapshot (Codebase Evidence)
- UI color consistency debt is still high.
  - `lib/screens`: `Colors.*` usage 110
  - `lib/features/live2d/presentation`: `Colors.*` usage 12
- Feedback UX is partially standardized.
  - Direct `ScaffoldMessenger` calls: 13
  - `ui_feedback` helper usage: 20
- Settings surfaces are oversized and difficult to evolve safely.
  - `live2d_settings_screen.dart`: 1,358 lines
  - `settings_screen.dart`: 1,108 lines
  - `theme_editor_screen.dart`: 773 lines
- Model folder validity logic exists in service layer but is not exposed as a clear one-tap UX in settings.
  - `lib/features/live2d/data/services/live2d_storage_service.dart`
  - `lib/features/live2d/data/repositories/live2d_repository.dart`

## 3. Prioritized Mission List (Non-core Only)
| Priority | Mission ID | Category | Mission | Success Criteria |
|---|---|---|---|---|
| P0 | M1 | Utility + Usability | Live2D model-folder quick validation action in settings | 1-tap validation, explicit result state (valid/invalid + reason), no core logic side effects |
| P0 | M2 | Utility + Design | Theme accessibility contrast helper | Contrast indicator for key text/background pairs, warning UI for WCAG risk pairs |
| P1 | M3 | Support + Usability | Feedback pipeline unification (`ui_feedback`) | Remove direct snackbar pattern from target non-core screens and unify message behavior |
| P1 | M4 | Design | Non-core visual consistency pass (color/spacing/empty states) | Hardcoded color usage reduced on target screens, consistent spacing/empty-state patterns |
| P1 | M5 | Support | Settings screen modular split (view-only refactor) | Section widgets extracted without changing business outcomes |
| P2 | M6 | Support | Legacy utility consolidation (scanner/validation overlap cleanup plan) | Deprecated path documented and one canonical non-core utility path defined |

## 4. Mission Sequencing and Dependency
1. M1 and M2 first (highest user-visible value, low blast radius).
2. M3 next (standardize UX feedback before large UI consistency pass).
3. M4 after M3 (design pass leverages unified feedback and color decisions).
4. M5 in parallel with late M4 or immediately after (maintainability hardening).
5. M6 last (cleanup after behavior and UX patterns stabilize).

## 5. Implementation Checkpoints
| Checkpoint | Goal | Exit Criteria | Artifacts |
|---|---|---|---|
| CP-0 Scope Freeze | Lock non-core boundary | File-level guardrail agreed (no core domain logic touched) | This plan doc + mission labels |
| CP-1 Backlog Baseline | Freeze measurable baseline before changes | Baseline counts captured for colors/snackbar/screen size hotspots | Baseline note in PR description |
| CP-2 P0 Delivery | Ship M1 + M2 | Both missions merged with screenshot evidence and reviewer sign-off | UX evidence images + short changelog |
| CP-3 Feedback Standardization | Ship M3 | Target screens migrated to unified feedback helper | Diff summary of replaced patterns |
| CP-4 Design Consistency | Ship M4 | Priority screens pass agreed spacing/color/empty-state checklist | Design QA checklist result |
| CP-5 Maintainability | Ship M5 | Large settings files decomposed into section widgets with parity review | Refactor map + parity checklist |
| CP-6 Cleanup and Sign-off | Decide on M6 and close round | Consolidation decision recorded and remaining items re-queued | Round close report |

## 6. Review and Governance Rules
- Every mission PR must explicitly include: "Non-core only" declaration.
- Any change proposal touching core logic is redirected to separate core-track planning.
- Medium/Low review comments are logged as warnings unless they introduce regression risk.

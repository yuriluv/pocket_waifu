# Project Rules

- Do NOT run `flutter build apk --debug` for code verification or testing purposes.
- Skip APK builds during validation steps.

## Architecture Docs (Read Before Editing)

When touching a feature, read the centralized docs first, implement against those contracts, and keep docs in sync with code changes.

- `docs/QUICK_CONTEXT.md`
- `docs/START_HERE.md`
- `docs/SYSTEM_ARCHITECTURE.md`
- `docs/FEATURES/LLM_AND_PROMPTS.md`
- `docs/FEATURES/OVERLAYS.md`
- `docs/FEATURES/LIVE2D_RUNTIME.md`
- `docs/FEATURES/TRANSFORMS.md`
- `docs/FEATURES/NOTIFICATIONS.md`
- `docs/FEATURES/SCREENSHOTS.md`
- `docs/EXTENSION_PLAYBOOK.md`

Each architecture doc should preserve at least:
- Ownership / entry points
- Main runtime flow
- Cross-feature links
- Extension guidance and known risks

## Docs Gate (Mandatory For Feature Work)

For feature requests, architecture changes, runtime behavior changes, or platform integrations:

1. Read the relevant docs before editing code.
2. Treat the docs as the source of truth for ownership and runtime flow.
3. If the docs are missing or stale, update the docs first or alongside the implementation.
4. Do not finish a feature change while leaving the matching docs outdated.

## Default Delivery Workflow

For feature/bugfix implementation requests, use this execution sequence unless user explicitly asks otherwise:
1. Analyze the request and map impact scope.
2. Read the relevant architecture docs before implementation.
3. Implement and review code changes.
4. Update the matching docs so the final behavior and ownership are current.
5. Commit and push.
6. If the user explicitly wants a release, trigger the Android release pipeline via GitHub Actions (not local Flutter APK build), then report the workflow run URL and release/APK URL.

Short form:
- feature request -> docs check -> implementation -> docs update -> commit/push
- optional release only when the user explicitly wants the Android Actions release pipeline

## Response Tail Requirement

For implementation responses, end with a concise `Commit / Push / Release` status block so release readiness is always visible.

# Project Rules

- Do NOT run `flutter build apk --debug` for code verification or testing purposes.
- Skip APK builds during validation steps.

## Feature Docs (Read Before Editing)

When touching a feature, read its colocated documentation first and keep docs in sync with code changes.

- `lib/services/notification_coordinator.md`
- `lib/services/proactive_response_service.md`
- `lib/services/agent_mode_service.md`
- `lib/providers/notification_settings_provider.md`
- `lib/features/live2d/README.md`
- `lib/features/image_overlay/README.md`
- `lib/features/live2d_llm/README.md`
- `lib/features/lua/README.md`
- `lib/features/regex/README.md`

Each feature doc should cover at least:
- Overview
- Internal/main structure
- Cross-feature links
- Known risks

## Default Delivery Workflow

For feature/bugfix implementation requests, use this execution sequence unless user explicitly asks otherwise:
1. Analyze and map impact scope.
2. Implement and review code changes.
3. Commit and push.
4. Trigger Android release via GitHub Actions (not local Flutter APK build).
5. Report commit hash, workflow run URL, and release/APK URL.

## Response Tail Requirement

For implementation responses, end with a concise `Commit / Push / Release` status block so release readiness is always visible.

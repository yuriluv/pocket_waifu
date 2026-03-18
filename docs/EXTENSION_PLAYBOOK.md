# Extension Playbook

Use this document when adding or changing features.

It is written for LLM-assisted development first: the goal is to help you choose the correct ownership layer before making edits.

## Core Rule

Before editing, answer this question:

"Which layer should own this behavior?"

Use the smallest correct owner:
- screen/widget for display-only UI behavior
- provider for persistent app state and selection state
- service/coordinator for cross-feature orchestration
- feature runtime module for domain-specific behavior
- native Android code only when Flutter needs a platform capability or overlay runtime support

## Fast Routing Guide

### If the feature starts from chat UI

Start at:
- `lib/screens/chat_screen.dart`
- `lib/providers/chat_provider.dart`
- `lib/providers/chat_session_provider.dart`

### If the feature changes prompt structure or preset behavior

Start at:
- `lib/providers/prompt_block_provider.dart`
- `lib/services/prompt_builder.dart`
- `lib/screens/prompt_editor_screen.dart`

### If the feature changes model transport or provider-specific request formatting

Start at:
- `lib/models/api_config.dart`
- `lib/models/oauth_account.dart`
- `lib/providers/settings_provider.dart`
- `lib/services/api_service.dart`
- `lib/services/oauth_account_service.dart`
- `lib/screens/settings_screen.dart`

### If the feature is a text transform

Decide first:
- deterministic text rule -> regex
- programmable hook behavior or explicit host-function calls -> Lua
- runtime command encoded in assistant output -> directive service

Lua routing guardrail:
- new scripts, default templates, and shared help now target the real-runtime host-function path first
- older persisted scripts may still remain `legacyCompatible` or rely on opt-in markers during migration
- `DirectiveLuaHostApi` currently routes only overlay/live2d actions, so new host domains need runtime and adapter work, not just Lua authoring changes

Then start at:
- regex: `lib/features/regex/services/regex_pipeline_service.dart`
- Lua routing: `lib/features/lua/services/lua_scripting_service.dart`
- Lua runtime contract: `lib/features/lua/runtime/real_lua_runtime.dart`
- Lua typed host API: `lib/features/lua/runtime/lua_host_api.dart`
- Lua directive-backed adapter: `lib/features/lua/runtime/directive_lua_host_api.dart`
- Lua shared help: `lib/features/lua/lua_help_contract.dart`
- Live2D directives: `lib/features/live2d_llm/services/live2d_directive_service.dart`
- image overlay directives: `lib/features/image_overlay/services/image_overlay_directive_service.dart`

### If the feature affects Live2D or image overlay windows

Start at:
- `docs/FEATURES/OVERLAYS.md`
- `lib/features/live2d/data/services/live2d_native_bridge.dart`
- `android/app/src/main/kotlin/com/example/flutter_application_1/live2d/overlay/Live2DOverlayService.kt`

### If the feature affects model metadata, parameter presets, aliases, or auto motion

Start at:
- `docs/FEATURES/LIVE2D_RUNTIME.md`
- `lib/features/live2d/data/services/model3_json_parser.dart`
- `lib/features/live2d/data/repositories/live2d_settings_repository.dart`
- `lib/features/live2d/data/services/auto_motion_service.dart`

### If the feature affects notifications, proactive mode, or agent mode

Start at:
- `docs/FEATURES/NOTIFICATIONS.md`
- `lib/services/notification_coordinator.dart`
- `lib/services/proactive_response_service.dart`
- `lib/services/agent_mode_service.dart`

### If the feature affects screenshots or screen analysis

Start at:
- `docs/FEATURES/SCREENSHOTS.md`
- `lib/services/unified_capture_service.dart`
- `lib/providers/screen_share_provider.dart`
- Android capture plugins in `android/app/src/main/kotlin/com/example/flutter_application_1/`

## How To Add New Behavior Safely

### New screen or settings surface

Checklist:
- decide which provider owns the state
- decide whether the setting is persistent or session-local
- decide whether a service needs to react to it immediately
- wire it through `main.dart` if a long-lived service needs the provider

### New prompt-driven runtime command

Checklist:
- decide whether it belongs to Live2D or image overlay
- add parser support in the correct directive service
- if real-runtime Lua should call it directly, add/update the typed `LuaHostAction` surface and `DirectiveLuaHostApi` mapping
- add bridge support in Flutter
- add method handling in Android
- document the contract change

If Lua authoring shapes this command path, also:
- keep the real-runtime-first help/default-template examples accurate
- preserve legacy compatibility notes if older helper-based scripts still need equivalent behavior
- add/update reason-coded diagnostics expectations (`lua.exec` / `lua.diag`)
- update shared help contract text and QA drift coverage

### Lua authoring or runtime contract change

Checklist (all required in one change):
- update runtime behavior in `lib/features/lua/services/lua_scripting_service.dart`
- update `lib/features/lua/runtime/real_lua_runtime.dart` / `lib/features/lua/runtime/flutter_embed_lua_runtime.dart` if real-runtime hook execution changes
- update `lib/features/lua/runtime/lua_host_api.dart` and `lib/features/lua/runtime/directive_lua_host_api.dart` if host functions or typed domains change
- keep `LuaScript.runtimeMode` defaults, opt-in markers, and legacy compatibility behavior intentional
- update shared help source `lib/features/lua/lua_help_contract.dart` instead of editing help copies
- ensure help consumers remain aligned (`lib/services/command_parser.dart`, `lib/widgets/prompt_preview_dialog.dart`, `lib/models/settings.dart`)
- update/add QA tests that pin behavior and reason-coded diagnostics (`test/qa/lua_*`, `test/qa/help_contract_test.dart`)
- update `docs/FEATURES/TRANSFORMS.md` and any impacted architecture docs

### New notification action

Checklist:
- add Android constant
- add Android notification action builder
- normalize the action in the broadcast receiver
- bridge it into Flutter
- handle it in `NotificationCoordinator`
- update any mini-menu or overlay entry logic if needed

### New screenshot backend

Checklist:
- add new enum/value to `ScreenShareSettings`
- update `ScreenShareProvider`
- route it through `UnifiedCaptureService`
- implement Android plugin + `MainActivity` binding
- verify mini-menu screenshot send still works

## Behavior Placement Rules

### Prefer providers for

- persisted user choices
- active preset ids
- selected feature mode

### Prefer coordinators/services for

- request orchestration
- cancellation rules
- cross-feature sequencing
- shared pipelines used by multiple entrypoints

### Prefer feature modules for

- feature-specific runtime models
- file parsing
- feature-local repositories
- feature-local directive execution

### Prefer native Android only for

- notifications
- overlay windows
- Shizuku/ADB capture
- renderer/runtime code that cannot live in Flutter

## Update Discipline

When a change touches one of these contracts, update docs in the same change:
- provider ownership
- platform channel methods or payloads
- permission or capability gating
- request ordering or cancellation semantics
- preset resolution behavior
- shared overlay mode behavior
- Lua runtime-mode defaults, legacy compatibility rules, diagnostics reason-code expectations, or helper guardrails
- shared Lua help contract ownership/wording (`lib/features/lua/lua_help_contract.dart`)

## Common Traps

- Forgetting `ChatSessionProvider.runSerialized(...)` on paths that mutate chat history from background-like entrypoints.
- Adding a feature only to chat while forgetting notification reply or proactive paths.
- Changing the shared Live2D native bridge and accidentally breaking image overlay mode.
- Storing preset ids without rebinding fallback behavior.
- Treating helper-first pseudo-Lua as the main authoring target even though shipped help and defaults are now real-runtime-first.
- Assuming a new `LuaHostAction` is live without wiring `DirectiveLuaHostApi` or another host adapter.
- Implementing a directive when the behavior should have been a regex/Lua transform, or vice versa.
- Treating the mini menu as a Flutter widget instead of a native overlay contract.

## Minimal Change Workflow

1. Read `docs/START_HERE.md`.
2. Read the feature doc that owns the behavior.
3. Identify the true owner layer.
4. Make the change in the owner layer first.
5. Update dependent layers only if the contract changed.
6. Update docs and `AGENTS.md` references if needed.

## Cross-Links

- System ownership and contracts -> `docs/SYSTEM_ARCHITECTURE.md`
- LLM and prompt stack -> `docs/FEATURES/LLM_AND_PROMPTS.md`
- Overlay behavior -> `docs/FEATURES/OVERLAYS.md`
- Live2D runtime internals -> `docs/FEATURES/LIVE2D_RUNTIME.md`
- Regex/Lua transforms -> `docs/FEATURES/TRANSFORMS.md`
- Notifications and automation -> `docs/FEATURES/NOTIFICATIONS.md`
- Screenshot stack -> `docs/FEATURES/SCREENSHOTS.md`

# System Architecture

This document explains how Pocket Waifu is assembled, which layer owns which responsibility, and which platform contracts future work must respect.

## System Shape

Pocket Waifu has five architectural layers:

1. Presentation
   - Flutter screens and feature settings pages.
2. State
   - `ChangeNotifier` providers under `lib/providers/`.
3. Orchestration
   - Cross-feature services under `lib/services/`.
4. Feature Runtime
   - Feature modules under `lib/features/`.
5. Native Android
   - Method channels, broadcast receivers, notification builders, overlay service, and screenshot plugins.

The app is intentionally not split into many isolated micro-features. Several high-value paths are shared:
- Chat and notification replies reuse the same model call pipeline.
- Live2D and image overlay reuse the same native overlay channel/service.
- Screenshots reuse the same image attachment format as user-added images.

## Bootstrap Order

`lib/main.dart` is the runtime composition root.

### Immediate startup work

- Initializes `ReleaseLogService`.
- Installs Flutter and platform error handlers.
- Launches `PocketWaifuApp`.

### Provider graph created in `PocketWaifuApp`

- `SettingsProvider`
  - Owns app settings, active character, username, API presets, and the UI-facing list of linked OAuth accounts.
- `ChatProvider`
  - Owns request/response execution state for the active chat flow.
- `PromptBlockProvider`
  - Owns editable prompt block presets.
- `ChatSessionProvider`
  - Owns session list, active session, and message persistence.
- `InteractionPresetProvider`
  - Owns reusable HTML/CSS board presets for the interaction tab.
- `ThemeProvider`
  - Owns theme presets and theme mode.
- `GlobalRuntimeProvider`
  - Owns the global master on/off switch.
- `NotificationSettingsProvider`
  - Owns notification, proactive, and agent mode settings.
- `ScreenShareProvider`
  - Owns screenshot mode and capture settings.
- `ScreenCaptureProvider`
  - Mirrors `ScreenShareProvider` into an imperative capture state object.
- `PromptPresetProvider`
  - Derived provider that exposes prompt preset references from `PromptBlockProvider`.
- `AgentPromptPresetProvider`
  - Owns agent-mode prompt presets.

### Service graph created in `PocketWaifuApp`

- `Live2DGlobalRuntimeHandler`
- `ImageOverlayGlobalRuntimeHandler`
- `NotificationCoordinator`
- `ProactiveResponseService`
- `AgentModeService`
- `MiniMenuService`

Each service is attached to providers rather than reading global singletons directly. This keeps runtime wiring centralized in `main.dart`.

## UI and UX Surface Map

The primary navigation surface is `lib/screens/menu_drawer.dart`.

### Chat surfaces

- `lib/screens/chat_screen.dart`
  - Main conversation screen.
  - User text input, image attachment, command parsing, and session-aware send flow.
  - Owns the right-side interaction `endDrawer` for session-scoped variables and board rendering.
- `lib/screens/chat_list_screen.dart`
  - Session switching, naming, and deletion surface.

### Prompt surfaces

- `lib/screens/prompt_editor_screen.dart`
  - Block editor for prompt presets.
- `lib/screens/prompt_preview_screen.dart`
  - Real prompt rendering preview for the current session plus hypothetical current input.
- `lib/widgets/prompt_preview_dialog.dart`
  - Despite the filename, this is command/Lua/regex help text, not the real prompt preview engine.

### Runtime and feature surfaces

- `lib/features/live2d/presentation/screens/live2d_settings_screen.dart`
  - Live2D runtime settings, model selection, display, and behavior controls.
- `lib/features/image_overlay/presentation/screens/image_overlay_settings_screen.dart`
  - Image overlay mode, folder scanning, character/emotion selection, geometry, and hitbox presets.
- `lib/screens/live2d_llm_settings_screen.dart`
  - Live2D-LLM integration toggles and prompt capability preview.
- `lib/screens/regex_lua_management_screen.dart`
  - Regex rules, Lua scripts, and directive target selection.
- `lib/screens/screen_share_settings_screen.dart`
  - Screenshot mode, Shizuku connection status, quality, and test capture.

### Automation and notification surfaces

- `lib/screens/notification_settings_screen.dart`
  - Notification enablement, prompt/API preset selection for replies and proactive behavior, test notification UI.
- `lib/screens/agent_mode_settings_screen.dart`
  - Agent mode prompt/API preset selection, timeout, iteration count, and proactive co-configuration.
- `lib/screens/proactive_debug_screen.dart`
  - Debug surface for the proactive scheduler.

### Support surfaces

- `lib/screens/settings_screen.dart`
  - API preset list, OAuth account management, and API-adjacent utility surfaces.
  - API preset creation/editing now routes into a dedicated fullscreen editor instead of popup dialogs.
  - Gemini CLI / GCA OAuth requires user-supplied Google OAuth desktop client credentials; Codex keeps a built-in public client flow.
- `lib/screens/theme_editor_screen.dart`
  - Theme preset customization.

## State Ownership Map

### `SettingsProvider`

Owned state:
- `AppSettings`
- current `Character`
- username
- all `ApiConfig` presets and the active API preset id
- loaded `OAuthAccount` metadata used by the API settings UI

Persistence:
- `SharedPreferences`

Why it matters:
- This is the only canonical owner of API presets.
- Notification/proactive/agent flows resolve API preset ids against this provider.
- The settings UI reads OAuth accounts through this provider, while token exchange and refresh live in `OAuthAccountService`.

### `ChatSessionProvider`

Owned state:
- session list
- active session id
- all messages for all sessions
- serialized write queue via `runSerialized`
- per-session chat variables (`mainChat`, `menu`, `newChat`)
- per-session interaction HTML/CSS state and applied preset id

Persistence:
- `SharedPreferences`
- image cleanup coordination via `ImageCacheManager`

Why it matters:
- Both normal chat and notification-originated replies must write through `runSerialized` to avoid race conditions.

### `ChatProvider`

Owned state:
- loading flag
- error state
- chat request execution lifecycle

Why it matters:
- This is the normal UI chat entrypoint.
- It is not the only LLM entrypoint; notification flows use `NotificationCoordinator` instead.

### `PromptBlockProvider`

Owned state:
- prompt block presets
- active preset id
- working block list for live editing

Why it matters:
- This is the canonical prompt assembly source for chat, notifications, and proactive flows.

### `PromptPresetProvider`

Owned state:
- read-only prompt preset references derived from `PromptBlockProvider`

Why it matters:
- Other systems store preset ids, not raw prompt blocks.

### `AgentPromptPresetProvider`

Owned state:
- agent mode prompt presets containing system prompt, reply prompt, regex rules, and Lua action parsing script

Why it matters:
- Agent mode does not use normal prompt block presets.

### `NotificationSettingsProvider`

Owned state:
- `NotificationSettings`
- `ProactiveResponseSettings`
- `AgentModeSettings`

Why it matters:
- This is the canonical owner of notification, proactive, and agent-mode preset ids.
- Rebinding methods prevent stale ids after preset deletion.

### `ScreenShareProvider` and `ScreenCaptureProvider`

Owned state:
- screenshot mode and Shizuku permission state (`ScreenShareProvider`)
- capture status and last capture (`ScreenCaptureProvider`)

Why it matters:
- Capture configuration is persistent.
- Capture execution state is transient.

## Long-Lived Service Ownership

### `NotificationCoordinator`

Owner of:
- notification reply execution
- proactive response execution
- agent loop execution
- in-flight request cancellation semantics for non-chat entrypoints

Why it exists:
- Notification flows need the same model pipeline as chat, but they also need native notification updates, mini-menu actions, and request-origin-aware cancellation.

### `ProactiveResponseService`

Owner of:
- schedule parsing
- timer lifecycle
- environment-aware proactive triggering

Environment inputs:
- overlay visibility
- orientation
- screen off/on
- global runtime state

### `AgentModeService`

Owner of:
- periodic agent loop scheduling
- cancellation on user reply or session change

### `MiniMenuService`

Owner of the Flutter side of the native mini-menu contract:
- current session resolution
- message list retrieval
- mini-menu message send
- mini-menu screenshot send
- notification toggle state
- touch-through toggle state

## Persistence Boundaries

### SharedPreferences

Used for:
- app settings
- character
- username
- API presets
- prompt presets
- agent prompt presets
- notification/proactive/agent settings
- screen share settings
- regex rules
- Lua scripts
- many Live2D per-model settings and mappings

### Secure storage

Used for:
- OAuth account tokens and refresh tokens via `OAuthAccountService`

Why it exists:
- OAuth credentials are more sensitive than normal preset metadata.
- The app requires secure storage for OAuth tokens instead of silently downgrading them to plain persisted settings.
- `OAuthAccountService` also owns the provider-specific OAuth contract details, such as Codex authorize query parameters and token exchange state/PKCE handling.

### App documents directory

Used for:
- Live2D parameter preset export/import files
- per-model parameter preset JSON files

### Image cache

Used for:
- cached image attachments generated from screenshots or picked media

## Platform Channel Contracts

These channels are architectural contracts. If you change payload shape or method names, update the docs and the Flutter/native implementations together.

### Live2D / overlay channel

- Flutter side: `lib/features/live2d/data/services/live2d_native_bridge.dart`
- Android side: `android/app/src/main/kotlin/com/example/flutter_application_1/live2d/Live2DPlugin.kt`, `Live2DMethodHandler.kt`, `live2d/overlay/Live2DOverlayService.kt`
- Channel names:
  - `com.example.flutter_application_1/live2d`
  - `com.example.flutter_application_1/live2d/events`

Owns:
- overlay show/hide
- overlay mode switching
- model load/unload
- motion/expression/parameter control
- touch-through and edit mode
- display state
- runtime behavior toggles such as blink, breath, look-at, physics

### Notifications channel

- Flutter side: `lib/services/notification_bridge.dart`
- Android side: `NotificationHelper.kt`, `NotificationActionReceiver.kt`, `NotificationActionStore.kt`, `MainActivity.kt`
- Channel name: `com.example.flutter_application_1/notifications`

Owns:
- notification channel initialization
- notification posting
- clearing notifications
- draining queued actions from Android to Flutter

### Mini-menu channel

- Flutter side: `lib/services/mini_menu_service.dart`
- Android side: `live2d/overlay/Live2DOverlayService.kt`, `MainActivity.kt`
- Channel name: `com.example.flutter_application_1/mini_menu`

Owns:
- mini-menu open/close
- current session resolution
- message fetch/send
- screenshot capture-and-send entrypoint
- touch-through toggle state
- notification enable state

### Screenshot channels

- Flutter side:
  - `lib/services/adb_screen_capture_service.dart`
- Android side:
  - `AdbScreenCapturePlugin.kt`
  - `MainActivity.kt`
- Channel names:
  - `com.pocketwaifu/adb_screen_capture`

### Lua channel

- Flutter side: `lib/features/lua/services/lua_native_bridge.dart`
- Channel name: `pocketwaifu/lua`

Owns:
- hook execution
- hook execution with return value

Contract notes:
- native Lua is opportunistic; fallback pseudo-Lua remains the supported safe subset unless native availability is verifiably true at runtime
- caller behavior must remain correct under native success, native no-result, native unavailable, and native exception outcomes

### Lua diagnostics visibility

- Runtime producer: `lib/features/lua/services/lua_scripting_service.dart`
- Emitted lines:
  - `lua.exec` for stage outcomes (`native_*` and `fallback_*` reason codes)
  - `lua.diag` for bounded warning/error/guard context (`pseudo_*` reason codes)
- Current visibility:
  - in-memory diagnostics buffer via `LuaScriptingService.logs`
  - QA contract tests in `test/qa/lua_native_fallback_contract_test.dart`, `test/qa/lua_scripting_diagnostics_test.dart`, and `test/qa/pseudolua_regex_guard_test.dart`
  - compact diagnostics summary plus raw log list in `lib/screens/regex_lua_management_screen.dart`

### Lua help contract ownership

- Single source: `lib/features/lua/lua_help_contract.dart`
- Shared consumers:
  - command help (`lib/services/command_parser.dart`)
  - prompt-preview Lua help (`lib/widgets/prompt_preview_dialog.dart`)
  - default settings template hints (`lib/models/settings.dart`)

Any Lua authoring/fallback contract change must update runtime behavior, shared help contract text, and QA drift tests together.

## Permissions Matrix

### Overlay permission

Needed for:
- Live2D overlay
- image overlay
- native mini menu

Behavior when denied:
- overlay cannot be shown
- mini menu cannot be opened because it lives inside the overlay service window layer

### Notification permission

Needed for:
- Android notification posting on modern Android versions

Behavior when denied:
- `NotificationHelper` silently skips posting notifications
- enabling notifications in Flutter can fail and revert to false

### Shizuku permission

Needed for:
- ADB screenshot path via `AdbScreenCapturePlugin`

Behavior when denied:
- ADB capture fails
- settings UI exposes install/run/permission steps

### File and folder access

Needed for:
- selecting Live2D model folder or image overlay folder via Flutter file/folder pickers

## Lifecycle and Global Runtime Rules

`GlobalRuntimeProvider` controls the top-level master switch.

When global runtime is disabled:
- `GlobalRuntimeRegistry` notifies listeners.
- active notification/proactive/agent requests are cancelled.
- notification surface is cleared.
- overlay handlers can hide or suspend overlay state.

Do not treat the master switch as a UI-only flag. It is a cross-cutting runtime cancellation contract.

## High-Risk Hotspots

- `lib/services/notification_coordinator.dart`
  - Most cross-feature interactions meet here.
- `lib/features/live2d/data/services/live2d_native_bridge.dart`
  - Shared bridge for Live2D and image overlay mode control.
- `android/app/src/main/kotlin/com/example/flutter_application_1/live2d/overlay/Live2DOverlayService.kt`
  - Hosts overlay rendering, mini menu, touch-through behavior, and shared native window state.
- `lib/providers/prompt_block_provider.dart`
  - Prompt preset ownership and migration logic.
- `lib/services/api_service.dart`
  - Provider-specific request formatting, OAuth credential resolution, and prompt lifecycle transforms.
- `lib/services/oauth_account_service.dart`
  - OAuth loopback login, callback parsing, token exchange, secure persistence, refresh behavior, and Codex authorize contract parameters.

## Cross-Links

- Base LLM request flow -> `docs/FEATURES/LLM_AND_PROMPTS.md`
- Interaction tab and CBS -> `docs/FEATURES/INTERACTIONS_AND_CBS.md`
- Overlay mode and mini-menu hosting -> `docs/FEATURES/OVERLAYS.md`
- Live2D model metadata and auto motion -> `docs/FEATURES/LIVE2D_RUNTIME.md`
- Regex/Lua transforms -> `docs/FEATURES/TRANSFORMS.md`
- Notifications/proactive/agent mode -> `docs/FEATURES/NOTIFICATIONS.md`
- Screenshot capture -> `docs/FEATURES/SCREENSHOTS.md`

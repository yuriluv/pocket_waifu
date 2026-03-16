# Notifications

This document covers standard notification replies, proactive responses, agent mode, and the notification entrypoint into the native mini menu.

## Owned Code Paths

- Flutter orchestration
  - `lib/services/notification_bridge.dart`
  - `lib/services/notification_coordinator.dart`
  - `lib/services/proactive_response_service.dart`
  - `lib/services/agent_mode_service.dart`
  - `lib/providers/notification_settings_provider.dart`
  - `lib/services/mini_menu_service.dart`
- Android notification runtime
  - `android/app/src/main/kotlin/com/example/flutter_application_1/notifications/NotificationHelper.kt`
  - `android/app/src/main/kotlin/com/example/flutter_application_1/notifications/NotificationActionReceiver.kt`
  - `android/app/src/main/kotlin/com/example/flutter_application_1/notifications/NotificationActionStore.kt`
  - `android/app/src/main/kotlin/com/example/flutter_application_1/notifications/NotificationConstants.kt`
  - `android/app/src/main/kotlin/com/example/flutter_application_1/MainActivity.kt`

## Standard Notification Flow

### Outbound notification creation

1. Flutter calls `NotificationBridge.showPreResponseNotification(...)`.
2. `MainActivity` forwards that to `NotificationHelper.notifyPreResponse(...)`.
3. Android builds a high-priority notification with:
   - open-app intent
   - inline reply action
   - menu action

### Android actions

`NotificationHelper` builds two important actions:
- `Reply`
- `Menu`

`NotificationActionReceiver` converts them into normalized action payloads such as:
- `reply`
- `menu`

Those actions are sent to `NotificationActionStore`.

### Delivery back to Flutter

`NotificationActionStore` tries to dispatch the action directly into Flutter over the notifications method channel.

If Flutter is not immediately available:
- it stores the action in SharedPreferences
- later `NotificationBridge.initialize()` drains those pending actions

This is why notification actions still work even if the Flutter side was not ready at the exact tap moment.

## `NotificationCoordinator`: The Main Orchestrator

`NotificationCoordinator` is the central owner of all notification-originated request execution.

### It handles

- reply actions
- menu actions
- touch-through shortcut actions
- cancel actions
- proactive responses
- agent mode loop execution

### Important ownership boundary

It does not own settings persistence or prompt authoring. It consumes:
- `SettingsProvider`
- `PromptBlockProvider`
- `ChatSessionProvider`
- `NotificationSettingsProvider`
- `GlobalRuntimeProvider`

## Notification Reply Flow

### Flow

1. Android reply action arrives in Flutter via `NotificationBridge`.
2. `NotificationCoordinator._handleNotificationReplyInternal(...)` starts.
3. Any proactive or agent in-flight work is cancelled.
4. User-reply listeners are notified.
5. A "Responding..." notification is posted.
6. The user message is preprocessed by regex and Lua.
7. The message is stored in the active session through `ChatSessionProvider.runSerialized(...)`.
8. A prompt preset id and API preset id are resolved from notification settings.
9. The same prompt builder and API service path used by chat is reused.
10. Assistant output is post-processed through regex, Lua, and directive parsing.
11. Final text is stored in the session and sent back out as a notification.

### Critical detail

Notification replies do not invent a separate request format. They are just another caller of the shared LLM stack.

## Proactive Responses

`ProactiveResponseService` is a scheduler, not a prompt engine.

### What it owns

- schedule parsing through `ProactiveConfigParser`
- timer lifecycle through `PreResponseTimer`
- environment tracking:
  - overlay on/off
  - screen orientation
  - screen off/on
- proactive trigger gating

### Flow

1. Settings define whether proactive mode is enabled and which prompt/API preset ids to use.
2. The scheduler parses a human-authored schedule string.
3. The service adjusts timer behavior based on runtime environment.
4. On trigger, it calls `NotificationCoordinator.triggerProactiveResponse(...)`.
5. Coordinator builds a prompt with `skipInputBlock = true` and empty current input.
6. Final assistant output becomes a notification and a stored assistant message.

### Why `skipInputBlock` matters

Proactive responses are not reacting to a new user message. They are using existing context and the configured prompt structure.

## Agent Mode

`AgentModeService` is a periodic loop launcher.

### What it owns

- timer lifecycle for agent loops
- preset loading from `AgentPromptPresetProvider`
- cancellation on new user messages or session changes

### Flow

1. Agent mode interval fires.
2. Service resolves:
   - active session id
   - agent prompt preset
   - API preset
3. It calls `NotificationCoordinator.triggerAgentModeLoop(...)`.
4. Coordinator builds a direct chat-context message list and starts iterative model calls.
5. Each output is processed through agent regex rules and Lua action parsing.
6. If output resolves to `notify(...)`, a notification is posted.
7. If output resolves to `end()`, the loop stops quietly.

### Key difference from proactive mode

- proactive mode is one-shot scheduled generation with normal prompt blocks
- agent mode is iterative and action-oriented with agent-specific preset semantics

## Notification Settings Ownership

`NotificationSettingsProvider` owns three settings domains:

- `NotificationSettings`
  - on/off
  - output-as-new-notification flag
  - prompt/API preset ids for reply flow
- `ProactiveResponseSettings`
  - on/off
  - schedule text
  - prompt/API preset ids for proactive flow
- `AgentModeSettings`
  - on/off
  - prompt/API preset ids for agent mode
  - interval, timeout, max iterations

The provider also rebinds stale ids when prompt or API presets change.

## Menu Action And Mini Menu Entry

The notification "Menu" action does not open a Flutter screen.

Flow:
- Android action receiver emits `type = menu`
- `NotificationCoordinator` handles that by calling `MiniMenuService.openMiniMenu(...)`
- `MainActivity` forwards the request to the native overlay service
- Android `Live2DOverlayService` creates the actual popup menu window

This means notification popup behavior is a bridge between the notification subsystem and the overlay subsystem.

## Cancellation Rules

These rules are architecture-critical.

- user reply cancels proactive work
- user reply cancels agent mode work
- global runtime off cancels all in-flight coordinator work
- agent mode avoids overlapping with proactive work

If you change cancellation semantics, re-check all three entrypoints:
- manual reply
- proactive trigger
- agent loop

## Extension Guidance

### Add a new notification action

Update all of these together:
- Android constants and receiver
- notification builder action
- action store normalization
- Flutter bridge mapping
- `NotificationCoordinator` handler logic

### Add a new scheduled automation mode

Decide first whether it is:
- one-shot like proactive mode
- looped like agent mode

Then reuse `NotificationCoordinator` instead of creating a new request stack.

### Add a new mini-menu capability reachable from notifications

Update both:
- the native mini-menu UI
- the Flutter-side `MiniMenuService` contract and downstream owner service

## Common Failure Modes

- Forgetting that notification taps can arrive before Flutter is ready.
- Changing preset ids without using provider rebinding.
- Breaking cancellation behavior by bypassing `NotificationCoordinator`.
- Treating the notification menu as a Flutter widget instead of a native overlay.
- Mixing notification-side variable state with the main chat scope instead of using the menu-scoped CBS/session variable path.

## Cross-Links

- Shared prompt/API stack -> `docs/FEATURES/LLM_AND_PROMPTS.md`
- Menu-scoped CBS and interaction variables -> `docs/FEATURES/INTERACTIONS_AND_CBS.md`
- Native mini-menu host -> `docs/FEATURES/OVERLAYS.md`
- Screenshot send action inside the mini menu -> `docs/FEATURES/SCREENSHOTS.md`

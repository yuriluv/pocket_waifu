# Pocket Waifu Start Here

This is the canonical entrypoint for future feature work.

If you are running with a very small context window, read `docs/QUICK_CONTEXT.md` before this file.

Read this doc first if you are an LLM, agent, or engineer trying to answer one of these questions:
- Where does a user action start?
- Which provider owns a piece of state?
- Which service actually talks to the model, overlay, notifications, or screenshot layer?
- Which doc should I read next before editing?

## 90-Second Mental Model

Pocket Waifu is a provider-driven Flutter app with one shared native Android runtime surface.

- `lib/main.dart` builds the app graph.
- `ChatScreen` is the main interactive surface, but chat is only one entrypoint.
- All model calls eventually funnel through `ApiService`.
- Prompt assembly is owned by `PromptBlockProvider` + `PromptBuilder`.
- API preset generation params are now owned by each `ApiConfig`, not by a separate global settings tab.
- Text transforms are owned by the regex and Lua pipelines.
- Live2D directives and image overlay directives are post-processing layers on assistant output.
- Live2D and image overlay share the same native method channel and the same Android overlay service.
- Notifications, proactive responses, and agent mode do not have a separate LLM stack; they reuse the same prompt/API pipeline through `NotificationCoordinator`.
- Screenshots are produced through ADB/Shizuku and become normal `ImageAttachment` objects.
- The mini menu is not a Flutter widget tree. It is an Android overlay window hosted by the native overlay service and synced with Flutter over the `mini_menu` channel.

## Read Order

0. `docs/QUICK_CONTEXT.md`
   - Ultra-short map for small-context models and fast orientation.
1. `docs/SYSTEM_ARCHITECTURE.md`
   - Bootstrap order, provider graph, platform contracts, permissions, lifecycle ownership.
2. `docs/FEATURES/LLM_AND_PROMPTS.md`
   - Base LLM call flow, prompt blocks, prompt preview, presets, API preset resolution.
3. `docs/FEATURES/OVERLAYS.md`
   - Live2D mode, image overlay mode, shared native overlay behavior.
4. `docs/FEATURES/LIVE2D_RUNTIME.md`
   - Model parsing, parameter loading, aliases, presets, auto motion.
5. `docs/FEATURES/TRANSFORMS.md`
   - Regex and Lua ordering and extension rules.
6. `docs/FEATURES/NOTIFICATIONS.md`
   - Notification replies, proactive responses, agent mode, mini-menu entrypoints.
7. `docs/FEATURES/SCREENSHOTS.md`
   - ADB/Shizuku capture, screenshot mode selection, overlay hiding/restoration.
8. `docs/EXTENSION_PLAYBOOK.md`
   - Where to edit for new features and how to avoid cross-feature regressions.

## If You Need X, Start Here

- Chat request path -> `docs/FEATURES/LLM_AND_PROMPTS.md`
- Prompt block or preset change -> `docs/FEATURES/LLM_AND_PROMPTS.md`
- API preset editor or OAuth preset flow -> `docs/FEATURES/LLM_AND_PROMPTS.md` and `docs/SYSTEM_ARCHITECTURE.md`
- New provider or lifecycle question -> `docs/SYSTEM_ARCHITECTURE.md`
- New Live2D runtime command -> `docs/FEATURES/LIVE2D_RUNTIME.md` and `docs/FEATURES/OVERLAYS.md`
- New image overlay behavior -> `docs/FEATURES/OVERLAYS.md`
- Regex or Lua behavior -> `docs/FEATURES/TRANSFORMS.md`
- Notification action, proactive logic, or agent loop -> `docs/FEATURES/NOTIFICATIONS.md`
- Screenshot or capture integration -> `docs/FEATURES/SCREENSHOTS.md`
- In-app status/error feedback UX -> `lib/utils/ui_feedback.dart` and `lib/screens/chat_screen.dart`
- "Where should I add this feature?" -> `docs/EXTENSION_PLAYBOOK.md`

## Four Core Pipelines

### 1. App Bootstrap

- `lib/main.dart` registers providers, runtime handlers, notification coordinator, proactive scheduler, agent scheduler, screen capture state, and mini-menu bindings.
- Long-lived services are configured once and then react to provider updates.

### 2. Chat and LLM

- User input starts in `lib/screens/chat_screen.dart`.
- `ChatProvider` prepares the text, stores the user message, builds prompt payloads, calls `ApiService`, then post-processes assistant output.
- Prompt presets, API presets, regex, Lua, Live2D directives, and image overlay directives all converge here.

### 3. Overlays

- Flutter uses `Live2DNativeBridge` and image overlay bridges.
- Android runs one overlay service: `android/app/src/main/kotlin/com/example/flutter_application_1/live2d/overlay/Live2DOverlayService.kt`.
- That service can host a Live2D renderer, an image overlay, and the native mini menu.
- Touch-through is owned by that shared Android service; when enabled it now applies immediately instead of waiting for the app to move to the background.

### 4. Notifications and Screenshots

- Android notifications are built natively, actions are sent back to Flutter, and Flutter routes them through `NotificationCoordinator`.
- Screenshot capture uses the same attachment format as gallery/camera image input, so downstream prompt logic stays shared.

## Critical Ownership Rules

- UI ownership lives in `lib/screens/` and feature presentation folders.
- Shared transient in-app feedback lives in `lib/utils/ui_feedback.dart`; persistent chat error feedback is rendered in `lib/screens/chat_screen.dart`.
- App state ownership lives in providers under `lib/providers/`.
- Cross-feature orchestration lives in services under `lib/services/`.
- Feature-specific runtime logic lives under `lib/features/<feature>/`.
- Android native contracts live in `android/app/src/main/kotlin/com/example/flutter_application_1/`.
- If a behavior crosses Flutter and Android, treat the channel contract as part of the feature, not an implementation detail.

## Operational Notes Moved From The Old README

### Local QA Helper

```bash
scripts/web_smoke_test.sh
```

This runs Flutter dependency install, analyze, test, and release web build.

### Wireless ADB Helper

```bash
adb tcpip 5555
scripts/adb_wireless_setup.sh <tailscale-device-ip> 5555
```

Use this when working on Android overlay, notifications, or screenshot flows remotely.

## Documentation Policy

- These docs are now the canonical architecture references.
- `docs/QUICK_CONTEXT.md` is the low-context entrypoint; `docs/START_HERE.md` is the normal entrypoint.
- `AGENTS.md` points here instead of the removed scattered docs.
- If you change a contract, lifecycle rule, or ownership boundary, update the matching doc in the same change.

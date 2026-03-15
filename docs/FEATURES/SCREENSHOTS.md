# Screenshots

This document explains how ADB/Shizuku screenshot capture works, how screenshot mode selection affects overlays, and how screenshot results enter the shared message pipeline.

## Owned Code Paths

- Flutter
  - `lib/models/screen_share_settings.dart`
  - `lib/providers/screen_share_provider.dart`
  - `lib/providers/screen_capture_provider.dart`
  - `lib/services/adb_screen_capture_service.dart`
  - `lib/services/unified_capture_service.dart`
  - `lib/screens/screen_share_settings_screen.dart`
  - `lib/services/mini_menu_service.dart`
- Android
  - `android/app/src/main/kotlin/com/example/flutter_application_1/AdbScreenCapturePlugin.kt`
  - `android/app/src/main/kotlin/com/example/flutter_application_1/MainActivity.kt`

## Shared Output Format

Every screenshot returns the same logical result:
- base64 image bytes
- mime type
- width
- height

Flutter converts that into `ImageAttachment`.

This keeps chat, notification reply, and mini-menu screenshot send on the same attachment pipeline as normal image input.

## Screenshot Mode Selection

`ScreenShareSettings` owns the chosen screenshot mode:
- `includeOverlays`
- `excludeOverlays`

`ScreenShareProvider` persists the choice and tracks coarse Shizuku permission state.

`ScreenCaptureProvider` is the transient execution layer for capture status and last capture result.

## ADB / Shizuku Path

### Flutter side

- `AdbScreenCaptureService` talks to `com.pocketwaifu/adb_screen_capture`.

### Android side

- `AdbScreenCapturePlugin.kt` owns Shizuku checks and `screencap -p` execution.

### Runtime flow

1. Flutter checks whether Shizuku is installed, running, and permission-granted.
2. Android uses Shizuku to start `screencap -p`.
3. The PNG bytes are read from process output.
4. If a max resolution is configured, Android rescales the bitmap.
5. Result is returned as PNG base64 plus dimensions.
6. Flutter converts it into an `ImageAttachment`.

## `UnifiedCaptureService`: The Real Router

`UnifiedCaptureService` always uses the ADB/Shizuku capture engine and decides how overlays should be handled based on `ScreenShareSettings.screenshotMode`.

### Why it exists

It gives the rest of the app one capture API while keeping overlay-handling rules in one place.

## Overlay Interaction During Capture

ADB capture supports two overlay-handling modes.

### `includeOverlays`

Before capture:
- close the native mini menu if open so the capture trigger UI does not appear in the screenshot
- keep the overlay surface visible

After capture:
- restore the mini menu if it was previously open

### `excludeOverlays`

Before capture:
- close the native mini menu if open
- temporarily suspend the overlay surface if visible without destroying the shared overlay service

After capture:
- restore the overlay if it was previously suspended
- restore the mini menu if it was previously open

Important detail:
- the temporary hide path must not use the normal destructive overlay hide path
- Live2D/image overlay runtime state should stay in memory during capture so `showOverlay()` can rebuild from the existing service state

### Why the mode split exists

- `includeOverlays` captures the visible assistant overlay together with the device screenshot
- `excludeOverlays` preserves the older behavior where the assistant is temporarily hidden before capture

External behavior note:
- Android's device screenshot path can capture normal visible overlay windows
- `FLAG_SECURE` content still cannot be captured through plain Shizuku/ADB `screencap`

## Mini Menu Screenshot Flow

The mini menu uses screenshots as a message-entry shortcut.

### Flow

1. Native mini menu button triggers `miniMenuCaptureAndSendScreenshot`.
2. Flutter-side `MiniMenuService` routes that to the callback configured in `main.dart`.
3. The callback uses `UnifiedCaptureService`.
4. The resulting `ImageAttachment` is sent into `NotificationCoordinator.handleMiniMenuReplyWithImages(...)`.
5. The rest of the flow becomes a normal prompt/API/assistant pipeline with images attached.

This is why mini-menu screenshot requests still obey the same prompt and post-processing rules as chat.

## Settings Surface

`ScreenShareSettingsScreen` exposes:
- screenshot mode selection
- Shizuku install/run/permission state
- capture interval
- auto capture
- image quality
- max resolution
- test capture UI

Important note:
- not every setting is currently a full automation pipeline feature; some are preparatory configuration and test-only controls

## Extension Guidance

### Add a new capture backend

Update all of these together:
- `ScreenShareSettings` enum/model
- `ScreenShareProvider`
- `UnifiedCaptureService`
- Flutter service wrapper
- Android plugin and method channel binding in `MainActivity`
- mini-menu screenshot path if the new backend has special constraints

### Change screenshot attachment behavior

Do it at the shared attachment conversion layer, not separately for chat and mini-menu.

## Common Failure Modes

- forgetting to restore overlay state after `excludeOverlays` capture
- using the normal destructive overlay hide path during capture and losing the active overlay runtime state
- forgetting to close and restore the mini menu when capture starts from the mini menu itself
- bypassing `UnifiedCaptureService` and losing shared behavior
- treating screenshot results as a special message type instead of normal image attachments

## Cross-Links

- Shared runtime and permissions -> `docs/SYSTEM_ARCHITECTURE.md`
- Mini-menu ownership -> `docs/FEATURES/OVERLAYS.md`
- Notification reply with images -> `docs/FEATURES/NOTIFICATIONS.md`
- Shared LLM/image attachment path -> `docs/FEATURES/LLM_AND_PROMPTS.md`

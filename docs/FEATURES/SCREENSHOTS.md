# Screenshots

This document explains how screenshot capture works, how MediaProjection differs from ADB/Shizuku capture, and how screenshot results enter the shared message pipeline.

## Owned Code Paths

- Flutter
  - `lib/models/screen_share_settings.dart`
  - `lib/providers/screen_share_provider.dart`
  - `lib/providers/screen_capture_provider.dart`
  - `lib/services/screen_capture_service.dart`
  - `lib/services/adb_screen_capture_service.dart`
  - `lib/services/unified_capture_service.dart`
  - `lib/screens/screen_share_settings_screen.dart`
  - `lib/services/mini_menu_service.dart`
- Android
  - `android/app/src/main/kotlin/com/example/flutter_application_1/ScreenCapturePlugin.kt`
  - `android/app/src/main/kotlin/com/example/flutter_application_1/AdbScreenCapturePlugin.kt`
  - `android/app/src/main/kotlin/com/example/flutter_application_1/MainActivity.kt`

## Shared Output Format

Both capture paths return the same logical result:
- base64 image bytes
- mime type
- width
- height

Flutter converts that into `ImageAttachment`.

This is a major architectural simplification: chat, notification reply, and mini-menu screenshot send all consume the same attachment model.

## Capture Method Selection

`ScreenShareSettings` owns the chosen capture method:
- `mediaProjection`
- `adb`

`ScreenShareProvider` persists the choice and tracks coarse permission state.

`ScreenCaptureProvider` is the transient execution layer for capture status and last capture result.

## MediaProjection Path

### Flutter side

- `ScreenCaptureService` talks to the `com.pocketwaifu/screen_capture` channel.

### Android side

- `ScreenCapturePlugin.kt` owns MediaProjection logic.

### Runtime flow

1. Flutter asks for permission or capture.
2. Android launches the MediaProjection permission intent if necessary.
3. Once permission is granted, Android caches the result code and intent data.
4. On capture, Android creates:
   - `ImageReader`
   - virtual display
   - bitmap from the latest image buffer
5. It encodes the result as PNG base64 and returns metadata.
6. Flutter writes the bytes to the image cache and returns an `ImageAttachment`.

### Important behavior

- permission is reusable until explicitly released or invalidated
- emulator detection can mark capture unavailable

## ADB / Shizuku Path

### Flutter side

- `AdbScreenCaptureService` talks to `com.pocketwaifu/adb_screen_capture`.

### Android side

- `AdbScreenCapturePlugin.kt` owns Shizuku checks and screencap execution.

### Runtime flow

1. Flutter checks whether Shizuku is installed, running, and permission-granted.
2. Android uses Shizuku to start `screencap -p`.
3. The PNG bytes are read from process output.
4. If a max resolution is configured, Android rescales the bitmap.
5. Result is returned as PNG base64 plus dimensions.
6. Flutter converts it into an `ImageAttachment` the same way as MediaProjection.

## `UnifiedCaptureService`: The Real Router

`UnifiedCaptureService` decides which capture engine to use based on `ScreenShareSettings.captureMethod`.

### Why it exists

It gives the rest of the app one capture API, regardless of the underlying Android mechanism.

## Overlay Interaction During Capture

ADB capture has a special rule.

### ADB path behavior

Before capture:
- hide the native mini menu if open
- hide the overlay if visible

After capture:
- restore the overlay if it was previously visible
- restore the mini menu if it was previously open

This behavior is implemented in `UnifiedCaptureService._captureWithHiddenOverlays(...)`.

### Why only ADB capture hides overlays

The ADB path captures the device screen from outside the app's normal Flutter flow. Hiding overlays avoids capturing the assistant itself inside the screenshot.

MediaProjection path currently captures without this hide/restore behavior.

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
- capture method selection
- MediaProjection permission state
- Shizuku install/run/permission state
- capture interval
- auto capture
- image quality
- max resolution
- test capture and comparison UI

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

- forgetting to restore overlay state after ADB capture
- assuming MediaProjection and ADB have the same permission model
- bypassing `UnifiedCaptureService` and losing shared behavior
- treating screenshot results as a special message type instead of normal image attachments

## Cross-Links

- Shared runtime and permissions -> `docs/SYSTEM_ARCHITECTURE.md`
- Mini-menu ownership -> `docs/FEATURES/OVERLAYS.md`
- Notification reply with images -> `docs/FEATURES/NOTIFICATIONS.md`
- Shared LLM/image attachment path -> `docs/FEATURES/LLM_AND_PROMPTS.md`

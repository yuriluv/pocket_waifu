# Overlays

This document explains the shared overlay runtime, the difference between Live2D mode and image overlay mode, and where the mini menu actually lives.

## Owned Code Paths

- Flutter overlay services and controllers
  - `lib/features/live2d/data/services/live2d_overlay_service.dart`
  - `lib/features/live2d/data/services/live2d_native_bridge.dart`
  - `lib/features/live2d/data/controllers/live2d_overlay_controller.dart`
  - `lib/features/image_overlay/presentation/controllers/image_overlay_controller.dart`
  - `lib/features/image_overlay/data/services/image_overlay_native_bridge.dart`
- Native Android overlay runtime
  - `android/app/src/main/kotlin/com/example/flutter_application_1/live2d/Live2DMethodHandler.kt`
  - `android/app/src/main/kotlin/com/example/flutter_application_1/live2d/overlay/Live2DOverlayService.kt`
  - `android/app/src/main/kotlin/com/example/flutter_application_1/MainActivity.kt`

## One Native Overlay Service, Multiple Modes

There is one shared Android overlay host: `Live2DOverlayService.kt`.

Flutter does not talk to separate native services for Live2D and image overlay. Instead, it switches overlay mode through the same bridge.

### Supported overlay modes

- `live2d`
  - Hosts the GL-based Live2D character runtime.
- `image`
  - Hosts the image overlay runtime with a customizable hitbox.
- `image_basic`
  - Hosts the image overlay runtime with a simpler geometry model where hitbox size follows image size.

### Why this matters

- Touch-through state is shared.
- Overlay visibility is shared.
- Mini-menu hosting is shared.
- A change to the native overlay service can break both Live2D and image overlay behavior at once.

## Flutter-Side Overlay Flow

### Live2D mode

1. UI or runtime handler requests overlay visibility through `Live2DOverlayService` or `Live2DOverlayController`.
2. `Live2DNativeBridge` sends method-channel calls such as:
   - `showOverlay`
   - `hideOverlay`
   - `loadModel`
   - `setScale`
   - `setOpacity`
   - `setPosition`
   - `setTouchThroughEnabled`
3. Android `Live2DMethodHandler` converts those into intents for `Live2DOverlayService`.
4. The Android service updates its foreground overlay window and renderer state.

### Image overlay mode

1. `ImageOverlayController` loads settings and scans the selected image folder.
2. When enabled, it forces the native overlay mode to `image` or `image_basic`.
3. It uses `Live2DNativeBridge.showOverlay()` to make sure the native overlay service is alive.
4. It then applies geometry, opacity, touch-through, and the selected image file.

## Native Overlay Responsibilities

`Live2DOverlayService.kt` owns:
- the foreground overlay window
- the current overlay mode
- Live2D renderer hosting
- image overlay hosting
- touch-through behavior
- edit mode and pinned mode
- mini-menu window lifecycle
- polling Flutter for message lists and toggle state

This service is the real runtime home of the mini menu and overlay interaction state.

## Live2D Overlay Behavior

### Live2D-side controls

Available through `Live2DNativeBridge`:
- scale
- opacity
- overlay position and size
- hitbox size
- character pinning
- edit mode
- relative character scale
- character offset
- character rotation
- motion and expression playback
- parameter writes and reads
- blink, breath, look-at, physics

### State synchronization

`Live2DNativeBridge` also exposes an event stream.

Native events include:
- overlay shown/hidden
- model loaded
- state sync payloads
- notification contract events for touch-through/session sync

`Live2DOverlayService` on Flutter caches local state but can re-sync from native when necessary.

## Image Overlay Behavior

`ImageOverlayController` owns the Flutter-side image overlay logic.

### Data model

- Root folder contains character folders.
- Each character folder contains emotion image files.
- The controller scans that structure through `ImageOverlayStorageService`.

### Runtime behavior

- selected character -> selected emotion file -> native image load
- opacity -> forwarded through `setCharacterOpacity`
- touch-through -> forwarded through the shared native bridge
- geometry -> forwarded through shared overlay size/hitbox/position APIs
- preset load/save -> stores hitbox and position presets per image overlay setup

### Character sync option

Image overlay can optionally sync the app character name with the selected overlay character folder name. This is a cross-feature link between image overlay setup and normal chat identity.

## Mini Menu Hosting

The mini menu is not a Flutter screen. It is an Android overlay card built inside `Live2DOverlayService.kt`.

### Important consequence

If overlay permission is missing, the mini menu cannot exist.

### Mini menu tabs

The Android implementation creates three tabs:
- General
- Input
- Settings placeholder

### General tab owns

- screenshot send action
- touch-through toggle
- open-app action
- notification enable toggle

### Input tab owns

- session message refresh
- inline text send via `miniMenuSendMessage`

### Session source

The mini menu resolves its session id by:
- using the provided session id if one exists
- otherwise asking Flutter for `miniMenuGetActiveSessionId`

## Touch-Through Model

Touch-through is not just a UI switch. It changes native overlay interactivity and visual alpha behavior.

Shared state lives in the Android overlay service and is synchronized with Flutter through:
- `miniMenuGetTouchThroughEnabled`
- `miniMenuToggleTouchThrough`
- direct `setTouchThroughEnabled` bridge calls from the normal settings flows

When touch-through is enabled and the app is not foregrounded, the overlay can reduce character/image alpha to the configured touch-through alpha.

## Global Runtime Interaction

Both `Live2DGlobalRuntimeHandler` and `ImageOverlayGlobalRuntimeHandler` register with `GlobalRuntimeRegistry`.

Implication:
- the master switch is allowed to stop overlay behavior even if the per-feature settings still say enabled

## Extension Guidance

### Add a new overlay mode

Edit all of these together:
- `lib/features/live2d/data/services/live2d_native_bridge.dart`
- `lib/features/image_overlay/data/services/image_overlay_native_bridge.dart` if image-mode-facing
- `android/app/src/main/kotlin/com/example/flutter_application_1/live2d/Live2DMethodHandler.kt`
- `android/app/src/main/kotlin/com/example/flutter_application_1/live2d/overlay/Live2DOverlayService.kt`

Do not create a second Android overlay service unless the shared-service design is being intentionally replaced.

### Add a new mini-menu action

Update:
- Android mini menu UI in `Live2DOverlayService.kt`
- `MiniMenuService` contract in Flutter
- the downstream owner service in Flutter that should execute the action

### Add new geometry or transform controls

Prefer extending the shared bridge instead of bypassing it through ad hoc platform code.

## Common Failure Modes

- Assuming image overlay is independent from the Live2D native bridge. It is not.
- Forgetting that mini menu lifecycle is owned by the native overlay service.
- Updating touch-through logic in Flutter without updating the native alpha/interactivity behavior.
- Breaking `image_basic` while testing only `image` or `live2d`.

## Cross-Links

- Platform contracts -> `docs/SYSTEM_ARCHITECTURE.md`
- Live2D runtime internals -> `docs/FEATURES/LIVE2D_RUNTIME.md`
- Notification and mini-menu entrypoints -> `docs/FEATURES/NOTIFICATIONS.md`
- Screenshot interaction with overlays -> `docs/FEATURES/SCREENSHOTS.md`

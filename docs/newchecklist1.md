# Screen Share Utilization Update — Implementation Plan & Checklist

> **Purpose:** Detailed plan & checklist for implementing the screen-share-based update.
> All items are based on the current codebase architecture and existing features.

---

## Legend

- `[ ]` — Not started
- `[~]` — In progress
- `[x]` — Completed
- `[!]` — Blocked / Needs investigation

---

## Test Findings & Architectural Clarifications

> The following findings were identified during hands-on testing and must be considered across all subsequent sections.

### F1. Dual Notification Architecture (Overlap Issue)

There are **two** separate notification systems in the app that currently overlap:

| Notification | Source | Purpose | Channel |
|---|---|---|---|
| **Overlay Foreground Notification** | `Live2DOverlayService.createNotification()` (line 1497–1523 of `Live2DOverlayService.kt`) | Required Android foreground service notification for the Live2D overlay. Shows "오버레이가 실행 중입니다" | `live2d_overlay_channel` |
| **Standalone Pre-Response Notification** | `NotificationHelper.notifyPreResponse()` (line 130–156 of `NotificationHelper.kt`) | Shows proactive/reply messages from the AI character | `CHANNEL_PRE_RESPONSE` |

**Decision:** The overlay foreground notification should remain as a simple "overlay is running" indicator. All interactive features (reply, menu, etc.) that were previously built **into the overlay notification** should be **migrated to the standalone pre-response notification**, which is the notification connected to the proactive response and reply system.

### F2. Current Overlay Notification Bar — Two-Click Reply Problem

The **overlay foreground notification** currently has a two-step reply flow:

1. **DEFAULT state:** `Reply (entry button)` / `Touch-Through` — user clicks "Reply"
2. **REPLY state:** `Reply (inline RemoteInput)` / `Cancel` — user clicks "Reply" again to open input
3. The actual inline reply text field appears only after step 2.

**Problem:** Users must click Reply **twice** to reach the input field. The Cancel button is unnecessary overhead.

**Solution:** Eliminate `NotificationLayoutState.REPLY` and the Cancel action. Make a single click on Reply directly open the inline input (RemoteInput). Change Touch-Through to Menu.

### F3. Standalone Notification Reply Is Broken

Testing confirmed that the standalone notification reply functionality **does not currently work**. The pipeline from `NotificationActionReceiver` → `NotificationActionStore` → `NotificationBridge.drainPendingActions()` → `NotificationCoordinator._handleAction()` needs end-to-end debugging and repair.

### F4. API Call Architecture — Three Distinct Preset Paths

The final API call structure has **three distinct invocation methods**, each with its own preset resolution:

| # | Invocation Method | API Preset Source | Prompt Preset Source |
|---|---|---|---|
| **1** | **Main Chat Screen** — user sends message via chat input | Active API preset from `SettingsProvider.activeApiConfig` | Active prompt preset from `PromptBlockProvider` (selected in prompt block editor) |
| **2** | **Proactive Auto-Call** — timer fires, sends automatic message | Proactive API preset from `NotificationSettings` > `ProactiveResponseSettings.apiPresetId` | Proactive prompt preset from `ProactiveResponseSettings.promptPresetId` |
| **3** | **Notification Reply** — user replies from notification / mini menu input | Reply API preset from `NotificationSettings.apiPresetId` | Reply prompt preset from `NotificationSettings.promptPresetId` |

> **Important:** Paths 2 and 3 must use **separate** preset configurations. The current code incorrectly falls through proactive presets into reply presets (line 176–178 of `notification_coordinator.dart`). This must be fixed so each path resolves its own presets independently.

---

## Pre1. Notification Feature Reinforcement

### 1. Proactive Response Subordination to Notification Toggle

> **Goal:** Proactive response (선응답) ON/OFF must be **subordinate** to the notification ON/OFF toggle. When notifications are disabled, proactive response must also be disabled regardless of its own toggle state. Remove the standalone proactive ON/OFF toggle from the UI and replace it with a notification-level ON/OFF toggle.

#### 1.1 Model & Provider Changes

- [x] **1.1.1** In `ProactiveResponseService._maybeStart()` (line 83–132 of `proactive_response_service.dart`), verify that it already checks `notificationSettings.notificationsEnabled` on the `_trigger()` path (line 207–247). Ensure `_maybeStart()` also gates on `notificationSettings.notificationsEnabled` — if notifications are OFF, call `stop()` immediately.
- [x] **1.1.2** In `NotificationSettingsProvider.setNotificationsEnabled()` (line 79–97 of `notification_settings_provider.dart`), when notifications are **disabled**, also stop the proactive timer by ensuring the `ProactiveResponseService` reacts to the provider change (it listens via `_notificationSettingsProvider`). Verify this chain: `setNotificationsEnabled(false)` → `notifyListeners()` → `ProactiveResponseService` picks up the change and calls `stop()`.
- [x] **1.1.3** Confirm that re-enabling notifications (`setNotificationsEnabled(true)`) triggers `ProactiveResponseService._maybeStart()` so the proactive timer resumes if the proactive settings themselves are still enabled.

#### 1.2 UI Changes in `notification_settings_screen.dart`

- [x] **1.2.1** Remove the **standalone proactive ON/OFF `SwitchListTile`** (currently at lines 98–103: `'프로액티브 응답 사용'`).
- [x] **1.2.2** Keep the existing **notification ON/OFF `SwitchListTile`** (lines 76–89: `'알림 사용'`) as the single master toggle. Update its subtitle to clarify that it controls both notifications **and** proactive responses: e.g., `'알림 및 선응답(프로액티브) 기능을 사용합니다.'`.
- [x] **1.2.3** All proactive-specific settings (schedule text, prompt preset, API preset) should become **visually disabled** (greyed out / `IgnorePointer`) when `notificationsEnabled == false`, to make the dependency clear.
- [x] **1.2.4** Verify that the proactive schedule, prompt preset, and API preset controls remain visible and editable when notifications are ON, so advanced users can still customize proactive behavior.

#### 1.3 Behavioral Verification

- [x] **1.3.1** Test: Disable notifications → verify proactive timer stops and no proactive notifications fire.
- [x] **1.3.2** Test: Enable notifications with proactive settings already configured → verify proactive timer starts.
- [x] **1.3.3** Test: Disable notifications while a proactive response is in-flight → verify the in-flight request is cancelled (`cancelProactiveInFlight()`).

---

### 2. Notification Fix & Test Feature

> **Goal:** Fix the current notification system (reply is confirmed broken) and add a manual notification test feature at the **bottom** of the notification settings screen.

#### 2.0 Notification Architecture Refactoring (Based on Finding F1)

> The overlay foreground notification and the standalone pre-response notification currently overlap. The interactive features (reply, touch-through toggle, reply session sync) built into the overlay notification should be migrated to the standalone notification system.

- [x] **2.0.1** **Identify features to migrate** from the overlay notification (`Live2DOverlayService.kt`) to the standalone notification (`NotificationHelper.kt`):
  - Inline reply via `RemoteInput` (currently in overlay: `createInlineReplyAction()`, line 1386–1405)
  - Reply session sync publishing (`publishNotificationSessionSync()`, line 1445–1479)
  - Notification loading/response/error state management (`updateNotificationResponse()`, `updateNotificationError()`, `buildNotificationContentText()`)
- [x] **2.0.2** **Keep the overlay foreground notification simple:** After migration, `Live2DOverlayService.createNotification()` should only show:
  - Title: "Live2D 오버레이"
  - Content: basic status text (e.g., "오버레이가 실행 중입니다")
  - SubText: Touch-Through ON/OFF status
  - Single action: Open App (existing `createOpenAppPendingIntent()`)
  - **Remove:** Reply entry, Reply inline, Cancel, Touch-Through toggle actions. These move to the standalone notification.
- [x] **2.0.3** **Remove `NotificationLayoutState` enum** from `Live2DOverlayService.kt` (line 205) and all related state tracking (`notificationLayoutState`, `notificationMessage`, `notificationLoading`, `notificationPendingReply`, `notificationError`, lines 206–210).
- [x] **2.0.4** **Enhance the standalone notification** (`NotificationHelper.kt`) to include the migrated interactive features. The new standalone notification should support:
  - **DEFAULT state:** `Reply (direct inline RemoteInput)` / `Menu`
  - Reply triggers `NotificationActionReceiver` → `NotificationActionStore` → Flutter pipeline.
  - Menu triggers the popup mini menu.

#### 2.1 Standalone Notification Debugging & Fix (Finding F3)

- [x] **2.1.1** Investigate the full standalone notification pipeline end-to-end:
  - Dart: `NotificationCoordinator.triggerProactiveResponse()` / `handleNotificationReply()` → `NotificationBridge.showPreResponseNotification()` → Android MethodChannel `showPreResponseNotification`.
  - Android: `MainActivity.configureFlutterEngine()` NOTIFICATION_CHANNEL handler (line 185–219 of `MainActivity.kt`) → `NotificationHelper.notifyPreResponse()` (line 130–156 of `NotificationHelper.kt`).
  - Check POST_NOTIFICATIONS permission on Android 13+ (TIRAMISU): `NotificationHelper.notifyPreResponse()` already checks this (line 137–145).
- [x] **2.1.2** Verify `NotificationHelper.createChannels()` is called during initialization. It is invoked via `NotificationBridge.initializeChannels()` → MethodChannel `initializeChannels` → `NotificationHelper.createChannels(this)` (line 188–191 of `MainActivity.kt`). Ensure this runs before any notification is posted.
- [x] **2.1.3** Check the notification channel importance: currently `IMPORTANCE_HIGH` in `NotificationHelper.createChannels()` (line 29 of `NotificationHelper.kt`). Ensure the user hasn't manually disabled the channel in Android settings.
- [x] **2.1.4** Verify that `NotificationBridge.initialize()` is called early in the app lifecycle (check `main.dart` or where `NotificationCoordinator.attach()` is invoked). Ensure `_channel.setMethodCallHandler(_handleMethodCall)` is registered before any notification actions are expected.
- [x] **2.1.5** Test notification delivery in all app states:
  - App in **foreground**
  - App in **background**
  - App **killed** (cold-start via notification action)
- [x] **2.1.6** Fix any identified issues from the above investigation.

#### 2.2 Reply Action Chain Fix (Finding F3 — Reply Confirmed Broken)

- [x] **2.2.1** Verify `NotificationActionReceiver.onReceive()` correctly enqueues actions to `NotificationActionStore` for all action types: `reply`, `touchThrough`, `cancelReply`. Add debug logging at each step.
- [x] **2.2.2** Verify `NotificationBridge.initialize()` calls `drainPendingActions` to pick up any actions queued while the Flutter engine was not attached. Check that the returned `List<dynamic>` correctly maps to `NotificationAction` objects.
- [x] **2.2.3** Verify `NotificationBridge._handleMethodCall()` correctly streams actions via `_actions` StreamController to `NotificationCoordinator._handleAction()`.
- [x] **2.2.4** **Debug the exact failure point:** Add `debugPrint` statements at each stage of the pipeline to identify where the reply message is lost:
  1. `NotificationActionReceiver.onReceive()` — does it receive the intent?
  2. `NotificationActionStore.enqueueAction()` — is the action persisted?
  3. `NotificationBridge.initialize()` → `drainPendingActions` — are stored actions retrieved?
  4. `_handleMethodCall('notificationAction')` — does the method channel fire?
  5. `NotificationCoordinator._handleAction()` — does the coordinator receive it?
  6. `handleNotificationReply()` — does the API call execute?
- [x] **2.2.5** Fix the identified broken link in the reply chain.

#### 2.3 Notification Test UI

- [x] **2.3.1** Add a new **"Notification Test"** section at the **bottom** of `notification_settings_screen.dart`, below all existing content (inside the `Opacity` > `IgnorePointer` > `Column` block, after the API preset dropdown).
- [x] **2.3.2** Add a `_SectionTitle(title: '알림 테스트')` divider.
- [x] **2.3.3** Add a `TextField` for **Character Name** input with:
  - `labelText: '캐릭터 이름'`
  - Pre-filled with the current `settingsProvider.character.name`.
  - Controller: `_testCharNameController`.
- [x] **2.3.4** Add a `TextField` for **Message** input with:
  - `labelText: '메세지'`
  - `maxLines: 3`
  - Controller: `_testMessageController`.
- [x] **2.3.5** Add an `ElevatedButton` labeled **'테스트 알림 보내기'** that:
  1. Reads the character name and message from the controllers.
  2. Calls `NotificationBridge.instance.showPreResponseNotification(title: charName, message: message, sessionId: activeSessionId)`.
  3. This must use the **exact same** `showPreResponseNotification` path as real API notifications, so the resulting Android notification has the same actions (Reply / Menu after migration).
- [x] **2.3.6** Verify that pressing **Reply** on a test notification triggers `NotificationCoordinator.handleNotificationReply()` and produces a real LLM response, stored in the chat session just like a real reply.
- [x] **2.3.7** Verify that pressing **Menu** on a test notification opens the popup mini menu (after §4 implementation).

#### 2.4 State Management for Test UI

- [x] **2.4.1** Add `TextEditingController _testCharNameController` and `TextEditingController _testMessageController` to `_NotificationSettingsScreenState`.
- [x] **2.4.2** Initialize `_testCharNameController` with `settingsProvider.character.name` in `initState()` (will need `context.read<SettingsProvider>()` or pass it in).
- [x] **2.4.3** Dispose both controllers in `dispose()`.

---

### 3. Notification Reply Feature Enhancement

> **Goal:** Verify reply functionality works (after §2 fixes), then add notification-specific prompt preset and API preset selection (similar to the existing proactive preset dropdowns). Based on Finding F4, each API call path must resolve its own presets independently.

#### 3.1 Reply Functionality Verification (After §2 Fix)

- [x] **3.1.1** End-to-end test: Send a test notification (from 2.3) → reply via the notification inline reply → verify:
  - User message is added to `ChatSessionProvider` for the resolved session.
  - API call is made using `NotificationCoordinator._sendWithPromptBlocks()`.
  - Assistant response is added to the session.
  - A new notification with the assistant response is shown.
- [x] **3.1.2** Test reply when **no active session** exists → verify the error notification is shown: `'활성 세션이 없습니다. 앱에서 채팅 세션을 생성하세요.'`.
- [x] **3.1.3** Test reply when the **Master Switch** is OFF → verify reply is ignored with log `'NotificationCoordinator: Master OFF, reply ignored'`.
- [x] **3.1.4** Test that regex pipeline and Lua scripting hooks are applied during notification reply (both `_prepareUserInput` and `_prepareAssistantOutput` in `notification_coordinator.dart` lines 326–443).

#### 3.2 Notification Reply Preset Selection UI

> The `NotificationSettings` model already has `promptPresetId` and `apiPresetId` fields, and `NotificationSettingsProvider` already has `setNotificationPromptPreset()` and `setNotificationApiPreset()` methods. However, the notification settings screen currently does NOT expose dropdown selectors for these fields (only proactive presets are shown). Per Finding F4, notification reply presets are separate from proactive presets.

- [x] **3.2.1** Add a new section in `notification_settings_screen.dart` labeled `'알림 답장 프리셋'` (between the notification toggle section and the proactive section).
- [x] **3.2.2** Add a `_PresetDropdown` widget for **notification reply prompt preset**:
  ```dart
  _PresetDropdown(
    label: '답장 프롬프트 프리셋',
    value: notificationSettings.promptPresetId,
    presets: promptPresets,
    onChanged: settingsProvider.setNotificationPromptPreset,
  )
  ```
- [x] **3.2.3** Add an `_ApiPresetDropdown` widget for **notification reply API preset**:
  ```dart
  _ApiPresetDropdown(
    label: '답장 API 프리셋',
    value: notificationSettings.apiPresetId,
    apiConfigs: apiConfigs,
    onChanged: settingsProvider.setNotificationApiPreset,
  )
  ```
- [x] **3.2.4** These dropdowns should be visually disabled when `notificationsEnabled == false`.

#### 3.3 Wiring Presets to Actual Reply Logic (Finding F4 — Preset Isolation)

- [x] **3.3.1** **Fix preset resolution in `NotificationCoordinator.handleNotificationReply()`** (line 118–233). Currently at line 176–178 it uses:
  ```dart
  final apiConfig = _resolveApiConfig(
    proactiveSettings?.apiPresetId ?? notificationSettings.apiPresetId,
  );
  ```
  **This is incorrect.** Reply must use `notificationSettings.apiPresetId` exclusively (Path 3 in F4). Change to:
  ```dart
  final apiConfig = _resolveApiConfig(notificationSettings.apiPresetId);
  ```
- [x] **3.3.2** **Ensure proactive uses its own presets independently.** In `ProactiveResponseService._trigger()` (line 207–247), verify it uses `settings.apiPresetId` from `ProactiveResponseSettings` (Path 2 in F4). Currently at line 235 it calls `_resolveApiConfig(settings.apiPresetId)` — confirm this only reads from `ProactiveResponseSettings.apiPresetId`.
- [x] **3.3.3** **Verify prompt preset wiring:** `NotificationCoordinator._sendWithPromptBlocks()` uses `promptProvider.buildMessagesForApi()`. The prompt preset must be resolved from `notificationSettings.promptPresetId` for reply (Path 3) and from `proactiveSettings.promptPresetId` for proactive (Path 2). Check if `PromptBlockProvider` has a mechanism to temporarily switch to a different prompt preset. If not, implement preset resolution before calling `_sendWithPromptBlocks()`.
- [x] **3.3.4** After implementation, test all three paths end-to-end:
  - **Path 1:** Main chat → verify active API preset + active prompt preset used.
  - **Path 2:** Proactive auto-call → verify proactive API preset + proactive prompt preset used.
  - **Path 3:** Notification reply → verify reply API preset + reply prompt preset used.

---

### 4. Notification Bar UI Improvement (Based on Findings F1, F2)

> **Goal:** Restructure both notification UIs based on the dual notification architecture findings.

#### 4.1 Overlay Foreground Notification Simplification (`Live2DOverlayService.kt`)

> The overlay foreground notification should become a simple, non-interactive service indicator. All interactive features migrate to the standalone notification.

- [x] **4.1.1** **Remove `NotificationLayoutState` enum** (line 205) and the `notificationLayoutState` field (line 206).
- [x] **4.1.2** **Remove notification state fields** (lines 207–210): `notificationMessage`, `notificationLoading`, `notificationPendingReply`, `notificationError`.
- [x] **4.1.3** **Remove all reply-related methods:**
  - `openNotificationReplyLayout()` (line 1227–1231)
  - `cancelNotificationReplyLayout()` (line 1233–1237)
  - `handleInlineReplyFromNotification()` (line 1239–1261)
  - `updateNotificationResponse()` (line 1269–1289)
  - `updateNotificationError()` (line 1291–1306)
  - `buildNotificationContentText()` (line 1308–1319)
- [x] **4.1.4** **Remove reply/cancel/touch-through actions from overlay notification:**
  - Remove: `createReplyEntryAction()` (line 1373–1384)
  - Remove: `createInlineReplyAction()` (line 1386–1405)
  - Remove: `createCancelReplyAction()` (line 1407–1418)
  - Remove: `createTouchThroughToggleAction()` (line 1420–1431)
- [x] **4.1.5** **Simplify `createNotification()`** to only include:
  - Title: "Live2D 오버레이"
  - Content: "오버레이가 실행 중입니다"
  - SubText: Touch-Through ON/OFF status (kept for quick visibility)
  - ContentIntent: `createOpenAppPendingIntent()` (open app on tap)
  - No action buttons (or just a single "Open App" action).
- [x] **4.1.6** **Remove related action constants** from the companion object:
  - `ACTION_NOTIFICATION_SHOW_REPLY` (line 71)
  - `ACTION_NOTIFICATION_SEND_REPLY` (line 72)
  - `ACTION_NOTIFICATION_CANCEL_REPLY` (line 73)
  - `ACTION_NOTIFICATION_TOGGLE_TOUCH_THROUGH` (line 74)
  - Keep `ACTION_NOTIFICATION_SET_RESPONSE` and `ACTION_NOTIFICATION_SET_ERROR` only if still needed by the Dart-side overlay service for status updates (otherwise remove).
- [x] **4.1.7** **Clean up `onStartCommand()` handlers** for the removed actions.
- [x] **4.1.8** **Remove `publishNotificationSessionSync()`** and `publishNotificationTouchThroughEvent()` if no longer needed after migration (the standalone notification system will handle these).

#### 4.2 Standalone Notification Enhancement (`NotificationHelper.kt`)

> The standalone pre-response notification becomes the primary interactive notification with 1-click reply and Menu button.

- [x] **4.2.1** **Redesign `buildPreResponseNotification()`** to support the new action layout:
  - **Actions:** `Reply (direct inline RemoteInput)` / `Menu`
  - **Remove the old Cancel action** (was 3rd button).
  - **Replace Touch-Through action with Menu action.**
- [x] **4.2.2** **Implement direct 1-click inline reply** (Finding F2 fix):
  - The Reply action should include `RemoteInput` directly (no intermediate "entry" step).
  - When user clicks Reply, the inline text input field appears immediately.
  ```kotlin
  val remoteInput = RemoteInput.Builder(NotificationConstants.REMOTE_INPUT_KEY)
      .setLabel("답장을 입력하세요")
      .build()
  val replyAction = NotificationCompat.Action.Builder(
      R.mipmap.ic_launcher, "Reply", replyPendingIntent
  )
      .addRemoteInput(remoteInput)
      .setAllowGeneratedReplies(true)
      .build()
  ```
- [x] **4.2.3** **Add Menu action** to the standalone notification:
  ```kotlin
  val menuIntent = Intent(context, NotificationActionReceiver::class.java).apply {
      action = NotificationConstants.ACTION_MENU
      putExtra(NotificationConstants.EXTRA_SESSION_ID, sessionId)
  }
  val menuPendingIntent = PendingIntent.getBroadcast(
      context, 4, menuIntent,
      PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
  )
  val menuAction = NotificationCompat.Action.Builder(
      R.mipmap.ic_launcher, "Menu", menuPendingIntent
  ).build()
  ```
- [x] **4.2.4** **Add `ACTION_MENU` constant** to `NotificationConstants.kt`.
- [x] **4.2.5** **Handle Menu action in `NotificationActionReceiver.onReceive()`:** Enqueue a `"menu"` type action to `NotificationActionStore`.
- [x] **4.2.6** **Handle Menu action in `NotificationCoordinator._handleAction()`:** When action type is `"menu"`, trigger the popup mini menu opening (via the mini menu service from §5).

#### 4.3 Dart-Side Integration

- [x] **4.3.1** In `NotificationCoordinator._handleAction()` (line 87–105 of `notification_coordinator.dart`), add a new case for `'menu'` action type that triggers the popup mini menu.
- [x] **4.3.2** Remove the `'cancelReply'` case (line 100–103) since the Cancel button is removed from the notification.
- [x] **4.3.3** Update `Live2DOverlayService` (Dart-side) to remove methods related to the migrated overlay notification features:
  - `setNotificationResponse()` (line 423–425 of `live2d_overlay_service.dart`)
  - `setNotificationError()` (if present)
  - Any notification contract callback handling.

---

## Main1. Popup Mini Menu (Draw Over Other Apps Overlay)

> **Goal:** When the "Menu" button on the notification bar is pressed, display a popup mini menu using the Draw Over Other Apps (overlay) permission. The menu has 3 tabs: General, Input, Settings.

### 5. Popup Mini Menu — Architecture & Service

#### 5.1 Architecture Design

- [x] **5.1.1** Decide implementation approach. Two viable options:
  - **Option A (Recommended): Android-native overlay window** — Similar to how `Live2DOverlayService` manages its overlay, create a separate overlay window (or extend the existing service) to show a native Android popup with XML layout.
  - **Option B: Flutter overlay** — Use the existing Flutter engine to render a popup, but this requires the Flutter engine to be active and is more complex for background scenarios.
  - **Decision:** Use **Option A** — Extend `Live2DOverlayService` with a secondary overlay window for the mini menu. This leverages the existing overlay permission and service lifecycle.

- [x] **5.1.2** The popup mini menu must:
  - Appear as a floating window on top of all apps.
  - Be dismissible by tapping outside or pressing a close button.
  - Not interfere with the Live2D overlay rendering.
  - Communicate with the Flutter engine via `Live2DEventStreamHandler` for actions that require Dart-side logic (e.g., sending messages, capturing screenshots).

#### 5.2 Android Native Implementation

- [x] **5.2.1** Add overlay permission check: The menu requires `SYSTEM_ALERT_WINDOW` permission (Draw Over Other Apps). This is the same permission used by `Live2DOverlayService`, so if the overlay is already running, permission is already granted. If not, request it before showing the menu.
- [x] **5.2.2** Create a new layout file or programmatic view for the mini menu popup:
  - Root: `FrameLayout` with semi-transparent background (for dismiss-on-tap-outside).
  - Inner: `CardView` or `LinearLayout` with rounded corners, containing:
    - `TabLayout` with 3 tabs (General / Input / Settings).
    - `ViewPager2` or `FrameLayout` for tab content switching.
  - Dimensions: ~80% screen width, ~60% screen height, centered.
- [x] **5.2.3** Add `WindowManager.addView()` logic for the popup overlay with `TYPE_APPLICATION_OVERLAY` flag and `FLAG_NOT_TOUCH_MODAL` so it can receive focus.
- [x] **5.2.4** Handle dismissal:
  - Tap outside the card → remove popup overlay.
  - Back button (if feasible) → remove popup overlay.
  - Explicit close button in the card header.

#### 5.3 Flutter-Side Popup Controller

- [x] **5.3.1** Create a new Dart service `MiniMenuService` (or extend `Live2DOverlayService` Dart side) with methods:
  - `openMiniMenu()` — sends intent to Android to show the popup overlay.
  - `closeMiniMenu()` — sends intent to Android to dismiss the popup overlay.
  - Event listener for menu actions coming back from Android.
- [x] **5.3.2** Wire the menu-open trigger: When `NotificationCoordinator._handleAction()` receives `type == "menu"`, call `MiniMenuService.openMiniMenu()`.

---

### 6. General Tab

> **Goal:** Quick-action buttons: Screenshot, Touch-Through toggle, Navigate to App, Notification Quick Setting.

#### 6.1 Screenshot Button

- [x] **6.1.1** Add a "Screenshot" (스크린샷) button in the General tab.
- [x] **6.1.2** Implement screen capture permission check:
  - Query `ScreenCaptureService.hasPermission()` via Flutter method channel (or check from Android side using the `ScreenCapturePlugin`).
  - If NOT granted → call `ScreenCaptureService.requestPermission()` and return (do not capture yet).
  - If granted → proceed to capture.
- [x] **6.1.3** Implement capture sequence:
  1. **Close the popup mini menu first** (remove the overlay window) to avoid capturing the menu itself.
  2. Add a small delay (e.g., 300ms) to ensure the popup has been fully removed from screen.
  3. Call `ScreenCapturePlugin.captureScreen()` (or via Flutter `ScreenCaptureProvider.capture()`).
  4. Receive the captured `ImageAttachment` (base64 data, dimensions, mime type).
- [x] **6.1.4** Send the screenshot to LLM:
  - Resolve the active session from `ChatSessionProvider.activeSessionId`.
  - If no active session, show error toast.
  - Create a `Message` with `role: user`, attach the `ImageAttachment`.
  - If the screenshot message input field contains text, include that text as the message content.
  - Clear the input field after sending.
  - Trigger API call via `NotificationCoordinator.handleNotificationReply()` or a similar pathway that supports image attachments.
- [x] **6.1.5** Add a `TextField` below the Screenshot button:
  - Hint text: e.g., `'메세지 (선택사항)'`
  - Controller managed on the Android side (if native menu) or via a Flutter method channel.
  - Text is sent alongside the screenshot.
  - Text is cleared after the screenshot is sent.

> **Implementation Note:** Since the mini menu is an Android native overlay, the screenshot input field and button logic will require method channel communication with Flutter for the actual API call. The flow: **Android button press → method channel → Flutter `ScreenCaptureProvider.capture()` → attach to message → API call → result back to Android overlay notification**.

#### 6.2 Touch-Through Toggle

- [x] **6.2.1** Add a toggle switch labeled "터치스루" that reflects the current touch-through state.
- [x] **6.2.2** Read current state from `Live2DOverlayService.touchThroughEnabled` (accessible within the service).
- [x] **6.2.3** On toggle, call `setTouchThroughEnabled(!touchThroughEnabled)` (existing method in `Live2DOverlayService`) and persist via publishing event to Flutter → `Live2DQuickToggleService.toggleTouchThrough()`.
- [x] **6.2.4** Update the toggle UI to reflect the new state.

#### 6.3 Navigate to App

- [x] **6.3.1** Add a button labeled "앱으로 이동".
- [x] **6.3.2** On press:
  1. Close the popup menu.
  2. Launch `MainActivity` with flags `FLAG_ACTIVITY_NEW_TASK | FLAG_ACTIVITY_CLEAR_TOP`:
     ```kotlin
     val intent = Intent(context, MainActivity::class.java).apply {
         flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
     }
     context.startActivity(intent)
     ```

#### 6.4 Notification Quick Setting

- [x] **6.4.1** Add a toggle switch labeled "알림 간편설정" to enable/disable notifications.
- [x] **6.4.2** Read current state from Flutter via method channel: `NotificationSettingsProvider.notificationSettings.notificationsEnabled`.
- [x] **6.4.3** On toggle, invoke Flutter method channel to call `NotificationSettingsProvider.setNotificationsEnabled(value)`.
- [x] **6.4.4** Handle the permission request flow if enabling (the provider's `ensureNotificationPermission()` handles this on the Dart side).

---

### 7. Input Tab (Mini Chat Screen)

> **Goal:** A mini chat screen similar to the main chat, showing past chat history and an input field. Operates identically to the notification reply functionality (Path 3 in F4).

#### 7.1 Chat History Display

- [x] **7.1.1** Create a scrollable message list in the Input tab.
- [x] **7.1.2** Retrieve chat history from the active session:
  - Via method channel: request `ChatSessionProvider.getMessagesForSession(activeSessionId)`.
  - Flutter serializes messages to JSON and returns to Android.
- [x] **7.1.3** Display messages in a simple chat bubble layout:
  - User messages aligned right, assistant messages aligned left.
  - Show message content text (no need for image thumbnails in mini view, but nice-to-have).
  - Auto-scroll to the bottom on load and when new messages arrive.
- [x] **7.1.4** Listen for real-time updates: When new messages are added to the session (from any source: reply, proactive, main app), refresh the mini chat view.

#### 7.2 Message Input

- [x] **7.2.1** Add an `EditText` input field at the bottom of the Input tab.
- [x] **7.2.2** Add a "Send" button next to the input field.
- [x] **7.2.3** On send:
  1. Read the message text.
  2. Send to Flutter via method channel → `NotificationCoordinator.handleNotificationReply(message, sessionId: activeSessionId)`.
  3. Clear the input field.
  4. Show "Responding..." status in the mini chat.
  5. When the assistant response arrives (via event stream), update the chat history and show the new message.
- [x] **7.2.4** The input functionality must use the **same reply pipeline** as the notification reply (Path 3 in F4):
  - Same `_prepareUserInput` / `_prepareAssistantOutput` hooks.
  - Uses **reply** prompt preset and API preset from `NotificationSettings` (not proactive presets).
  - Messages are stored in the same `ChatSessionProvider` session.

#### 7.3 Integration with Notification Reply

- [x] **7.3.1** Verify that messages sent from the Input tab appear in the main chat screen when the user navigates back to the app.
- [x] **7.3.2** Verify that messages sent from the notification inline reply appear in the Input tab's chat history.
- [x] **7.3.3** Ensure thread-safety: `ChatSessionProvider.runSerialized()` is used for all message additions, so concurrent mini-chat and notification replies are serialized.

---

### 8. Settings Tab (Placeholder)

> **Goal:** Create the tab with no functionality — placeholder for future features.

- [x] **8.1** Add the "설정" (Settings) tab in the mini menu `TabLayout`.
- [x] **8.2** Display a centered placeholder text: e.g., `'향후 업데이트 예정'` (Coming in future updates).
- [x] **8.3** Ensure the tab is navigable and does not crash.

---

## Post1. Live Testing Results & Bug Fixes

> **Context:** All §1–§8 tasks have been marked complete (code written). Live device testing revealed the following results. This section captures the **bugs found** and the **detailed fix plan** for each.

### Live Test Results Summary

| Feature | Result | Notes |
|---------|--------|-------|
| Notification Test | ✅ **Pass** | Test notification fires correctly with Reply/Menu actions |
| Proactive Response | ✅ **Pass** | Timer triggers API call, notification appears correctly |
| Notification Reply | ✅ **Pass** | Inline reply sends message, receives LLM response |
| Reply Re-notification (Proactive) | ✅ **Pass** | After replying to proactive notification, response notification fires and allows further replies |
| Reply Re-notification (Test) | ❌ **Fail** | After replying to a test notification, the response notification does NOT allow another reply cycle |
| Menu Button | ✅ **Pass** | Menu opens the popup mini menu overlay correctly |
| Screenshot Feature | ❌ **Fail** | Permission not requested, capture fails, image+message send fails |
| Touch-Through Toggle (Menu) | ❌ **Fail** | State not synced with actual overlay touch-through state |
| Notification Toggle (Menu) | ❌ **Fail** | State not synced with actual notification settings |
| Input Tab — Send Message | ❌ **Fail** | Returns `not_implemented` error — handler not connected |
| Input Tab — Chat History | ❌ **Fail** | Chat history display not populating |

---

### 9. Bug Fixes (Priority Phase)

> **Principle:** Use the successfully working features (notification reply, proactive, menu open) as reference implementations to fix the broken features.

#### 9.1 Test Notification Reply Re-send Failure

> **Symptom:** Replying to a proactive notification works end-to-end (reply → LLM response → new notification → can reply again). But replying to a *test* notification succeeds once, and the response notification cannot be replied to again.

> **Root Cause Analysis:** The response notification is posted by `_handleNotificationReplyInternal()` at line 242–246 of `notification_coordinator.dart` via `_bridge.showPreResponseNotification()`. This calls `NotificationHelper.notifyPreResponse()` which generates a unique notification ID (`NOTIFICATION_ID_PRE_RESPONSE_BASE + time % 1000`, line 133–134 of `NotificationHelper.kt`). The `sessionId` passed to the response notification must be correct for the next reply to work. If the test notification was sent without a `sessionId`, the reply chain breaks because subsequent replies can't resolve the session.

- [x] **9.1.1** **Debug the test notification `sessionId` flow:**
  - In `notification_settings_screen.dart`, verify that the test notification button sends `sessionId: activeSessionId` to `NotificationBridge.showPreResponseNotification()`.
  - Check `ChatSessionProvider.activeSessionId` is non-null when the test button is pressed.
  - Add `debugPrint` to trace: test button → `showPreResponseNotification(sessionId)` → Android `notifyPreResponse(sessionId)` → `buildPreResponseNotification(sessionId)` → reply Intent extras contain `sessionId`.

- [x] **9.1.2** **Verify the reply chain preserves `sessionId`:**
  - After the first reply, `_handleNotificationReplyInternal()` calls `_bridge.showPreResponseNotification(sessionId: resolvedSessionId)` (line 242–246).
  - Confirm this `resolvedSessionId` is propagated to the new notification's reply action Intent extra (`NotificationConstants.EXTRA_SESSION_ID`).
  - In `NotificationHelper.buildPreResponseNotification()` (line 38–109), verify `sessionId` is included in `replyIntent.putExtra()` (line 57).

- [x] **9.1.3** **Fix if `sessionId` is null in test notifications:**
  - In the notification settings screen test button handler, ensure `activeSessionId` is resolved from `ChatSessionProvider`:
    ```dart
    final sessionProvider = context.read<ChatSessionProvider>();
    final activeSessionId = sessionProvider.activeSessionId;
    // Pass to showPreResponseNotification
    ```
  - If `activeSessionId` is null, show an error toast instead of sending the test notification.

- [x] **9.1.4** **Verify re-reply works end-to-end after fix:** Test notification → reply → response notification → reply again → second response.

#### 9.2 Screenshot Feature Fix (Permission + Capture + Send)

> **Symptom:** The screenshot button in the General tab does nothing. No permission prompt appears, no capture occurs, and no image is sent.
>
> **Root Cause Analysis:** The `captureAndSend` handler in `main.dart` (line 230–254) creates a **new** `ScreenCaptureService()` instance each time. This service uses the `com.pocketwaifu/screen_capture` MethodChannel which routes to `ScreenCapturePlugin` in `MainActivity.kt`. The critical issue is that `ScreenCapturePlugin.requestPermission()` and `captureScreen()` both use `startActivityForResult()` — **but when the mini menu triggers the capture, the method channel call originates from `Live2DOverlayService`'s Flutter engine, which goes to `MainActivity`'s registered handler. If `MainActivity` is not in the foreground, `startActivityForResult()` may fail silently or the permission dialog may not appear.**

- [x] **9.2.1** **Modularize permission check to work from background/service context:**
  - The `ScreenCapturePlugin.requestPermission()` (line 45–62 of `ScreenCapturePlugin.kt`) requires `startActivityForResult` which needs a visible Activity.
  - **Option A (Recommended):** Before calling `captureAndSend`, bring `MainActivity` to the foreground briefly for permission, then return to the overlay context:
    ```dart
    // In captureAndSend handler:
    if (!hasPermission) {
      // Launch MainActivity for permission, wait, then check again
      await captureService.requestPermission(); // This triggers startActivityForResult
      // Wait for result
    }
    ```
  - **Option B:** Store the MediaProjection permission result globally so that even if the Activity is not visible, the stored result code + data can be reused for subsequent captures.

- [x] **9.2.2** **Verify the MethodChannel is correctly registered from the overlay context:**
  - The `SCREEN_CAPTURE_CHANNEL` is registered in `MainActivity.configureFlutterEngine()` (line 249–270).
  - When the mini menu calls `miniMenuCaptureAndSendScreenshot`, this invokes `_captureAndSend()` in Dart, which calls `ScreenCaptureService().capture()`.
  - `ScreenCaptureService` uses `MethodChannel('com.pocketwaifu/screen_capture')` — this should work if the FlutterEngine is the same one registered in `MainActivity`.
  - **Verify:** The `FlutterEngineCache.getInstance().get(ENGINE_ID)` used by `Live2DOverlayService.miniMenuChannel()` returns the same engine as `MainActivity.flutterEngine`. If they share the engine, the MethodChannel handler should be the same.

- [x] **9.2.3** **Handle the "permission already granted" case:**
  - If `ScreenCapturePlugin.hasPermission()` returns `true` (projectionResultCode is OK and projectionResultData is non-null), the capture should proceed without requiring `startActivityForResult`.
  - **Problem:** The `projectionResultCode` and `projectionResultData` are instance fields of `ScreenCapturePlugin` — they reset if `MainActivity` is recreated. Ensure the plugin instance is persistent across the Activity lifecycle.
  - **Check:** `screenCapturePlugin` is initialized in `configureFlutterEngine()` (line 72 of `MainActivity.kt`). If the Activity is recreated, the permission state is lost. Consider persisting permission state in SharedPreferences or a companion object.

- [x] **9.2.4** **Implement screenshot flow resilience:**
  - Step 1: Add `debugPrint` at every stage in `captureAndSend` in `main.dart`:
    ```dart
    captureAndSend: (sessionId, text) async {
      debugPrint('MiniMenu: captureAndSend called, sessionId=$sessionId');
      final captureService = ScreenCaptureService();
      final hasPermission = await captureService.hasPermission();
      debugPrint('MiniMenu: hasPermission=$hasPermission');
      if (!hasPermission) {
        debugPrint('MiniMenu: requesting permission...');
        final granted = await captureService.requestPermission();
        debugPrint('MiniMenu: permission granted=$granted');
        if (!granted) {
          return {'ok': false, 'error': 'capture_permission_denied'};
        }
      }
      debugPrint('MiniMenu: capturing screen...');
      final image = await captureService.capture();
      debugPrint('MiniMenu: capture result=${image != null}');
      // ...
    }
    ```
  - Step 2: Test on device and trace where the pipeline breaks.
  - Step 3: Fix the identified issue.

- [x] **9.2.5** **Alternative approach — Reuse ScreenShareProvider's permission:**
  - The user notes that `ScreenShareSettings` has a working permission grant flow.
  - Check `ScreenShareProvider` → how it requests MediaProjection permission.
  - If `ScreenShareProvider` already has a granted projection, reuse that projection for screenshot capture instead of requesting a new one.
  - This may require exposing the `MediaProjection` or its result code/data from `ScreenShareProvider` / its Android plugin.

- [x] **9.2.6** **Ensure the image attachment is correctly sent to the LLM:**
  - After capture, `captureAndSend` calls `coordinator.handleMiniMenuReplyWithImages()`.
  - This calls `_handleNotificationReplyInternal(images: [image])`.
  - The image is attached to a `Message(role: user, images: [image])`.
  - Verify the API configuration supports image attachments (vision models like GPT-4o, Claude).
  - Verify the message builder correctly serializes `ImageAttachment.base64Data` in the API request body.

- [x] **9.2.7** **Test the full screenshot flow end-to-end after fix:**
  1. Open mini menu → General tab → enter optional message → click Screenshot.
  2. Menu closes → 300ms delay → permission dialog (if first time) → capture.
  3. Image + message sent to LLM → assistant response → notification with response.

#### 9.3 Mini Menu State Synchronization Fix

> **Symptom:** The Touch-Through toggle and Notification toggle in the General tab do not reflect the actual current state when the mini menu is opened. The toggles start in a default (unchecked) state instead of the actual state.
>
> **Root Cause Analysis:** The `refreshMiniMenuFromFlutter()` method (line 1557–1591 of `Live2DOverlayService.kt`) correctly calls `miniMenuGetTouchThroughEnabled` and `miniMenuGetNotificationEnabled` via the method channel. However, the Dart-side handlers may not be returning the correct state, or the response may arrive after the UI renders.

- [x] **9.3.1** **Debug the touch-through state sync:**
  - Dart handler in `main.dart` (line 267–269): `getTouchThroughEnabled` calls `Live2DSettings.load()` which reads from persistent storage.
  - **Problem:** `Live2DSettings.load()` is an async file read. If the saved state doesn't match the runtime state of the overlay, the toggle will be wrong.
  - **Fix:** Instead of loading from persistent storage, read the **actual runtime state** from `Live2DOverlayService`. The overlay service already has `touchThroughEnabled` as a field — use it directly in the `refreshMiniMenuFromFlutter()` method instead of calling Dart:
    ```kotlin
    // In refreshMiniMenuFromFlutter():
    miniMenuTouchToggle?.let { toggle ->
        toggle.setOnCheckedChangeListener(null)
        toggle.isChecked = touchThroughEnabled  // Use the service's actual field directly
        // Re-attach listener...
    }
    ```
  - This eliminates the need for the method channel round-trip for touch-through state.

- [x] **9.3.2** **Debug the notification enabled state sync:**
  - Dart handler in `main.dart` (line 255–258): `getNotificationsEnabled` reads `notificationSettingsProvider.notificationSettings.notificationsEnabled`.
  - **Verify:** This provider may not be updated when the method channel call arrives from the overlay service, because the ProxyProvider may not have rebuilt yet.
  - **Fix:** Add `debugPrint` to confirm the returned value matches expectations.
  - If the value is stale, consider calling `notificationSettingsProvider.loadSettings()` before returning the value.

- [x] **9.3.3** **Set initial toggle states synchronously on menu open:**
  - In `showMiniMenuWindow()` (line 1284–1375), set the touch-through toggle immediately from the service's own state before the async refresh:
    ```kotlin
    // After building the UI, before calling refreshMiniMenuFromFlutter():
    miniMenuTouchToggle?.isChecked = touchThroughEnabled
    ```
  - For the notification toggle, call `refreshMiniMenuFromFlutter()` and accept the small delay.

- [x] **9.3.4** **Ensure toggle changes propagate back correctly:**
  - Touch-through toggle change → calls `miniMenuToggleTouchThrough` → Dart `Live2DQuickToggleService.instance.toggleTouchThrough()` → this should update both the overlay state AND persist the change.
  - Notification toggle change → calls `miniMenuSetNotificationEnabled` → Dart `notificationSettingsProvider.setNotificationsEnabled()` → this should save the setting and (if disabling) stop the proactive timer.
  - **Verify:** After toggling, call `refreshMiniMenuFromFlutter()` to re-read the state and confirm propagation.

- [x] **9.3.5** **Test sync end-to-end:**
  1. Enable touch-through from main app → open menu → verify toggle is ON.
  2. Disable touch-through from menu → close menu → verify overlay is no longer touch-through.
  3. Disable notifications from main app → open menu → verify notification toggle is OFF.
  4. Enable notifications from menu → close menu → verify proactive starts firing.

#### 9.4 Input Tab Send Message Fix

> **Symptom:** Clicking "Send" in the Input tab shows `not_implemented` error. This means the `miniMenuSendMessage` method channel call from Android reaches Flutter but `_handleMethodCall` returns `notImplemented()`.
>
> **Root Cause Analysis:** The `MiniMenuService._handleMethodCall()` dispatches to `_sendMessage` (line 100 of `mini_menu_service.dart`). The `_sendMessage` callback is set in `configure()` (line 58) with a handler that calls `coordinator.handleMiniMenuReply()`. The `not_implemented` return means **either:**
> 1. `configure()` was never called (so `_sendMessage` is null and the handler returns null), OR
> 2. The method channel call is being routed to a different `MethodChannel` handler that doesn't have the method registered.
>
> **Most likely:** The method channel `com.example.flutter_application_1/mini_menu` is registered in both `MainActivity` (line 223–246) and `Live2DOverlayService` (line 1226–1228). The Android side of the mini menu calls methods via `Live2DOverlayService.miniMenuChannel()`, which creates a `MethodChannel` using the `FlutterEngineCache` engine. But the Dart side `MiniMenuService` registers its handler on the **same** channel name. If the Dart handler is set up correctly via `_channel.setMethodCallHandler(_handleMethodCall)`, then any method call from Android should route to it.
>
> The issue may be that `MiniMenuService.configure()` (which calls `_channel.setMethodCallHandler`) hasn't been called yet when the first method call arrives. The `configure()` is called inside a `ProxyProvider4.update()` in `main.dart` — this only runs when one of the dependencies changes. **If the mini menu is opened before any provider updates, `configure()` may not have run yet.**

- [x] **9.4.1** **Verify `MiniMenuService.configure()` is called on app startup:**
  - Add `debugPrint('MiniMenuService: configure() called, _initialized=$_initialized')` at the start of `configure()`.
  - Check if `configure()` runs before the mini menu is opened.
  - **Fix if not called:** Move the `setMethodCallHandler` registration to the `MiniMenuService` constructor or `MiniMenuService.instance` initialization, so the handler is always registered regardless of whether `configure()` has been called.

- [x] **9.4.2** **Handle the case where `_sendMessage` is null:**
  - In `_handleMethodCall`, the `miniMenuSendMessage` case returns `_sendMessage?.call(...)` — if `_sendMessage` is null, it returns `null`. But `null` is NOT the same as `notImplemented()`.
  - The `notImplemented()` callback in `invokeMiniMenuMethod()` (line 1250–1252 of `Live2DOverlayService.kt`) is triggered when the **Dart side explicitly returns `notImplemented`** — this happens when NO handler is set on the channel at all (`_channel.setMethodCallHandler` was never called).
  - **Confirm:** This means `_initialized` is `false` and `setMethodCallHandler` hasn't been called.

- [x] **9.4.3** **Fix: Register method handler eagerly in MiniMenuService:**
  ```dart
  class MiniMenuService {
    MiniMenuService._internal() {
      // Register handler immediately on construction
      _channel.setMethodCallHandler(_handleMethodCall);
    }
    // ...
    // In configure(), remove the _initialized guard for setMethodCallHandler
    void configure({...}) {
      _getActiveSessionId = getActiveSessionId;
      _getMessages = getMessages;
      _sendMessage = sendMessage;
      _captureAndSend = captureAndSend;
      // ... set all handlers
      // No longer need to call setMethodCallHandler here
    }
  }
  ```
  This ensures the Dart side always has a handler for the method channel, even if the specific callbacks haven't been configured yet. If a callback is null, it returns a meaningful error (`handler_unavailable`) instead of `notImplemented`.

- [x] **9.4.4** **Ensure `handleMiniMenuReply` works correctly:**
  - The `sendMessage` callback in `main.dart` (line 223–229) calls `coordinator.handleMiniMenuReply()`.
  - `handleMiniMenuReply()` (line 137–150 of `notification_coordinator.dart`) calls `_handleNotificationReplyInternal()`.
  - This is the **same pipeline** as notification reply — verify it works with the same preset resolution (Path 3 in F4: `notificationSettings.apiPresetId` and `notificationSettings.promptPresetId`).

- [x] **9.4.5** **Test the Input tab Send:**
  1. Open mini menu → Input tab.
  2. Type a message → click Send.
  3. Verify "Responding..." status appears.
  4. Verify assistant response appears in the chat history.
  5. Verify the message appears in the main chat screen.

#### 9.5 Input Tab Chat History Fix

> **Symptom:** The Input tab's message list is empty even when there are messages in the active session.
>
> **Root Cause Analysis:** Same as §9.4 — `miniMenuGetMessages` is also routed through the method channel, and if `_handleMethodCall` is not registered, the call returns `notImplemented`. Additionally, `refreshMessages()` (line 1593–1608 of `Live2DOverlayService.kt`) calls the method channel and then `renderMessages()`.

- [x] **9.5.1** After applying fix **9.4.3** (eager handler registration), verify that `miniMenuGetMessages` returns the correct message list.

- [x] **9.5.2** **Verify message serialization:**
  - The `getMessages` handler in `main.dart` (line 210–222) maps each `Message` to `{'id', 'role', 'content', 'timestamp'}`.
  - `renderMessages()` in `Live2DOverlayService.kt` (line 1611–1634) reads `role` and `content` from the returned list.
  - Verify the Dart→Android serialization doesn't lose data (Dart `List<Map>` → Android `List<Map<*, *>>`).

- [x] **9.5.3** **Verify auto-scroll works:**
  - After `renderMessages()` populates the `miniMenuMessagesContainer`, the `ScrollView` parent should auto-scroll to the bottom.
  - Add `scrollView.post { scrollView.fullScroll(View.FOCUS_DOWN) }` after rendering, if not already present.

- [x] **9.5.4** **Verify real-time updates:**
  - The mini menu polls every 2 seconds via `startMiniMenuPolling()` (line 1396–1406) calling `refreshMiniMenuFromFlutter()` which calls `refreshMessages()`.
  - After a message is sent (§9.4), the polling should pick up the new messages.
  - Test: Send a message → wait 2 seconds → verify the new user+assistant messages appear.

---

## Implementation Order (Recommended)

| Phase | Tasks | Dependencies |
|-------|-------|-------------|
| **Phase 1** | Pre1 §1 (Proactive subordination) | None |
| **Phase 2a** | Pre1 §2.0 (Notification architecture refactoring — overlay simplification) | None |
| **Phase 2b** | Pre1 §2.1–2.2 (Standalone notification fix & reply chain debug) | Phase 2a |
| **Phase 2c** | Pre1 §2.3–2.4 (Notification test UI) | Phase 2b |
| **Phase 3** | Pre1 §3 (Reply preset wiring + API call path isolation) | Phase 2b |
| **Phase 4** | Pre1 §4 (Notification bar UI: overlay simplification + standalone Reply/Menu) | Phase 2a |
| **Phase 5** | Main1 §5 (Popup menu architecture) | Phase 4 |
| **Phase 6** | Main1 §6 (General tab) | Phase 5 |
| **Phase 7** | Main1 §7 (Input tab / mini chat) | Phase 5, Phase 3 |
| **Phase 8** | Main1 §8 (Settings tab placeholder) | Phase 5 |
| **Phase 9** | Post1 §9 (Bug fixes from live testing) | Phase 6, 7, 8 |

### Phase 9 — Recommended Sub-Order

| Sub-Phase | Task | Rationale |
|-----------|------|-----------|
| **9a** | §9.4 (Input tab Send fix — eager handler) | Unblocks §9.5 and likely fixes §9.3 state sync too. Highest impact single fix. |
| **9b** | §9.5 (Input tab Chat History) | Depends on §9.4. Should work after handler registration fix. |
| **9c** | §9.3 (State sync — touch-through & notification toggles) | Independent fix. Use direct service field for touch-through. |
| **9d** | §9.1 (Test notification re-reply) | Investigate sessionId flow. Relatively isolated. |
| **9e** | §9.2 (Screenshot full pipeline) | Most complex. Requires permission flow rework. Do last. |

---

## Key Files Reference

| File | Purpose |
|------|---------|
| `lib/models/notification_settings.dart` | NotificationSettings model (notificationsEnabled, promptPresetId, apiPresetId) — used for **reply** presets (Path 3) |
| `lib/models/proactive_response_settings.dart` | ProactiveResponseSettings model (enabled, scheduleText, promptPresetId, apiPresetId) — used for **proactive** presets (Path 2) |
| `lib/providers/notification_settings_provider.dart` | Provider managing both notification & proactive settings |
| `lib/services/notification_bridge.dart` | Dart ↔ Android method channel bridge for standalone notifications |
| `lib/services/notification_coordinator.dart` | Central coordinator for reply handling & proactive triggering |
| `lib/services/proactive_response_service.dart` | Timer-based proactive response service |
| `lib/services/mini_menu_service.dart` | Dart-side mini menu method channel handler & callbacks |
| `lib/screens/notification_settings_screen.dart` | Notification settings UI screen |
| `lib/services/screen_capture_service.dart` | Screen capture method channel service |
| `lib/providers/screen_capture_provider.dart` | Screen capture state management |
| `lib/services/live2d_quick_toggle_service.dart` | Touch-through quick toggle |
| `lib/providers/chat_session_provider.dart` | Chat session & message management |
| `lib/screens/chat_screen.dart` | Main chat screen (reference for mini chat) |
| `android/.../notifications/NotificationHelper.kt` | **Standalone** notification builder & delivery (Reply/Menu) |
| `android/.../notifications/NotificationActionReceiver.kt` | Handles notification reply/menu actions |
| `android/.../notifications/NotificationActionStore.kt` | Queues pending actions for Flutter |
| `android/.../notifications/NotificationConstants.kt` | Notification channel/action constants |
| `android/.../live2d/overlay/Live2DOverlayService.kt` | Overlay foreground service + mini menu overlay + method channel calls |
| `android/.../ScreenCapturePlugin.kt` | MediaProjection-based screen capture (permission + capture logic) |
| `android/.../MainActivity.kt` | Flutter engine + method channel registration |
| `lib/features/live2d/data/services/live2d_overlay_service.dart` | Dart-side overlay service wrapper |

---

## Risk & Notes

1. **Migration impact on overlay notification reply users:** The overlay notification's reply feature (via `NotificationLayoutState.REPLY`) is being removed. Users who relied on replying from the overlay notification will now use the standalone notification's Reply button. Ensure the standalone notification is always visible when proactive responses fire, so users can still reply.

2. **Popup menu as Android native overlay:** Since the popup uses `TYPE_APPLICATION_OVERLAY`, it requires the same `SYSTEM_ALERT_WINDOW` permission as the Live2D overlay. If the overlay is already active, permission is already granted. If not, a permission request flow is needed before showing the menu.

3. **Method channel bidirectional communication:** The mini menu (native Android) needs to communicate extensively with Flutter (chat history, send messages, capture screen). This requires either:
   - Extending the existing `Live2DEventStreamHandler` event stream, OR
   - Creating a dedicated method channel for the mini menu.

4. **Screenshot timing:** The popup menu must be fully dismissed before the screen capture occurs. A delay of ~300ms should be sufficient, but this may need tuning on slower devices.

5. **Chat history in native UI:** Rendering chat history in an Android native overlay requires either:
   - A `RecyclerView` with custom message bubble views, OR
   - A `WebView` rendering the chat in HTML/CSS.
   - Recommendation: Use a simple `RecyclerView` for performance.

6. **Thread safety:** All chat session mutations must go through `ChatSessionProvider.runSerialized()` to prevent race conditions between the mini menu input, notification replies, and proactive responses.

7. **Preset isolation (Finding F4):** The three API call paths (main chat, proactive, reply) must each resolve their own presets independently. This is a critical correctness requirement — mixing presets across paths would cause unexpected behavior (e.g., proactive using the reply API key or vice versa).

8. **Backward compatibility of overlay notification removal:** The `Live2DOverlayService` (Dart-side) calls `setNotificationResponse()` / `setNotificationError()` to update the overlay notification content. After migration, these calls need to be redirected to update the **standalone** notification instead, or removed entirely if the standalone notification already handles this via `NotificationBridge.showPreResponseNotification()`.

9. **Screenshot permission from Service context (§9.2):** `ScreenCapturePlugin.requestPermission()` requires `startActivityForResult()` which only works from an Activity. When the mini menu triggers capture from `Live2DOverlayService`, the Activity may not be visible. The recommended approach is to either (a) bring `MainActivity` to foreground briefly for permission, or (b) reuse the already-stored MediaProjection result code/data from a previous `ScreenShareProvider` permission grant. If neither is available, the screenshot feature must gracefully show an error telling the user to grant permission from the main app first.

10. **MiniMenuService method handler registration timing (§9.4):** The `setMethodCallHandler` must be registered before any method call arrives from Android. The current implementation defers registration to `configure()` which may not have been called yet. Moving registration to the constructor ensures it's always ready.

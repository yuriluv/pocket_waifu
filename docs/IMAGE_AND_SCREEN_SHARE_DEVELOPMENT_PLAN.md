# Image Attachment & Screen Share Development Plan

> **Version**: 1.0  
> **Date**: 2026-03-01  
> **Status**: Draft  
> **Target Release**: v1.1.0

---

## Table of Contents

1. [Executive Summary](#1-executive-summary)
2. [Current State Analysis](#2-current-state-analysis)
3. [Feature 1 — Image Attachment on Main Chat Screen](#3-feature-1--image-attachment-on-main-chat-screen)
4. [Feature 2 — Android Screen Share for LLM Screenshots](#4-feature-2--android-screen-share-for-llm-screenshots)
5. [Feature 3 — Screen Share Menu Tab & Permission Settings](#5-feature-3--screen-share-menu-tab--permission-settings)
6. [Implementation Phases](#6-implementation-phases)
7. [Risk Assessment & Mitigations](#7-risk-assessment--mitigations)
8. [Future Extensions](#8-future-extensions)
9. [Appendix — API Payload Reference](#9-appendix--api-payload-reference)

---

## 1. Executive Summary

This plan covers three interconnected features to be delivered in the next update cycle:

| # | Feature | Summary |
|---|---------|---------|
| 1 | **Image Attachment** | Allow users to attach images from the gallery/camera directly in the main chat input and send them to the LLM as multimodal content. |
| 2 | **Screen Share → Screenshot Capture** | Leverage Android's `MediaProjection` API to capture the device screen and forward screenshots to the LLM as image context. |
| 3 | **Screen Share Menu Tab** | Add a dedicated *Screen Share* section in the navigation drawer with permission management UI, designed for future extensibility. |

---

## 2. Current State Analysis

### 2.1 How Data Is Currently Delivered to the LLM

The current data pipeline is **text-only**. The full flow is:

```
User Input (text)
    │
    ▼
ChatScreen._sendMessage()
    │  passes: userMessage, character, settings, apiConfig
    ▼
ChatProvider.sendMessage()
    │  builds PromptBlocks, retrieves past Message list
    ▼
ApiService.sendMessageWithBlocks()
    │  calls PromptBuilder.buildMessagesForApi()
    │  produces: List<Map<String, String>>  ← text-only {"role": ..., "content": ...}
    ▼
ApiService.sendMessageWithConfig()
    │  applies _applyPromptLifecycle() (Regex + Lua hooks)
    ▼
┌───────────────────────┐    ┌───────────────────────┐
│ _sendToOpenAICompatible│    │   _sendToAnthropic    │
│                       │    │                       │
│  messages: [          │    │  messages: [          │
│    {"role","content"} │    │    {"role","content"} │
│  ]                    │    │  ]                    │
│  → text strings only  │    │  → text strings only  │
└───────────────────────┘    └───────────────────────┘
```

**Key observations:**

- `Message` model contains `String content` — no binary/image field.
- `PromptBuilder.buildMessagesForApi()` returns `List<Map<String, String>>` — content is always a plain string.
- `_buildOpenAICompatibleRequestBody()` passes `messages` as-is into the JSON payload.
- `_buildAnthropicRequestBody()` passes `messages` as-is into the JSON payload.
- Neither builder supports the **multimodal content array** format required by vision-capable models.
- The chat input widget (`_MessageInput`) only contains a `TextField` and a send `IconButton` — no attachment button exists.

### 2.2 What Needs to Change for Image Support

Both OpenAI and Anthropic vision APIs expect messages in a **multimodal content array** format instead of a plain string:

```json
// OpenAI Vision format
{
  "role": "user",
  "content": [
    { "type": "text", "text": "What's in this image?" },
    { "type": "image_url", "image_url": { "url": "data:image/png;base64,..." } }
  ]
}

// Anthropic Vision format
{
  "role": "user",
  "content": [
    { "type": "text", "text": "What's in this image?" },
    { "type": "image", "source": { "type": "base64", "media_type": "image/png", "data": "..." } }
  ]
}
```

This means the message type must shift from `Map<String, String>` to `Map<String, dynamic>` for the `content` field.

---

## 3. Feature 1 — Image Attachment on Main Chat Screen

### 3.1 Goals

- Add an **image attachment button** (📎 or 🖼️) next to the text input on the chat screen.
- Support image selection from **gallery** and **camera**.
- Display a **thumbnail preview** of the attached image before sending.
- Encode the image as **base64** and include it in the API payload using the correct multimodal format for each provider.

### 3.2 Affected Files & Changes

| File | Change |
|------|--------|
| `lib/models/message.dart` | Add optional `List<ImageAttachment>? images` field to `Message` model. Add `ImageAttachment` class with `base64Data`, `mimeType`, `thumbnailPath`. |
| `lib/services/prompt_builder.dart` | Update `buildMessagesForApi()` return type from `List<Map<String, String>>` to `List<Map<String, dynamic>>`. When images are present, build multimodal content arrays. |
| `lib/services/api_service.dart` | Change message type signatures from `Map<String, String>` to `Map<String, dynamic>` throughout the pipeline. |
| `lib/screens/chat_screen.dart` | Add `_attachImage()` method. Update `_MessageInput` widget to include an attachment icon button. Add image preview widget above input when image is staged. |
| `lib/providers/chat_provider.dart` | Update `sendMessage()` to accept optional `List<ImageAttachment>` parameter. |
| `pubspec.yaml` | Add `image_picker` dependency. |

### 3.3 Detailed Design

#### 3.3.1 `ImageAttachment` Model

```dart
class ImageAttachment {
  final String id;
  final String base64Data;
  final String mimeType;     // "image/png", "image/jpeg", etc.
  final int    width;
  final int    height;
  final String? thumbnailPath;

  const ImageAttachment({
    required this.id,
    required this.base64Data,
    required this.mimeType,
    this.width = 0,
    this.height = 0,
    this.thumbnailPath,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'base64Data': base64Data,
    'mimeType': mimeType,
    'width': width,
    'height': height,
  };
}
```

#### 3.3.2 Multimodal Message Builder

```dart
// In PromptBuilder — new helper
List<dynamic> _buildMultimodalContent(String text, List<ImageAttachment> images) {
  final List<dynamic> parts = [];
  
  if (text.isNotEmpty) {
    parts.add({'type': 'text', 'text': text});
  }
  
  for (final img in images) {
    parts.add({
      'type': 'image_url',
      'image_url': {
        'url': 'data:${img.mimeType};base64,${img.base64Data}',
      },
    });
  }
  
  return parts;
}
```

#### 3.3.3 Chat Input UI Changes

```
┌─────────────────────────────────────────────┐
│  [📷 Attach]  [ Text Input Field ...      ] [➤ Send] │
│                                             │
│  ┌──────┐  (thumbnail preview if attached)  │
│  │ 🖼️  │  × remove                         │
│  └──────┘                                   │
└─────────────────────────────────────────────┘
```

### 3.4 Image Size & Encoding Strategy

| Setting | Value | Rationale |
|---------|-------|-----------|
| Max resolution | 1024×1024 px | Balance between quality and token cost |
| Max file size | 5 MB (before encoding) | API limits vary; this is a safe default |
| Encoding | Base64 inline | Avoids external URL hosting requirements |
| Format | JPEG (quality 85) | Best compression for photos |
| Compression | Resize + quality reduction | Applied before base64 encoding |

---

## 4. Feature 2 — Android Screen Share for LLM Screenshots

### 4.1 Goals

- Use Android's `MediaProjection` API to capture the current device screen.
- Provide a **one-tap screenshot** button that captures the screen and sends it to the LLM.
- Optionally support **periodic auto-capture** for continuous context mode (future phase).

### 4.2 Technical Approach

```
User taps "Share Screen" → Permission check
    │
    ▼
MediaProjection permission dialog (Android system)
    │  user grants
    ▼
MediaProjection → VirtualDisplay → ImageReader
    │
    ▼
Capture single frame as Bitmap
    │
    ▼
Compress to JPEG → Base64 encode
    │
    ▼
Create ImageAttachment → Inject into message pipeline
    │
    ▼
Send to LLM via existing multimodal pathway (Feature 1)
```

### 4.3 Platform Channel Design

A new `MethodChannel` will bridge Flutter ↔ Android native code:

```dart
// Flutter side
class ScreenCaptureService {
  static const _channel = MethodChannel('com.pocketwaifu/screen_capture');

  /// Request MediaProjection permission. Returns true if granted.
  Future<bool> requestPermission() async {
    return await _channel.invokeMethod('requestPermission');
  }

  /// Check if permission is currently granted.
  Future<bool> hasPermission() async {
    return await _channel.invokeMethod('hasPermission');
  }

  /// Capture current screen. Returns base64-encoded JPEG.
  Future<String?> captureScreen() async {
    return await _channel.invokeMethod('captureScreen');
  }

  /// Release MediaProjection resources.
  Future<void> release() async {
    await _channel.invokeMethod('release');
  }
}
```

```kotlin
// Android native side (Kotlin)
class ScreenCapturePlugin : MethodCallHandler {
  private var mediaProjection: MediaProjection? = null
  private var virtualDisplay: VirtualDisplay? = null
  private var imageReader: ImageReader? = null

  override fun onMethodCall(call: MethodCall, result: Result) {
    when (call.method) {
      "requestPermission" -> requestMediaProjection(result)
      "hasPermission"     -> result.success(mediaProjection != null)
      "captureScreen"     -> captureScreenshot(result)
      "release"           -> releaseResources(result)
      else                -> result.notImplemented()
    }
  }
}
```

### 4.4 Affected Files & Changes

| File | Change |
|------|--------|
| `lib/services/screen_capture_service.dart` | **NEW** — Flutter-side MethodChannel wrapper |
| `android/app/src/main/kotlin/.../ScreenCapturePlugin.kt` | **NEW** — Native MediaProjection handler |
| `android/app/src/main/kotlin/.../MainActivity.kt` | Register the MethodChannel plugin |
| `android/app/src/main/AndroidManifest.xml` | Add `FOREGROUND_SERVICE_MEDIA_PROJECTION` permission and new foreground service declaration |
| `lib/screens/chat_screen.dart` | Add screen capture button (conditionally visible when permission granted) |
| `lib/providers/screen_capture_provider.dart` | **NEW** — State management for capture permission & last screenshot |

### 4.5 Required Android Permissions

```xml
<!-- Screen capture via MediaProjection -->
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_MEDIA_PROJECTION" />

<!-- Foreground service for MediaProjection (required on Android 14+) -->
<service
    android:name=".screencapture.ScreenCaptureService"
    android:exported="false"
    android:foregroundServiceType="mediaProjection" />
```

---

## 5. Feature 3 — Screen Share Menu Tab & Permission Settings

### 5.1 Goals

- Add a new **"Screen Share"** (화면 공유) section in the `MenuDrawer`.
- Provide a dedicated settings screen for **permission management**.
- Design the settings architecture to be **extensible** for future features that may also require screen-related permissions.

### 5.2 Menu Drawer Update

Add a new section between "Live2D" and "도움말" in `menu_drawer.dart`:

```
─────────────────────────
  📺 Screen Share (화면 공유)
─────────────────────────
  [🛡️] Screen Share Settings
        Permission & capture options
─────────────────────────
```

### 5.3 Screen Share Settings Screen

**`lib/screens/screen_share_settings_screen.dart`** — NEW

```
┌─────────────────────────────────────────┐
│         Screen Share Settings           │
├─────────────────────────────────────────┤
│                                         │
│  📋 Permission Status                   │
│  ┌─────────────────────────────────┐    │
│  │ Screen Capture     ● Granted   │    │
│  │                    [Revoke]     │    │
│  │                                │    │
│  │ (If not granted)               │    │
│  │ Screen Capture     ○ Not Set   │    │
│  │                    [Grant]     │    │
│  └─────────────────────────────────┘    │
│                                         │
│  ⚙️ Capture Settings                    │
│  ┌─────────────────────────────────┐    │
│  │ Auto-attach to message  [OFF]  │    │
│  │ Image quality       [Medium ▼] │    │
│  │ Max resolution      [1024 ▼]   │    │
│  └─────────────────────────────────┘    │
│                                         │
│  ℹ️ Screen sharing allows the AI to     │
│  see your screen content. Screenshots   │
│  are processed locally and sent only    │
│  when you explicitly trigger capture.   │
│                                         │
│  🔮 Coming Soon                         │
│  ┌─────────────────────────────────┐    │
│  │ • Continuous capture mode       │    │
│  │ • Region selection              │    │
│  │ • App-specific capture          │    │
│  └─────────────────────────────────┘    │
│                                         │
└─────────────────────────────────────────┘
```

### 5.4 Settings Model Extension

```dart
// In lib/models/screen_share_settings.dart — NEW
class ScreenShareSettings {
  final bool isPermissionGranted;
  final bool autoAttachToMessage;
  final ImageQuality imageQuality;
  final int maxResolution;

  const ScreenShareSettings({
    this.isPermissionGranted = false,
    this.autoAttachToMessage = false,
    this.imageQuality = ImageQuality.medium,
    this.maxResolution = 1024,
  });

  // Extensible: future features can add fields here
  // e.g., continuousCaptureInterval, regionRect, targetAppPackage
}

enum ImageQuality { low, medium, high }
```

### 5.5 Affected Files & Changes

| File | Change |
|------|--------|
| `lib/screens/menu_drawer.dart` | Add new "Screen Share" section with `_DrawerMenuItem` |
| `lib/screens/screen_share_settings_screen.dart` | **NEW** — Permission management & settings UI |
| `lib/models/screen_share_settings.dart` | **NEW** — Settings data model |
| `lib/providers/screen_share_provider.dart` | **NEW** — State management (extends `ChangeNotifier`) |
| `lib/main.dart` | Register `ScreenShareProvider` in the `MultiProvider` |

---

## 6. Implementation Phases

### Phase 1 — Foundation (Week 1)

> Adapt the existing text-only pipeline to support multimodal content.

- [ ] Update `Message` model to include optional image attachments
- [ ] Change API pipeline type signatures from `Map<String, String>` to `Map<String, dynamic>`
- [ ] Implement multimodal content builder in `PromptBuilder`
- [ ] Update `_buildOpenAICompatibleRequestBody` to handle content arrays
- [ ] Update `_buildAnthropicRequestBody` to handle Anthropic vision format
- [ ] Add image compression/resize utility class

### Phase 2 — Image Attachment UI (Week 2)

> Add image picking and preview on the chat screen.

- [ ] Add `image_picker` dependency to `pubspec.yaml`
- [ ] Create `ImageAttachment` model
- [ ] Implement `_attachImage()` in `ChatScreen`
- [ ] Update `_MessageInput` widget with attachment button
- [ ] Add thumbnail preview strip above input
- [ ] Update `ChatProvider.sendMessage()` to pass images through
- [ ] End-to-end test: pick image → preview → send → LLM receives

### Phase 3 — Screen Capture Service (Week 3)

> Implement Android-native screen capture via MediaProjection.

- [ ] Create `ScreenCapturePlugin.kt` native handler
- [ ] Register MethodChannel in `MainActivity.kt`
- [ ] Add required permissions to `AndroidManifest.xml`
- [ ] Create `ScreenCaptureService` Flutter wrapper
- [ ] Create `ScreenCaptureProvider` for state management
- [ ] Add capture button on chat screen (next to image attach)
- [ ] Test on physical Android device (emulator does not support MediaProjection well)

### Phase 4 — Screen Share Settings UI (Week 4)

> Build the menu integration and settings screen.

- [ ] Create `ScreenShareSettings` model
- [ ] Create `ScreenShareSettingsScreen` UI
- [ ] Add "Screen Share" section to `MenuDrawer`
- [ ] Register provider in `main.dart`
- [ ] Persist settings via `SharedPreferences`
- [ ] Permission grant/revoke workflow
- [ ] Final integration testing

---

## 7. Risk Assessment & Mitigations

| Risk | Severity | Mitigation |
|------|----------|------------|
| Large base64 images exceed API token limits | High | Enforce max resolution (1024px) and JPEG compression. Show warning on large images. |
| MediaProjection permission prompt confuses users | Medium | Add clear explanation dialog before triggering system prompt. Add help text in settings. |
| Some LLM endpoints don't support vision | High | Check `ApiConfig` for vision support flag. Gracefully fall back to text-only with error message. |
| Samsung/OEM aggressive background kill interrupts MediaProjection | Medium | Use foreground service (already established pattern in the app). Add battery optimization check. |
| Base64 encoding increases memory usage significantly | Medium | Process images in isolates. Limit to 1 image per message initially. |
| Breaking change to `Map<String, String>` → `Map<String, dynamic>` | High | Migration must be comprehensive — grep all call sites. Add backward compatibility for text-only messages. |

---

## 8. Future Extensions

The settings architecture is designed to be extensible. Planned future integrations:

| Feature | Connects With | Settings Extension |
|---------|---------------|-------------------|
| **Continuous Capture Mode** | Screen Share | Add interval slider, start/stop toggle |
| **Region Selection** | Screen Share | Add crop rectangle selector |
| **App-Specific Capture** | Screen Share | Add app picker, package name filter |
| **Live2D + Screen Context** | Live2D, Screen Share | Character reacts to screen content |
| **Proactive Screen Analysis** | Proactive Response, Screen Share | Auto-analyze screen periodically |
| **OCR Text Extraction** | Screen Share | Extract text from screenshots before sending (reduce tokens) |

---

## 9. Appendix — API Payload Reference

### OpenAI Vision API Format

```json
{
  "model": "gpt-4o",
  "messages": [
    {
      "role": "user",
      "content": [
        {
          "type": "text",
          "text": "What is in this screenshot?"
        },
        {
          "type": "image_url",
          "image_url": {
            "url": "data:image/jpeg;base64,/9j/4AAQ..."
          }
        }
      ]
    }
  ],
  "max_tokens": 1024
}
```

### Anthropic Vision API Format

```json
{
  "model": "claude-sonnet-4-20250514",
  "messages": [
    {
      "role": "user",
      "content": [
        {
          "type": "text",
          "text": "What is in this screenshot?"
        },
        {
          "type": "image",
          "source": {
            "type": "base64",
            "media_type": "image/jpeg",
            "data": "/9j/4AAQ..."
          }
        }
      ]
    }
  ],
  "max_tokens": 1024
}
```

### Current App Message Format (Text-Only — Before Change)

```json
{
  "messages": [
    { "role": "system", "content": "You are a character..." },
    { "role": "user", "content": "Hello!" }
  ]
}
```

### Target App Message Format (Multimodal — After Change)

```json
{
  "messages": [
    { "role": "system", "content": "You are a character..." },
    {
      "role": "user",
      "content": [
        { "type": "text", "text": "What do you see?" },
        { "type": "image_url", "image_url": { "url": "data:image/jpeg;base64,..." } }
      ]
    }
  ]
}
```

---

> [!IMPORTANT]
> The migration from `Map<String, String>` to `Map<String, dynamic>` in the API pipeline is the most critical and risky change. All existing call sites must be audited to prevent type errors. Text-only messages should continue to work with plain string `content` for backward compatibility.

> [!NOTE]
> MediaProjection testing **requires a physical Android device**. The Android emulator has limited support for screen capture APIs. Plan device testing sessions accordingly.

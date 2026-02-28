# Live2D Motion System — Overhaul Plan

> **Date:** 2026-02-28  
> **Scope:** Complete restructuring of the Live2D motion/interaction/gesture settings.  
> **Approach:** Problem → Root Cause → Solution → Implementation Spec, for every item.

---

## Table of Contents

1. [Executive Summary](#executive-summary)
2. [Current Architecture Diagnosis](#current-architecture-diagnosis)
3. [Problems & Solutions](#problems--solutions)
   - [P1: Redundant & Overlapping Settings Screens](#p1-redundant--overlapping-settings-screens)
   - [P2: Interaction Test is Non-Functional](#p2-interaction-test-is-non-functional)
   - [P3: Auto Behavior Settings Are Disconnected](#p3-auto-behavior-settings-are-disconnected)
   - [P4: Gesture Mapping is Duplicated and Disconnected](#p4-gesture-mapping-is-duplicated-and-disconnected)
   - [P5: Dual Config Systems Create Data Conflicts](#p5-dual-config-systems-create-data-conflicts)
   - [P6: No Model-Awareness in Motion Settings](#p6-no-model-awareness-in-motion-settings)
   - [P7: Auto-Motion Idle Looping Not Implemented](#p7-auto-motion-idle-looping-not-implemented)
   - [P8: No Live Gesture Recognition Feedback](#p8-no-live-gesture-recognition-feedback)
4. [New Feature Proposals](#new-feature-proposals)
   - [F1: Auto-Motion Idle Loop System](#f1-auto-motion-idle-loop-system)
   - [F2: Composite Action Builder (Multi-Action Sequences)](#f2-composite-action-builder-multi-action-sequences)
   - [F3: Hit-Area Based Gesture Mapping](#f3-hit-area-based-gesture-mapping)
   - [F4: Motion Preview Without Overlay](#f4-motion-preview-without-overlay)
5. [New Architecture Design](#new-architecture-design)
6. [Implementation Steps](#implementation-steps)
7. [File Manifest](#file-manifest)

---

## Executive Summary

The current Live2D settings screen exposes **four overlapping entry points** for motion-related configuration:

| Current Entry Point | Screen/Widget | Lines | Status |
|---|---|---|---|
| `🎮 상호작용 테스트` (section) | `_InteractionTestTile` in `live2d_settings_screen.dart` | L418–625 | **Non-functional** — creates a new `InteractionManager` instance that doesn't share state with the real one. Events never arrive. |
| `상호작용 설정` (advanced → 3-tab screen) | `interaction_settings_screen.dart` | 1,264 lines | **Partially functional** — Motion/expression test tab works, but interaction mapping tab and auto behavior tab duplicate functionality from the other two screens. |
| `제스처 설정` (advanced) | `gesture_settings_screen.dart` | 569 lines | **Functional but redundant** — Same `GestureConfig` data as the interaction mapping tab above, but uses a separate screen. Both write to the same SharedPreferences key. |
| `자동 동작 설정` (advanced) | `auto_behavior_settings_screen.dart` | 356 lines | **Functional but duplicated** — Eye blink, breathing, look-at toggling. Also replicated as a tab inside `interaction_settings_screen.dart`. |

**Decision:** Per user request, **remove all four** and replace them with a single unified **"Motion" tab** inside the Advanced Settings area.

---

## Current Architecture Diagnosis

### Screen & Widget Map (to be removed)

```
live2d_settings_screen.dart
├─ _SectionHeader('🎮 상호작용 테스트')          ← REMOVE
│   └─ _InteractionTestTile                        ← REMOVE (420 lines)
│
└─ _AdvancedSettingsMenu
    ├─ '상호작용 설정' → InteractionSettingsScreen  ← REMOVE entry
    ├─ '제스처 설정' → GestureSettingsScreen        ← REMOVE entry
    ├─ '자동 동작 설정' → AutoBehaviorSettingsScreen ← REMOVE entry
    ├─ '디스플레이 설정' → DisplaySettingsScreen    ← KEEP
    └─ 'Lua/Regex 파이프라인' → prototype screen    ← KEEP
```

### Data Model Map (to be consolidated)

```
GestureConfig (gesture_config.dart)
├─ enableTapReaction, enableDoubleTapReaction, enableLongPressReaction
├─ enableDragPatterns, enableAreaTouch
└─ List<GestureActionMapping>
    └─ GestureActionMapping { gesture, actionType, motionGroup, motionIndex, expressionId, signalName }

InteractionConfig (interaction_config.dart)
├─ List<InteractionMapping>
│   └─ InteractionMapping { trigger, response, enabled, cooldownMs, condition, priority }
│       └─ InteractionResponse { action, motionGroup, motionIndex, motionPriority, expressionId, ... }
├─ enableTouchFeedback, autoReactionEnabled, globalCooldownMs
├─ enableTouchReaction, enableSwipeDetection, enableHeadPatDetection
└─ enableExternalSignals

AutoBehaviorSettings (auto_behavior_settings_screen.dart — model class inside screen file!)
├─ eyeBlinkEnabled, breathingEnabled, lookAtEnabled
├─ eyeBlinkInterval, breathingSpeed, lookAtSensitivity
```

> [!CAUTION]
> **Critical Issue:** There are **TWO separate config systems** (`GestureConfig` and `InteractionConfig`) that both try to map gestures to actions. They conflict with each other. The `InteractionManager` uses `InteractionConfig`, while `GestureSettingsScreen` and the `_InteractionMappingTab` write to `GestureConfig`. Neither reads the other's data. This means **settings saved in one screen are invisible to the other** and the runtime behavior is unpredictable.

### Service Layer

```
InteractionManager (327 lines)
├─ Subscribes to Live2DNativeBridge events
├─ Uses InteractionConfig to map events → responses
├─ Does NOT use GestureConfig at all
├─ Has cooldown tracking per InteractionType
└─ Executes: motion, expression, randomMotion, vibrate, signal, composite

InteractionConfigService (287 lines)
├─ loadConfig() / saveConfig()     → InteractionConfig (SharedPreferences key: 'interaction_config')
├─ loadGestureConfig() / saveGestureConfig()  → GestureConfig (SharedPreferences key: 'gesture_config')
├─ loadAutoBehaviorSettings() / saveAutoBehaviorSettings() → AutoBehaviorSettings (SharedPreferences key: 'auto_behavior_settings')
├─ saveOverlayState() / loadOverlayState() / clearOverlayState()
└─ saveRenderSettings() / loadRenderSettings()
```

---

## Problems & Solutions

### P1: Redundant & Overlapping Settings Screens

**Problem:**  
Four separate entry points (`_InteractionTestTile`, `InteractionSettingsScreen`, `GestureSettingsScreen`, `AutoBehaviorSettingsScreen`) manage closely related functionality. The user must navigate to different places to configure what should be a unified motion system. The `InteractionSettingsScreen` itself has 3 tabs that duplicate the other 2 standalone screens.

**Root Cause:**  
Organic feature growth without architectural consolidation. Each feature was added as a new screen without refactoring existing ones.

**Solution:**  
1. **Remove** from `live2d_settings_screen.dart`:
   - The entire `_SectionHeader('🎮 상호작용 테스트')` section and `_InteractionTestTile` widget (lines 272–625).
   - The `상호작용 설정` list tile in `_AdvancedSettingsMenu` (lines 635–648).
   - The `제스처 설정` list tile in `_AdvancedSettingsMenu` (lines 650–661).
   - The `자동 동작 설정` list tile in `_AdvancedSettingsMenu` (lines 663–676).
2. **Add** a single new list tile in `_AdvancedSettingsMenu`:
   ```dart
   ListTile(
     leading: const Icon(Icons.animation),
     title: const Text('모션'),
     subtitle: const Text('제스처, 자동 동작, 상호작용 테스트'),
     trailing: const Icon(Icons.chevron_right),
     onTap: () => Navigator.push(
       context,
       MaterialPageRoute(builder: (_) => const MotionSettingsScreen()),
     ),
   ),
   ```
3. **Create** a new `MotionSettingsScreen` with **3 internal tabs**:
   - **Tab 1: 제스처 & 매핑** (Gestures & Mapping)
   - **Tab 2: 자동 동작** (Auto Behavior)
   - **Tab 3: 테스트** (Interaction Test)

---

### P2: Interaction Test is Non-Functional

**Problem:**  
`_InteractionTestTile` in `live2d_settings_screen.dart` creates a **new instance** of `InteractionManager()` and tries to subscribe to its `eventStream`. However, `InteractionManager` is a singleton that was already initialized elsewhere. The test tile creates a **second** instance, which opens a **new** EventChannel subscription that never receives events because the native side only sends events to the channel already held by the first instance.

Additionally:
- When clicking "이벤트 수신 시작", `_startListening()` calls `manager.initialize()` which re-subscribes to the native bridge, potentially causing duplicate handlers.
- The "Happy 표정" and "Tap 모션" test buttons call into a freshly constructed `InteractionManager()`, not the singleton.
- No event ever shows up in the event log in practice.

**Root Cause:**  
`InteractionManager()` uses a factory constructor that returns a singleton, but `_InteractionTestTile` calls `await manager.initialize()` again each time, which re-attaches event handlers. The `eventStream` field is a `StreamController` that gets events from `_handleNativeEvent`, which is registered as a handler on `Live2DNativeBridge`. But the bridge's EventChannel receives events in its own isolate — if the overlay isn't active or the native side doesn't emit events, the stream stays empty.

**Solution:**
1. The new **Test Tab** inside `MotionSettingsScreen` must use the **existing singleton** `InteractionManager()` without calling `initialize()` again.
2. Use `InteractionManager().eventStream.listen(...)` directly.
3. Show a prominent warning if the overlay is not active: *"오버레이가 활성화되어 있어야 이벤트를 수신할 수 있습니다."*
4. Add a **"trigger from Dart"** section that calls native bridge methods directly (bypassing the event system) to verify motion/expression playback independently of gesture recognition.
5. Display the **real-time overlay state** (visible/hidden, model loaded/not) at the top of the test tab.

---

### P3: Auto Behavior Settings Are Disconnected

**Problem:**  
`AutoBehaviorSettings` is a **model class defined inside a screen file** (`auto_behavior_settings_screen.dart`, lines 9–63). This violates separation of concerns. The same model is also used as an inline tab (`_AutoBehaviorTab`) inside `interaction_settings_screen.dart` (lines 955–1263), creating **code duplication**.

When saved, `_saveSettings()` calls `_bridge.setEyeBlink()`, `_bridge.setBreathing()`, `_bridge.setLookAt()`, but:
- The `eyeBlinkInterval`, `breathingSpeed`, and `lookAtSensitivity` slider values are **never sent to the native side**. The bridge API (`setEyeBlink`, `setBreathing`, `setLookAt`) only accepts a `bool enabled` parameter — there is no API to set interval/speed/sensitivity.
- Settings are persisted in SharedPreferences but **not auto-applied on app restart**. There is no initialization code that reads saved settings and calls the native bridge at startup.

**Root Cause:**  
- The native bridge doesn't expose parameter/speed control for these features — only enable/disable.
- No startup hook applies stored settings.

**Solution:**
1. **Move** `AutoBehaviorSettings` model to its own file: `lib/features/live2d/data/models/auto_behavior_settings.dart`.
2. **Remove** the `eyeBlinkInterval`, `breathingSpeed`, `lookAtSensitivity` sliders **unless** corresponding native bridge APIs are added. If the native side supports these parameters, add corresponding bridge methods. If not, remove the sliders to avoid giving users controls that do nothing.
3. **Add auto-motion idle loop** settings here (see [F1](#f1-auto-motion-idle-loop-system)).
4. **Apply on startup:** In `Live2DController.initialize()` (or wherever the overlay initializes), load `AutoBehaviorSettings` from storage and call the relevant bridge methods.

---

### P4: Gesture Mapping is Duplicated and Disconnected

**Problem:**  
Two systems manage gesture-to-action mappings:

| System | Config Class | SharedPreferences Key | Used By |
|---|---|---|---|
| **Gesture Settings** | `GestureConfig` with `List<GestureActionMapping>` | `'gesture_config'` | `GestureSettingsScreen`, `_InteractionMappingTab` |
| **Interaction Config** | `InteractionConfig` with `List<InteractionMapping>` | `'interaction_config'` | `InteractionManager` (runtime) |

The **runtime** (`InteractionManager._processAutoReaction()`) reads from `InteractionConfig` and ignores `GestureConfig` entirely. So any mapping set via the gesture settings screen is **never executed**.

**Root Cause:**  
`GestureConfig` was added later as a simpler alternative to `InteractionConfig`, but the runtime was never updated to read from it. Both exist, neither integrated with the other.

**Solution:**
1. **Deprecate `GestureConfig`** and its `GestureActionMapping` class. Stop writing to the `'gesture_config'` SharedPreferences key.
2. **Merge** gesture mapping UI into `InteractionConfig`'s `InteractionMapping` system, since that's what the runtime actually uses.
3. The new **Gestures & Mapping tab** in `MotionSettingsScreen` should:
   - Read/write `InteractionConfig` (via `InteractionConfigService.loadConfig() / saveConfig()`).
   - Present enable/disable toggles that map to `InteractionConfig.enableTouchReaction`, `enableSwipeDetection`, `enableHeadPatDetection`.
   - Present mapping tiles that write `InteractionMapping` entries to `InteractionConfig.mappings`.
   - Show available motions/expressions from the current model (via `Live2DNativeBridge.getMotionGroups()` etc.) so users can select real motion groups/indices.
   - Allow assignment of actions to each gesture type: `tap`, `doubleTap`, `longPress`, `swipeLeft`, `swipeRight`, `swipeUp`, `swipeDown`, `headPat`, `circleCW`, `circleCCW`, `zigzag`.
4. **Remove** `gesture_config.dart`, `gesture_settings_screen.dart`, and the `GestureConfig` load/save methods from `InteractionConfigService`.
5. **Keep** `InteractionManager._processAutoReaction()` as-is — it already correctly reads `InteractionConfig`.

---

### P5: Dual Config Systems Create Data Conflicts

**Problem:**  
`InteractionConfigService` manages three separate SharedPreferences keys:
- `'interaction_config'` → `InteractionConfig`
- `'gesture_config'` → `GestureConfig`
- `'auto_behavior_settings'` → `AutoBehaviorSettings`

`InteractionConfig` has its own enable flags (`enableTouchReaction`, `enableSwipeDetection`, `enableHeadPatDetection`) that overlap with `GestureConfig`'s enable flags (`enableTapReaction`, `enableDoubleTapReaction`, `enableLongPressReaction`). When the user toggles one, the other doesn't update.

**Root Cause:**  
Same as P4 — organically added, never unified.

**Solution:**  
Consolidate into **two** stored configurations:
1. `'interaction_config'` → Unified `InteractionConfig` with gesture enable flags, all mappings, and cooldown settings.
2. `'auto_behavior_settings'` → `AutoBehaviorSettings` (kept separate since it controls a different concern — idle behaviors vs. gesture reactions).

Delete the `'gesture_config'` key on migration.

---

### P6: No Model-Awareness in Motion Settings

**Problem:**  
When the user configures a gesture mapping (e.g., "tap → play motion 'tap[0]'"), the settings screen shows motion groups and indices from the currently loaded model. But:
- If the user switches models, the saved mapping still references the old model's motion groups (e.g., `group: 'tap'`), which may not exist on the new model.
- No validation or warning on model switch.
- Default mappings reference hardcoded group names like `'tap'`, `'special'`, `'happy'`, `'greet'`, `'bow'` that may not exist.

**Root Cause:**  
Default mappings in `InteractionConfig._defaultMappings()` use generic group names. No model-change listener invalidates stale mappings.

**Solution:**
1. In the new **Gestures & Mapping tab**, when loading motion data, **cross-validate** saved mappings against the current model's actual groups/indices.
2. If a saved mapping references a non-existent group, show a ⚠️ warning badge with tooltip: *"현재 모델에 '{group}' 모션 그룹이 없습니다."*
3. Provide a **"Reset to Model Defaults"** button that auto-generates sensible mappings based on the loaded model's actual motion groups (first group → tap, second group → doubleTap, etc.).
4. Consider saving mappings **per model** in the future (model-specific `InteractionConfig` keyed by `modelId`). For now, at minimum show the warning.

---

### P7: Auto-Motion Idle Looping Not Implemented

**Problem:**  
`request2.md` §1.1.3 requires:
> "Automatic motion playback: idle motion looping toggle."

The bridge has `setAutoMotion(bool enabled)`, but:
- No UI exposes this toggle.
- `AutoBehaviorSettingsScreen` covers eye blink, breathing, look-at — but not idle motion looping.
- No way to set which motion group is used for idle looping.
- No way to set the looping interval.

**Root Cause:**  
Auto-motion was implemented at the native bridge level but never surfaced in the UI or connected to settings persistence.

**Solution:** See [F1: Auto-Motion Idle Loop System](#f1-auto-motion-idle-loop-system).

---

### P8: No Live Gesture Recognition Feedback

**Problem:**  
Users cannot tell if gesture recognition is actually working. The existing `_InteractionTestTile` is supposed to show live events but doesn't work (P2). Even when events do arrive, there is no visual feedback on the overlay itself — no ripple, highlight, or popup when a gesture is recognized.

**Root Cause:**  
No visual feedback layer in the overlay. The test tile's event listening is broken.

**Solution:**
1. In the new **Test tab**, implement a working event listener (fix P2) with:
   - Large, clear indicator showing the last recognized gesture name + timestamp.
   - Running event log (scrollable, max 50 items).
   - Color-coded badges per gesture type.
2. Add a **"Test Mode"** toggle that, when enabled:
   - Shows a semi-transparent gesture name overlay on the Live2D character when a gesture is detected (e.g., "TAP" flashes on-screen for 1 second).
   - This requires a native bridge call (e.g., `showDebugGestureFeedback(bool enabled)`) or can be simulated via Flutter toast/overlay.
3. Show real-time connection status: "이벤트 스트림: 연결됨 / 연결 안 됨".

---

## New Feature Proposals

### F1: Auto-Motion Idle Loop System

**Description:**  
Allow the user to enable automatic idle motion playback when the character has been still (no user interaction, no API-triggered motion) for a configurable duration.

**Spec:**

| Setting | Type | Default | Range |
|---|---|---|---|
| `autoMotionEnabled` | bool | false | — |
| `idleMotionGroup` | String? | null (= first available group) | Model's motion groups |
| `idleIntervalMin` | Duration | 5s | 3s – 60s |
| `idleIntervalMax` | Duration | 15s | 5s – 120s |
| `randomizeIdleMotion` | bool | true | — |

**Behavior:**
1. When `autoMotionEnabled` = true and no interaction detected for `idleIntervalMin` ~ `idleIntervalMax` (random within range):
   - If `randomizeIdleMotion`: play a random motion from `idleMotionGroup`.
   - Else: play motions sequentially (index 0, 1, 2, ..., wrap around).
2. Any user interaction (tap, swipe, etc.) immediately cancels the idle timer and resets the interval.
3. If the current model doesn't have the specified `idleMotionGroup`, fallback to the first available group.
4. Persist all settings in `AutoBehaviorSettings`.
5. Call `Live2DNativeBridge.setAutoMotion(enabled)` at the bridge level, but implement the interval/group logic in Dart (since the bridge's `setAutoMotion` is a simple boolean toggle).

**UI Location:** Auto Behavior tab → new "아이들 모션" section.

---

### F2: Composite Action Builder (Multi-Action Sequences)

**Description:**  
The `InteractionResponse` already supports `composite` actions (a list of sub-actions with delays). But the UI for configuring these doesn't exist. Allow users to build multi-step reaction sequences in the mapping dialog.

**Spec:**
- In the gesture mapping bottom sheet, add a **"복합 동작"** (Composite Action) option.
- When selected, show a list builder where the user can add ordered steps:
  - Step 1: Expression → "happy"
  - Step 2: Motion → "wave[0]" (delay: 100ms)
  - Step 3: Expression → "neutral" (delay: 2000ms)
- Each step has an optional `delayMs` field.
- Steps are reorderable by drag.
- Preview button plays the sequence.

**UI Location:** Inside the gesture mapping bottom sheet (step 3 of mapping configuration).

---

### F3: Hit-Area Based Gesture Mapping

**Description:**  
The `InteractionType` enum already includes `headTouch`, `faceTouch`, `bodyTouch`. Allow users to configure different reactions for touches on different parts of the character.

**Spec:**
- Show a silhouette/outline of the character divided into zones (head, face, body).
- Each zone can have its own gesture mapping.
- This requires the native side to report `headTouch`, `faceTouch`, `bodyTouch` events based on hit-box detection.
- If the current model doesn't define hit areas, show a notice and fall back to generic `tap`.

**Priority:** Lower priority — requires native-side hit-box data. Mark as **future enhancement**.

**UI Location:** Gestures & Mapping tab → optional "영역별 터치" section (only visible if model supports hit areas).

---

### F4: Motion Preview Without Overlay

**Description:**  
Currently, testing motions/expressions requires the overlay to be active and a model to be loaded. This is inconvenient for initial setup. Allow previewing motions in-app without the floating overlay.

**Spec:**
- Show a small embedded Live2D viewer (or a placeholder illustration) inside the Motion Test tab.
- If a full embedded viewer is not feasible (native overlay limitation), at minimum show:
  - The current model's name and thumbnail.
  - A "play motion" button that works **even when the overlay is hidden** — just sends the command to the native bridge (which may queue it for when overlay becomes visible).
- Show a clear message: *"오버레이가 비활성 상태입니다. 모션이 오버레이 활성화 시 재생됩니다."*

**Priority:** Medium — good UX improvement.

**UI Location:** Test tab.

---

## New Architecture Design

### Screen Structure

```
_AdvancedSettingsMenu (in live2d_settings_screen.dart)
├─ '모션' → MotionSettingsScreen (NEW)
│   ├─ Tab 1: 제스처 & 매핑 (GesturesMappingTab)
│   │   ├─ Gesture Enable Toggles (tap, doubleTap, longPress, swipe, headPat, ...)
│   │   ├─ Per-Gesture Mapping Tiles → bottom sheet to assign action
│   │   │   └─ Action types: none, motion, expression, randomExpression, randomMotion, composite
│   │   ├─ Validation warnings for stale mappings
│   │   └─ "Reset to Model Defaults" button
│   │
│   ├─ Tab 2: 자동 동작 (AutoBehaviorTab)
│   │   ├─ 눈 깜빡임 (Eye Blink) — toggle + interval slider (ONLY IF native supports)
│   │   ├─ 호흡 (Breathing) — toggle
│   │   ├─ 시선 추적 (Look At) — toggle
│   │   └─ 아이들 모션 (Idle Motion Loop) — NEW
│   │       ├─ Enable toggle
│   │       ├─ Motion group selector (dropdown from model's available groups)
│   │       ├─ Interval range (min/max sliders)
│   │       └─ Randomize toggle
│   │
│   └─ Tab 3: 테스트 (InteractionTestTab)
│       ├─ Overlay status indicator
│       ├─ Direct trigger buttons (per motion group, per expression)
│       ├─ Event stream listener with live log
│       └─ Test mode toggle (visual gesture feedback)
│
├─ '디스플레이 설정' → DisplaySettingsScreen (KEEP)
└─ 'Lua/Regex 파이프라인' → prototype (KEEP)
```

### Data Model (Post-Refactor)

```
InteractionConfig (KEEP, enhanced)
├─ mappings: List<InteractionMapping>   (gesture → action mapping)
├─ enableTouchReaction: bool
├─ enableSwipeDetection: bool
├─ enableHeadPatDetection: bool
├─ enableAreaTouch: bool                (for F3 future)
├─ enableTouchFeedback: bool
├─ autoReactionEnabled: bool
├─ globalCooldownMs: int
└─ enableExternalSignals: bool

AutoBehaviorSettings (MOVE to own file, enhanced)
├─ eyeBlinkEnabled: bool
├─ breathingEnabled: bool
├─ lookAtEnabled: bool
├─ autoMotionEnabled: bool              (NEW - F1)
├─ idleMotionGroup: String?             (NEW - F1)
├─ idleIntervalMinSec: double           (NEW - F1)
├─ idleIntervalMaxSec: double           (NEW - F1)
├─ randomizeIdleMotion: bool            (NEW - F1)

DEPRECATED (to delete):
├─ GestureConfig → merged into InteractionConfig
├─ GestureActionMapping → replaced by InteractionMapping
├─ AutoBehaviorSettings.eyeBlinkInterval / breathingSpeed / lookAtSensitivity → remove if no native API
```

### Service Layer (Post-Refactor)

```
InteractionConfigService (simplify)
├─ loadConfig() / saveConfig()                  → InteractionConfig (key: 'interaction_config')
├─ loadAutoBehaviorSettings() / save...()       → AutoBehaviorSettings (key: 'auto_behavior_settings')
├─ REMOVE: loadGestureConfig() / saveGestureConfig()
├─ migrateGestureConfigToInteractionConfig()    → one-time migration
└─ (keep overlay/render settings as-is)

InteractionManager (slight changes)
├─ Apply AutoBehaviorSettings on initialize()
├─ Idle motion timer (F1) management
└─ (existing interaction processing stays the same)
```

---

## Implementation Steps

### Phase 1: Cleanup & Removal (Prerequisites)

#### Step 1.1 — Remove broken sections from `live2d_settings_screen.dart`

**File:** `lib/features/live2d/presentation/screens/live2d_settings_screen.dart`

**Actions:**
1. Delete the `_SectionHeader(title: '🎮 상호작용 테스트')` and `_InteractionTestTile` widget usage (lines 272–275).
2. Delete the `_InteractionTestTile` class and `_InteractionTestTileState` class (lines 418–625).
3. In `_AdvancedSettingsMenu`, delete the `상호작용 설정`, `제스처 설정`, `자동 동작 설정` list tiles (lines 635–676).
4. Add a new `모션` list tile pointing to `MotionSettingsScreen`.
5. Remove now-unused imports: `interaction_settings_screen.dart`, `gesture_settings_screen.dart`, `auto_behavior_settings_screen.dart`, `interaction_manager.dart`, `interaction_event.dart`.

#### Step 1.2 — Extract `AutoBehaviorSettings` model

**From:** `lib/features/live2d/presentation/screens/auto_behavior_settings_screen.dart` (lines 9–63)  
**To:** `lib/features/live2d/data/models/auto_behavior_settings.dart` (NEW)

- Move the class and add new fields for idle motion (F1).
- Remove `eyeBlinkInterval`, `breathingSpeed`, `lookAtSensitivity` if native APIs don't support them.
- Update all imports.

#### Step 1.3 — Data Migration: `GestureConfig` → `InteractionConfig`

**File:** `lib/features/live2d/data/services/interaction_config_service.dart`

**Actions:**
1. Add `migrateGestureConfigToInteractionConfig()` method:
   - Read `'gesture_config'` from SharedPreferences.
   - Convert each `GestureActionMapping` → `InteractionMapping` with equivalent `InteractionResponse`.
   - Merge enable flags (`enableTapReaction` → `enableTouchReaction`, etc.).
   - Write to `'interaction_config'`.
   - Delete `'gesture_config'` key.
2. Call migration in `loadConfig()` if `'gesture_config'` key exists and `'interaction_config'` is empty/default.
3. After migration is shipped, remove `loadGestureConfig()` / `saveGestureConfig()`.

---

### Phase 2: Build New `MotionSettingsScreen`

#### Step 2.1 — Create screen file

**File:** `lib/features/live2d/presentation/screens/motion_settings_screen.dart` (NEW)

**Structure:**
```dart
class MotionSettingsScreen extends StatelessWidget {
  // TabController with 3 tabs: Gestures, Auto, Test
}

class _GesturesMappingTab extends StatefulWidget {
  // Reads/writes InteractionConfig
  // Shows enable toggles + mapping list
  // Mapping bottom sheet uses InteractionMapping / InteractionResponse
}

class _AutoBehaviorTab extends StatefulWidget {
  // Reads/writes AutoBehaviorSettings
  // Eye blink, breathing, look-at toggles
  // NEW: Idle motion section
}

class _InteractionTestTab extends StatefulWidget {
  // Uses existing InteractionManager singleton
  // Direct trigger buttons + event log
}
```

#### Step 2.2 — Implement `_GesturesMappingTab`

**Key behaviors:**
1. On load: `InteractionConfigService().loadConfig()` + `Live2DNativeBridge().getMotionGroups()` + `getExpressions()`.
2. Display gesture enable toggles (tap, doubleTap, longPress, swipe, headPat).
3. Display mapping tiles for each `InteractionType`:
   - Show current mapping description.
   - Validate against loaded model data. Show ⚠️ if stale.
   - On tap → open bottom sheet (reuse/refactor `_InteractionMappingSheet` from `interaction_settings_screen.dart`).
4. Mapping bottom sheet:
   - Radio: none, motion, expression, randomExpression, randomMotion, composite (F2 - optional in first pass).
   - If motion: dropdown for group + spinner for index.
   - If expression: chip selector.
   - Save → update `InteractionConfig.mappings`.
5. Save button → `InteractionConfigService().saveConfig(config)`.
6. "Reset to Model Defaults" → generate new mappings from loaded model groups.

#### Step 2.3 — Implement `_AutoBehaviorTab`

**Key behaviors:**
1. On load: `InteractionConfigService().loadAutoBehaviorSettings()`.
2. Display toggles for eyeBlink, breathing, lookAt.
3. NEW: Idle motion section:
   - Toggle `autoMotionEnabled`.
   - Dropdown `idleMotionGroup` (populated from model's motion groups).
   - Range slider `idleIntervalMin` ~ `idleIntervalMax` (3s–120s).
   - Toggle `randomizeIdleMotion`.
4. On save: persist settings + apply to native bridge.

#### Step 2.4 — Implement `_InteractionTestTab`

**Key behaviors:**
1. Show overlay status (connected/not, model loaded/not) via `Live2DNativeBridge().isOverlayVisible()`.
2. Motion test section:
   - Load `getMotionGroups()`, `getMotionCount()`, `getMotionNames()`.
   - ExpansionTile per group, play button per motion.
3. Expression test section:
   - Load `getExpressions()`.
   - Chip selector to set expression.
4. Event listener:
   - Use singleton `InteractionManager().eventStream`.
   - Display live event log with timestamp + type + position.
   - Clear button.
5. Empty state if overlay not active.

---

### Phase 3: Apply Settings on Startup

#### Step 3.1 — Auto-apply in `Live2DController` or overlay initialization

**Where:** `lib/features/live2d/presentation/controllers/live2d_controller.dart` (or `Live2DOverlayController`)

**Actions:**
1. After model is loaded and overlay is shown, read `AutoBehaviorSettings` and call:
   ```dart
   bridge.setEyeBlink(settings.eyeBlinkEnabled);
   bridge.setBreathing(settings.breathingEnabled);
   bridge.setLookAt(settings.lookAtEnabled);
   bridge.setAutoMotion(settings.autoMotionEnabled);
   ```
2. If idle motion is enabled, start the idle timer in `InteractionManager`.

#### Step 3.2 — Idle Motion Timer in `InteractionManager`

**File:** `lib/features/live2d/data/services/interaction_manager.dart`

**Actions:**
1. Add fields: `Timer? _idleTimer`, `AutoBehaviorSettings? _autoBehavior`.
2. On initialize: load `AutoBehaviorSettings`, start idle timer if enabled.
3. `_startIdleTimer()`: schedule a random delay between min~max, then play idle motion group.
4. `_resetIdleTimer()`: cancel and restart (called on any user interaction).
5. `_handleNativeEvent()`: after processing, call `_resetIdleTimer()`.

---

### Phase 4: Cleanup

#### Step 4.1 — Delete deprecated files

| File | Action |
|---|---|
| `interaction_settings_screen.dart` (1,264 lines) | ❌ **Delete** |
| `gesture_settings_screen.dart` (569 lines) | ❌ **Delete** |
| `auto_behavior_settings_screen.dart` (356 lines) | ❌ **Delete** (model extracted) |
| `gesture_config.dart` (188 lines) | ❌ **Delete** |

#### Step 4.2 — Clean up imports

Remove all references to deleted files from:
- `live2d_settings_screen.dart`
- `interaction_config_service.dart`
- `live2d_module.dart` (barrel file)

#### Step 4.3 — Remove `_InteractionTestTile` remaining code

Ensure all references to the old test tile are gone from `live2d_settings_screen.dart`.

---

## File Manifest

### Files to CREATE

| File | Description |
|---|---|
| `lib/features/live2d/presentation/screens/motion_settings_screen.dart` | New unified motion settings with 3 tabs |
| `lib/features/live2d/data/models/auto_behavior_settings.dart` | Extracted model class with idle motion fields |

### Files to MODIFY

| File | Changes |
|---|---|
| `lib/features/live2d/presentation/screens/live2d_settings_screen.dart` | Remove test section, remove 3 advanced menu entries, add "모션" entry |
| `lib/features/live2d/data/services/interaction_config_service.dart` | Add migration, remove gesture config methods |
| `lib/features/live2d/data/services/interaction_manager.dart` | Add idle motion timer, apply auto behavior on init |
| `lib/features/live2d/data/models/interaction_config.dart` | Absorb enable flags from GestureConfig, ensure full coverage of all InteractionTypes |
| `lib/features/live2d/live2d_module.dart` | Update barrel exports |
| `lib/features/live2d/presentation/controllers/live2d_controller.dart` | Apply auto behavior settings on model load |

### Files to DELETE

| File | Reason |
|---|---|
| `lib/features/live2d/presentation/screens/interaction_settings_screen.dart` | Replaced by MotionSettingsScreen |
| `lib/features/live2d/presentation/screens/gesture_settings_screen.dart` | Replaced by MotionSettingsScreen Tab 1 |
| `lib/features/live2d/presentation/screens/auto_behavior_settings_screen.dart` | Model extracted; screen replaced by MotionSettingsScreen Tab 2 |
| `lib/features/live2d/domain/entities/gesture_config.dart` | Deprecated; merged into InteractionConfig |

### Files to KEEP (no changes)

| File | Reason |
|---|---|
| `lib/features/live2d/domain/entities/interaction_event.dart` | Core event types — still valid |
| `lib/features/live2d/domain/entities/interaction_response.dart` | Response actions — still valid |
| `lib/features/live2d/data/models/interaction_mapping.dart` | Mapping model — still valid |
| `lib/features/live2d/data/services/live2d_native_bridge.dart` | Bridge API — still valid |
| `lib/features/live2d/presentation/screens/display_settings_screen.dart` | Unrelated — keep |
| `lib/features/live2d/presentation/screens/live2d_pipeline_prototype_screen.dart` | Unrelated — keep |

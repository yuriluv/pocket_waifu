# newchecklist2.md — Live2D Feature Enhancement & Consolidation

> **Purpose:** Detailed implementation plan & checklist for Live2D feature testing, LLM-driven motion control, and directive pipeline improvements.
>
> **Source:** `userprompt1.md` user requirements + codebase analysis.
>
> **Date:** 2026-03-02

---

## Table of Contents

1. [Baseline: Current Architecture & Code Audit](#baseline-current-architecture--code-audit)
2. [§1 Parameter Control — Fix & Make Functional](#1-parameter-control--fix--make-functional)
3. [§2 Live2D Function Test Screen — New 3-Tab Screen](#2-live2d-function-test-screen--new-3-tab-screen)
4. [§3 XML Command Specification — Extend & Formalize](#3-xml-command-specification--extend--formalize)
5. [§4 LLM Directive Pipeline — Fix & Enhance](#4-llm-directive-pipeline--fix--enhance)
6. [§5 Generalized Parameter Naming (Model-Agnostic Mapping)](#5-generalized-parameter-naming-model-agnostic-mapping)
7. [§6 Motion Generation via LLM (MCP-Style Chat)](#6-motion-generation-via-llm-mcp-style-chat)
8. [Implementation Order](#implementation-order)
9. [Key Files Reference](#key-files-reference)
10. [Risk & Notes](#risk--notes)

---

## Baseline: Current Architecture & Code Audit

> This section documents the **existing state** of the Live2D subsystem as discovered through codebase analysis. All subsequent tasks build on this foundation.

### B1. Native Bridge Layer (Android → Cubism SDK)

| Component | File | Status |
|-----------|------|--------|
| JNI Bridge | `Live2DNativeBridge.kt` | ✅ Loaded. `nativeGetParameterCount`, `nativeGetParameterIds`, `nativeGetParameterValue` exist but return **stub values** (`emptyArray()`, `0f`). No actual JNI implementation for `nativeSetParameterValue`. |
| Model Manager | `Live2DManager.kt` | ✅ Singleton, delegates to `CubismFrameworkManager`. |
| Model Entity | `Live2DModel.kt` | ✅ Handles load, motions, expressions, scale, position, rotation, opacity. `playMotion()`, `setExpression()`, `lookAt()` work. |
| Motion Manager | `CubismMotionManager.kt` | ✅ Preloads motions, plays by group/index/priority, supports looping, handles idle restart. |
| App Model | `LAppModel.kt` | ✅ Encapsulates MOC loading, texture binding, renderer init, update/draw loop. Eye blink + breathing timers present but use **commented-out** `setParameterValue` calls. |
| GL Renderer | `Live2DGLRenderer.kt` | ⚠️ `setParameterValue()` at line 594–597 is **commented out** — logs but does nothing. |
| GL Surface View | `Live2DGLSurfaceView.kt` | ✅ `setParameterValue()` at line 231 correctly routes via `queueEvent` to renderer — but the renderer's method is a no-op. |
| Overlay Service | `Live2DOverlayService.kt` | ✅ `ACTION_SET_PARAMETER` handler at line 350 routes to `setParameterValue()` at line 798 → `glSurfaceView?.setParameterValue()`. Pipeline connected but terminal no-op. |

### B2. Method Channel (Flutter ↔ Android)

| Method | Handler | Status |
|--------|---------|--------|
| `setParameter` | `Live2DMethodHandler.setParameter()` (line 475–496) | ✅ Sends Intent to `Live2DOverlayService` with `ACTION_SET_PARAMETER`. Works, but overlay's `setParameterValue` is a no-op. |
| `getParameter` | `Live2DMethodHandler.getParameter()` (line 498–511) | ⚠️ Calls `Live2DNativeBridge.nativeGetParameterValue()` which returns **stub `0f`**. |
| `getParameterIds` | `Live2DMethodHandler.getParameterIds()` (line 513–521) | ⚠️ Calls `Live2DNativeBridge.nativeGetParameterIds()` which returns **stub `emptyArray()`**. |

### B3. Flutter-Side Services

| Component | File | Status |
|-----------|------|--------|
| Native Bridge (Dart) | `live2d_native_bridge.dart` | ✅ `setParameter()`, `getParameter()`, `getParameterIds()` all call method channel correctly. |
| Directive Service | `live2d_directive_service.dart` | ✅ Parses `<live2d>` XML blocks and `[param:id=value]` inline directives. Executes `param`, `motion`, `expression`, `emotion` commands. Delay support via `delay` attribute. Parameter bounds-checking loads from `getModelInfo()`. |
| Command Queue | `live2d_command_queue.dart` | ✅ Serial task queue for directive execution. |
| Lua Scripting | `lua_scripting_service.dart` | ✅ Hook system: `onUserMessage`, `onAssistantMessage`, `onPromptBuild`, `onDisplayRender`. Pseudo-Lua fallback with native bridge for real Lua. |

### B4. UI Screens

| Screen | File | Status |
|--------|------|--------|
| Advanced Settings | `live2d_advanced_settings_screen.dart` | ✅ 4 tabs: Auto Motion, Gesture Mapping, Interaction Test, Motion & Params. |
| Interaction Test | Lines 772–960 in above | ⚠️ UI for parameter sliders, motion chips, expression chips exists. `_setParameter()` calls `_bridge.setParameter()` → method channel → no-op. **Visually works, no actual Live2D effect.** |
| Motion & Params | Lines 964–1447 in above | ⚠️ Same issue — sliders update state but `setParameter` doesn't reach the model. Presets save/load/export/import work (file storage works). |
| Pipeline Prototype | `live2d_pipeline_prototype_screen.dart` | ⚠️ Pure UI prototype — no functional wiring. Lua/Regex/Directive tabs are static mockups. |

### B5. Critical Finding: **Parameter Control Is Entirely Non-Functional**

The complete parameter control pipeline is:

```
Flutter slider → setParameter() → MethodChannel → Live2DMethodHandler.setParameter()
→ Intent → Live2DOverlayService.setParameterValue(paramId, value, durationMs)
→ glSurfaceView.setParameterValue(paramId, value, durationMs)
→ Live2DGLRenderer.setParameterValue(paramId, value, durationMs)
→ // live2DModel?.setParameterValue(paramId, value, durationMs)  ← COMMENTED OUT
```

**Additionally:**
- `Live2DNativeBridge.nativeGetParameterIds()` returns `emptyArray()` — no actual JNI implementation.
- `Live2DNativeBridge.nativeGetParameterValue()` returns `0f` — no actual JNI implementation.
- The Interaction Test tab's parameter list comes from `Model3Data.parameters` (parsed from `model3.json` file), NOT from the native SDK — so the UI shows correct parameter names, but can't read live values.

---

## §1 Parameter Control — Fix & Make Functional

> **Goal:** Make parameter slider adjustments actually affect the Live2D model in real-time.
>
> **Scope:** This requires changes at the Android native layer. The Dart side and method channel are already wired correctly — only the Android terminal endpoints need fixing.

### 1.1 Implement `setParameterValue` in Renderer

- [x] **1.1.1** In `Live2DGLRenderer.kt` (line 594–597), uncomment and implement `setParameterValue`:
  ```kotlin
  fun setParameterValue(paramId: String, value: Float, durationMs: Int) {
      // Option A: Immediate set (if durationMs == 0)
      pendingParameterUpdates.add(ParameterUpdate(paramId, value, durationMs))
  }
  ```
  - The renderer runs on the GL thread. Parameter updates should be queued and applied during the `onDrawFrame()` call.

- [x] **1.1.2** Create a `ParameterUpdate` data class:
  ```kotlin
  data class ParameterUpdate(
      val paramId: String,
      val targetValue: Float,
      val durationMs: Int,
      var startValue: Float? = null,
      var elapsedMs: Float = 0f
  )
  ```

- [x] **1.1.3** In the `onDrawFrame()` update loop, before `nativeDraw()`:
  - Process pending `ParameterUpdate` entries.
  - For each entry:
    - If `durationMs == 0`: set value immediately via the native model.
    - If `durationMs > 0`: interpolate from `startValue` to `targetValue` over the duration (lerp). Remove when complete.
  - Apply values via `CubismCore` API: `Live2DNativeBridge.nativeSetParameterValue(paramId, computedValue)`.

- [x] **1.1.4** **Add `nativeSetParameterValue` JNI function:**
  - In `Live2DNativeBridge.kt`, add:
    ```kotlin
    external fun nativeSetParameterValue(paramId: String, value: Float)
    ```
  - In the JNI C++ side (`live2d_jni.cpp`), implement using Cubism SDK:
    ```cpp
    // Find parameter index by ID, then set value
    auto model = modelPtr->GetModel();
    auto count = model->GetParameterCount();
    auto ids = model->GetParameterIds();
    for (int i = 0; i < count; i++) {
        if (strcmp(ids[i], paramId) == 0) {
            model->SetParameterValue(i, value);
            break;
        }
    }
    ```

- [x] **1.1.5** **Implement `nativeGetParameterIds` properly** (currently returns `emptyArray()`):
  - In JNI C++, read `model->GetParameterIds()` and `model->GetParameterCount()`, return as `Array<String>`.

- [x] **1.1.6** **Implement `nativeGetParameterValue` properly** (currently returns `0f`):
  - In JNI C++, find parameter by ID, return `model->GetParameterValue(index)`.

### 1.2 Smooth Transition Support

- [x] **1.2.1** Implement lerp-based parameter animation in the renderer:
  - When `durationMs > 0`, the parameter value should transition smoothly from current to target over the specified duration.
  - Use `deltaTime` from `onDrawFrame()` to advance the interpolation.
  - Support multiple simultaneous parameter animations (e.g., moving both eyes and mouth).

- [x] **1.2.2** Ensure new parameter updates to the same `paramId` replace (not stack with) any in-progress animation for that parameter.

### 1.3 Re-enable Eye Blink and Breathing via Parameters

- [x] **1.3.1** In `LAppModel.kt`, uncomment the `setParameterValue` calls in `updateEyeBlinkTimer()` (line 378–396) and `updateBreathTimer()` (line 398–402).
  - These use hardcoded parameter IDs (`ParamEyeLOpen`, `ParamEyeROpen`, `ParamBreath`) which may not exist on all models.
  - Add a check: only apply if the parameter ID exists in the model.

- [ ] **1.3.2** Test on the current model (`Sherry`) to verify eye blink and breathing work after enabling.

### 1.4 Verification

- [ ] **1.4.1** Open Advanced Settings → Interaction Test tab.
- [ ] **1.4.2** Drag a parameter slider → verify the Live2D model visually changes in real-time.
- [ ] **1.4.3** Click "Reset All Parameters" → verify the model returns to default pose.
- [ ] **1.4.4** Play a motion → verify the motion overrides parameters temporarily, then parameters return to slider values.

---

## §2 Live2D Function Test Screen — New 3-Tab Screen

> **Goal:** Add a new screen accessible from Live2D Advanced Settings with 3 tabs:
> 1. **Parameter Adjustment** — Real-time parameter sliders (uses raw parameter IDs)
> 2. **Command Input** — Chat-like UI to manually type XML directives and see them execute
> 3. **Motion Generation** — LLM-powered motion preset creation
>
> **Location:** New button "Live2D Function Test" at the top of the existing advanced settings, opening a new screen. This is separate from the existing 4-tab advanced settings.

### 2.1 Entry Point

- [x] **2.1.1** In `live2d_advanced_settings_screen.dart`, add a button above the TabBar body (or in the AppBar actions):
  ```dart
  IconButton(
    icon: const Icon(Icons.science),
    tooltip: 'Live2D Function Test',
    onPressed: () => Navigator.push(context, MaterialPageRoute(
      builder: (_) => Live2DFunctionTestScreen(modelPath: widget.model3Path),
    )),
  )
  ```

- [x] **2.1.2** Create `lib/features/live2d/presentation/screens/live2d_function_test_screen.dart`.

### 2.2 Tab 1: Parameter Adjustment (Real-Time)

> **Requirement:** Show ALL adjustable parameters with their raw English parameter IDs. Sliders must affect the live model immediately. Reset button at top.

- [x] **2.2.1** Load parameters from `Model3Data.parameters` (parsed from `model3.json`).
  - Display each parameter with its **raw `id`** as the label (e.g., `ParamAngleX`, `ParamBodyAngleZ`).
  - Do **not** use a translated or friendly name — use the exact parameter variable name.

- [x] **2.2.2** For each parameter, render a `Slider` with:
  - `min`: `parameter.min`
  - `max`: `parameter.max`
  - `value`: current value (fetched from native if possible, otherwise `parameter.defaultValue`)
  - `onChanged`: call `Live2DNativeBridge.setParameter(id, value, durationMs: 0)` for instant feedback.

- [x] **2.2.3** **Reset All button** at the top:
  ```dart
  ElevatedButton.icon(
    icon: const Icon(Icons.refresh),
    label: const Text('Reset All'),
    onPressed: () async {
      for (final param in parameters) {
        await bridge.setParameter(param.id, param.defaultValue, durationMs: 200);
      }
      setState(() { /* reset local values */ });
    },
  )
  ```

- [x] **2.2.4** **Search/filter** (optional): Add a search field to filter parameters by ID substring, since some models have 50+ parameters.

- [x] **2.2.5** **Current value display:** Show the current numerical value next to each slider (e.g., `0.57`).

- [x] **2.2.6** **Depends on:** §1 (parameter control must actually work for this tab to be useful).

### 2.3 Tab 2: Command Input (XML Directive Tester)

> **Requirement:** Chat-like UI where the user types XML commands manually and sees them executed on the Live2D model in real-time.

- [x] **2.3.1** Build a simple chat-like UI:
  - Top area: scrollable list of past commands and their results (like a terminal log).
  - Bottom: text input field + send button.

- [x] **2.3.2** Each submitted command is parsed and executed via `Live2DDirectiveService.processAssistantOutput()`:
  ```dart
  final result = await Live2DDirectiveService.instance.processAssistantOutput(
    userInput,
    parsingEnabled: true,
    exposeRawDirectives: true,  // Show what was parsed
  );
  ```

- [x] **2.3.3** Display result in the log:
  - **Input:** The raw XML the user typed.
  - **Parsed:** The chip-formatted representation (e.g., `⟦param:ParamAngleX=0.5⟧`).
  - **Errors:** Any errors from execution.
  - **Status:** ✅ or ❌ for each command.

- [x] **2.3.4** **Command examples panel:** Add a collapsible section with example commands:
  ```xml
  <!-- Single parameter -->
  <live2d>
    <param id="ParamAngleX" value="30" dur="500"/>
  </live2d>

  <!-- Motion -->
  <live2d>
    <motion group="Idle" index="0"/>
  </live2d>

  <!-- Expression -->
  <live2d>
    <expression name="happy"/>
  </live2d>

  <!-- Emotion preset -->
  <live2d>
    <emotion name="surprised"/>
  </live2d>

  <!-- Sequence with delays -->
  <live2d>
    <param id="ParamAngleX" value="30" dur="300"/>
    <param id="ParamAngleX" value="-30" dur="300" delay="500"/>
    <param id="ParamAngleX" value="0" dur="300" delay="500"/>
  </live2d>

  <!-- Inline format -->
  [param:ParamAngleX=30]
  [motion:Idle/0]
  [emotion:happy]
  ```

- [x] **2.3.5** **Real-time feedback:** After each command execution, update the parameter slider values in Tab 1 (if the user switches back) to reflect the changed state.

- [x] **2.3.6** **Clear log** button to reset the command history.

### 2.4 Tab 3: Motion Generation (LLM-Powered)

> **Requirement:** A chat interface where the user can talk to an LLM that generates motion presets as JSON, using a selected API preset. The LLM has "MCP-like" tool-calling capability to read/write JSON motion files.
>
> This is the most complex tab and is detailed in [§6](#6-motion-generation-via-llm-mcp-style-chat).

- [x] **2.4.1** Placeholder entry point — defer implementation to §6.

---

## §3 XML Command Specification — Extend & Formalize

> **Goal:** Define and implement all required XML commands for LLM-driven Live2D control. The user's requirements specify several missing command types.

### 3.1 Current Command Set (Already Implemented)

| Command | XML Syntax | Inline Syntax | Status |
|---------|-----------|---------------|--------|
| Set Parameter | `<param id="X" value="V" dur="D"/>` | `[param:X=V]` | ✅ Parsed, but execution is a no-op (§1 fixes this) |
| Play Motion | `<motion group="G" index="I" priority="P"/>` | `[motion:G/I]` | ✅ Works |
| Set Expression | `<expression name="N"/>` or `id="N"` | `[expression:N]` | ✅ Works |
| Emotion Preset | `<emotion name="N"/>` | `[emotion:N]` | ✅ Works (happy, sad, angry, surprised, neutral) |
| Delay | `delay="D"` attribute on any command | — | ✅ Works per-command |

### 3.2 Missing Commands (To Implement)

| Command | Purpose | Required By User |
|---------|---------|----------------|
| **Wait** | Pause execution for N milliseconds between commands | ✅ "n초를 기다리는 명령어" |
| **Smooth Param** | Transition a parameter from current to target value over duration | ✅ "파라미터 값을 어떤 값으로 천천히 바꾸는 명령어" (partially exists via `dur` attribute) |
| **Play Named Motion** | Play a custom user-saved motion preset by name | ✅ "기존에 구현된 모션을 실행하는 명령어" |
| **Reset** | Reset all parameters to defaults | — |

#### 3.2.1 Wait Command

- [x] **3.2.1.1** Add `<wait ms="N"/>` command:
  ```xml
  <live2d>
    <param id="ParamAngleX" value="30" dur="300"/>
    <wait ms="500"/>
    <param id="ParamAngleX" value="-30" dur="300"/>
  </live2d>
  ```
  
- [x] **3.2.1.2** Implementation in `Live2DDirectiveService._executeSingleDirective()`:
  ```dart
  case 'wait':
    final ms = int.tryParse(attrs['ms'] ?? attrs['duration'] ?? '') ?? 0;
    if (ms > 0) {
      await Future<void>.delayed(Duration(milliseconds: ms));
    }
    break;
  ```

- [x] **3.2.1.3** Add inline syntax: `[wait:500]` (wait 500ms).

#### 3.2.2 Smooth Param Transition (Enhancement)

> The existing `dur` attribute on `<param>` already supports transitions, but depends on §1.1 renderer lerp implementation. Once §1 is complete, this effectively works.

- [x] **3.2.2.1** Verify that `dur` attribute on `<param>` works for smooth transitions after §1 fix.
- [ ] **3.2.2.2** Document: `<param id="ParamAngleX" value="30" dur="1000"/>` means "transition ParamAngleX to 30 over 1000ms".
- [ ] **3.2.2.3** Add `easing` attribute (optional, future): `<param id="X" value="V" dur="D" easing="easeInOut"/>`.

#### 3.2.3 Named Motion Preset Command

- [x] **3.2.3.1** Add `<preset name="N"/>` command:
  ```xml
  <live2d>
    <preset name="MyCustomWave"/>
  </live2d>
  ```

- [x] **3.2.3.2** Implementation: Look up `name` in `Live2DSettingsRepository.loadParameterPresets()`:
  ```dart
  case 'preset':
    final name = attrs['name'];
    if (name == null) break;
    // Load presets, find by name, apply overrides
    final presets = await _repo.loadParameterPresets(currentModelPath);
    final preset = presets.firstWhere((p) => p.name == name, orElse: () => null);
    if (preset != null) {
      for (final entry in preset.overrides.entries) {
        await _bridge.setParameter(entry.key, entry.value, durationMs: dur);
      }
    }
    break;
  ```
  This requires passing `modelPath` to the directive service.

- [x] **3.2.3.3** Add inline syntax: `[preset:MyCustomWave]`.

#### 3.2.4 Reset Command

- [x] **3.2.4.1** Add `<reset/>` command:
  ```xml
  <live2d>
    <reset/>
  </live2d>
  ```

- [x] **3.2.4.2** Implementation: Load parameters from `Model3Data`, set all to defaults:
  ```dart
  case 'reset':
    final dur = int.tryParse(attrs['dur'] ?? '') ?? 200;
    await _ensureParameterBoundsLoaded();
    for (final id in _parameterBounds.keys) {
      // Need default values — may need to store them during bounds loading
    }
    break;
  ```
  This requires extending `_ParameterRange` to include `defaultValue`.

### 3.3 Update Regex Patterns

- [x] **3.3.1** Update `_executeDirectiveBlock` regex to include `wait`, `preset`, `reset`:
  ```dart
  final commandRegex = RegExp(
    r'<(param|motion|expression|emotion|wait|preset|reset)\s+([^/>]*)/?>',
  );
  ```

- [x] **3.3.2** Update `_inlineDirectiveRegex` to include new commands:
  ```dart
  static final RegExp _inlineDirectiveRegex = RegExp(
    r'\[(param|motion|expression|emotion|wait|preset|reset):([^\]]+)\]',
    caseSensitive: false,
  );
  ```

- [x] **3.3.3** Update `_formatChipTag` for new command display formatting.

---

## §4 LLM Directive Pipeline — Fix & Enhance

> **Goal:** Ensure the full pipeline from API response → directive execution → cleaned text → chat display → notification works correctly.
>
> **Current Pipeline Analysis:**
> ```
> API call → raw response → _prepareAssistantOutput():
>   1. Regex rules (AI_OUTPUT) → strip/transform
>   2. Lua hooks (onAssistantMessage) → transform
>   (order configurable via settings.runRegexBeforeLua)
>   3. Live2DDirectiveService.processAssistantOutput():
>      a. Parse <live2d> blocks and [inline] directives
>      b. Execute commands (param, motion, expression, emotion)
>      c. Strip directives from text → cleanedText
>   4. Regex rules (DISPLAY_ONLY) → final display transform
>   5. Lua hooks (onDisplayRender) → final display transform
> ```

### 4.1 Verify End-to-End Pipeline

- [x] **4.1.1** The pipeline in `NotificationCoordinator._prepareAssistantOutput()` (line 424–500) calls `_directiveService.processAssistantOutput()` at line 463. This returns `cleanedText` (directives stripped).
  - **Verify:** The `cleanedText` is what gets stored in the chat session via the message.
  - **Verify:** The directive execution happens before the cleaned text is displayed.

- [x] **4.1.2** Same pipeline exists in `ChatProvider` (line 263 calls `_directiveService.processAssistantOutput()`).
  - **Verify:** Both paths (main chat and notification reply) go through the same directive processing.

- [x] **4.1.3** **Streaming support:** `ChatProvider` likely uses `pushStreamChunk()` for streaming responses.
  - **Verify:** `pushStreamChunk()` correctly handles partial `<live2d>` blocks (doesn't execute until block is closed).
  - **Verify:** The stream buffer correctly accumulates partial inline directives.

### 4.2 Directive Execution Order

- [x] **4.2.1** Confirm that directive commands execute **sequentially** via `Live2DCommandQueue`:
  ```
  <live2d>
    <param id="A" value="1" dur="300"/>
    <wait ms="300"/>
    <param id="A" value="0" dur="300"/>
  </live2d>
  ```
  This should: set A→1 over 300ms, wait 300ms, set A→0 over 300ms (total: ~900ms).

- [x] **4.2.2** **Currently:** The `delay` attribute on each command works independently. The new `<wait>` command adds explicit pauses between commands. Verify these don't conflict.

### 4.3 Notification Path — Directive Processing

- [x] **4.3.1** For notification replies processed via `NotificationCoordinator._handleNotificationReplyInternal()`:
  - The LLM response is processed via `_prepareAssistantOutput()`.
  - Directives are executed during processing.
  - The `cleanedText` is sent to the notification via `_bridge.showPreResponseNotification()`.
  - **Verify:** The notification shows the cleaned text (no XML tags visible).

- [x] **4.3.2** For proactive responses via `NotificationCoordinator._handleProactiveResponse()`:
  - The LLM response is also processed via `_prepareAssistantOutput()`.
  - **Verify:** Proactive responses also trigger directive execution (model reacts while the notification shows text).

### 4.4 Error Handling in Directives

- [x] **4.4.1** If a directive command fails (e.g., unknown parameter ID), the error is logged but execution continues to the next command. **Verify** this behavior.

- [x] **4.4.2** If the `<live2d>` block is malformed, `processAssistantOutput()` should strip it anyway and return the cleaned text. **Verify** this doesn't crash.

---

## §5 Generalized Parameter Naming (Model-Agnostic Mapping)

> **Goal:** Since different Live2D models have different parameter IDs (e.g., one model uses `ParamAngleX`, another uses `Param_Angle_X`, another uses `param_head_yaw`), the LLM cannot hardcode specific parameter names. Instead, use a generalized mapping system.
>
> **User Requirement:** "파라미터 조절 명령어를 위해, 고유한 파라미터 명을 미리 지정하지 않고, parameterN과 같이 일반화 하여 저장해둔다"

### 5.1 Design: Parameter Alias System

- [x] **5.1.1** Create a generalized parameter alias model:
  ```dart
  // lib/features/live2d/data/models/parameter_alias_map.dart
  class ParameterAliasMap {
    final Map<String, String> aliasToReal;  // e.g. "parameter1" → "ParamAngleX"
    final Map<String, String> realToAlias;  // reverse lookup
  }
  ```

- [x] **5.1.2** When a model is loaded, auto-generate aliases:
  - Sort the model's parameters by ID alphabetically.
  - Assign `parameter1`, `parameter2`, ..., `parameterN`.
  - Store the mapping persistently per model (in `Live2DSettingsRepository`).

- [x] **5.1.3** Allow user to customize aliases via a simple table editor:
  - Show: `parameter1 → ParamAngleX (Angle X)`, with an editable alias field.
  - Users can rename `parameter1` to `headAngleX` for clarity.

### 5.2 LLM System Prompt Integration

- [x] **5.2.1** When the LLM is generating directives, inject the alias mapping into the system prompt:
  ```
  Available Live2D parameters (use alias names in commands):
  - parameter1: ParamAngleX (range: -30.0 to 30.0, default: 0.0) — Head angle X axis
  - parameter2: ParamAngleY (range: -30.0 to 30.0, default: 0.0) — Head angle Y axis
  ...
  ```

- [x] **5.2.2** The directive service should resolve aliases before execution:
  ```dart
  // In _runParam():
  var resolvedId = id;
  if (_aliasMap != null && _aliasMap!.aliasToReal.containsKey(id)) {
    resolvedId = _aliasMap!.aliasToReal[id]!;
  }
  ```

### 5.3 Alias Persistence

- [x] **5.3.1** Store aliases per model in `Live2DSettingsRepository`:
  ```dart
  Future<ParameterAliasMap?> loadParameterAliases(String modelPath);
  Future<void> saveParameterAliases(String modelPath, ParameterAliasMap map);
  ```

- [x] **5.3.2** Auto-regenerate aliases when a different model is loaded (but preserve user customizations if the model path matches a saved mapping).

---

## §6 Motion Generation via LLM (MCP-Style Chat)

> **Goal:** The "Motion Generation" tab (Tab 3 of §2) provides a chat interface where the user converses with an LLM. The LLM can create, modify, and save motion presets as JSON files. The LLM has tool-calling capabilities (MCP-style) to read/write model data.
>
> **User Requirement:** "상단에 api 프리셋을 선택할 수 있게 하고, 그 밑에 프롬프트 입력창을 두어, 해당 공간에서 해당 api로 채팅을 할 수 있게 한다. 이때, 이 api에 권한을 부여하여, json 파일을 수정, 추가할 수 있도록 두어라."

### 6.1 UI Layout

- [x] **6.1.1** Top section: API preset selector dropdown.
  - Use existing `ApiPreset` model and `ApiPresetProvider`.
  - Populate with user's saved API presets.
  - On change, switch the LLM backend for this tab's chat.

- [x] **6.1.2** Main section: Chat messages list (scrollable).
  - Display user messages and LLM responses.
  - LLM responses may contain tool calls and tool results (shown as collapsible cards).

- [x] **6.1.3** Bottom section: Text input + send button.
  - Separate chat session from the main app chat.
  - This chat's context is isolated (its own message history, its own system prompt).

### 6.2 System Prompt for Motion Generation

- [x] **6.2.1** A built-in system prompt (English) that instructs the LLM:
  ```
  You are a Live2D motion preset designer. You have access to the following tools:

  1. read_model_info(): Returns the current model's parameters, motions, and expressions.
  2. read_param_values(): Returns current parameter values.
  3. set_parameter(id, value, durationMs): Set a parameter value with optional transition.
  4. create_preset(name, overrides): Save a parameter preset as JSON.
  5. list_presets(): List all saved motion presets.
  6. delete_preset(id): Delete a preset.
  7. play_motion(group, index): Play a built-in motion.
  8. test_sequence(commands): Execute a sequence of XML commands to preview.

  When creating motion presets, output them as JSON with the following format:
  {
    "name": "preset_name",
    "overrides": { "ParamAngleX": 15.0, "ParamEyeLSmile": 0.8, ... }
  }

  Always test your presets by executing them before saving.
  ```

- [x] **6.2.2** The system prompt should dynamically include the current model's parameter list (from `Model3Data.parameters`) so the LLM knows what parameters are available.

### 6.3 Tool/Function Calling Implementation (MCP-Style)

- [x] **6.3.1** When the LLM response contains a tool call (detected by API-specific format — OpenAI function_call, Claude tool_use, etc.):
  - Parse the tool call.
  - Execute the corresponding local function.
  - Send the tool result back as a follow-up message.
  - Display the tool call and result in the chat as a collapsible card.

- [x] **6.3.2** Implement each tool locally:

  | Tool | Implementation |
  |------|---------------|
  | `read_model_info` | `Live2DNativeBridge.getModelInfo()` → return model params, motions, expressions |
  | `read_param_values` | For each param in `Model3Data.parameters`, call `getParameter(id)` → return map |
  | `set_parameter` | `Live2DNativeBridge.setParameter(id, value, durationMs: dur)` |
  | `create_preset` | Create `Live2DParameterPreset`, save via `Live2DSettingsRepository.saveParameterPresets()` |
  | `list_presets` | `Live2DSettingsRepository.loadParameterPresets(modelPath)` |
  | `delete_preset` | Filter and re-save presets list |
  | `play_motion` | `Live2DNativeBridge.playMotion(group, index)` |
  | `test_sequence` | `Live2DDirectiveService.processAssistantOutput(xmlCommands)` |

- [ ] **6.3.3** Tool definitions should be sent to the LLM as part of the API request (using the API's native function/tool format):
  - For OpenAI: `tools` array in the request body.
  - For Claude: `tools` array with input schemas.
  - Adapt based on the selected API preset's provider type.

### 6.4 File Write Permissions

- [x] **6.4.1** The LLM can create/modify JSON preset files:
  - Presets are saved via `Live2DSettingsRepository` (internally uses app's data directory).
  - No external file system access — only through the repository API.
  - This is inherently safe since it writes to the app's private storage.

- [x] **6.4.2** **Guard:** Add a confirmation dialog before the preset is saved:
  ```dart
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      title: Text('Save Motion Preset?'),
      content: Text('The LLM wants to save preset: "${preset.name}" with ${preset.overrides.length} parameter overrides.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: Text('Save')),
      ],
    ),
  );
  ```

### 6.5 Isolated Chat Session

- [x] **6.5.1** Create a `MotionGenChatSession` model for this tab's conversation:
  ```dart
  class MotionGenChatSession {
    List<MotionGenMessage> messages = [];
    String? selectedApiPresetId;
  }
  ```

- [x] **6.5.2** This session persists while the screen is open but does NOT save to `ChatSessionProvider` (completely isolated).

- [x] **6.5.3** Use the selected API preset's `apiKey`, `model`, `endpoint` for API calls.

- [x] **6.5.4** The system prompt includes the motion generation instructions + current model info.

---

## Implementation Order

| Phase | Tasks | Dependencies | Complexity |
|-------|-------|-------------|------------|
| **Phase 1** | §1 (Fix parameter control — JNI, renderer, lerp) | None | 🔴 High — JNI/C++ changes |
| **Phase 2** | §3.1–3.2 (New XML commands: wait, preset, reset) | None (execution depends on Phase 1 for param commands) | 🟡 Medium |
| **Phase 3** | §4 (Verify & fix directive pipeline) | Phase 1, 2 | 🟢 Low — mostly verification |
| **Phase 4** | §2.1–2.2 (New screen + Parameter tab) | Phase 1 | 🟡 Medium |
| **Phase 5** | §2.3 (Command Input tab) | Phase 2 | 🟡 Medium |
| **Phase 6** | §5 (Generalized parameter naming) | Phase 1 | 🟡 Medium |
| **Phase 7** | §6 + §2.4 (Motion Generation tab) | Phase 1, 2, 6 | 🔴 High — API integration + tool calling |

### Recommended Critical Path

```
Phase 1 (fix parameters) → Phase 4 (parameter UI) → Phase 2 (new commands)
→ Phase 5 (command input) → Phase 3 (verify pipeline)
→ Phase 6 (alias system) → Phase 7 (LLM motion gen)
```

---

## Key Files Reference

| File | Purpose | §§ |
|------|---------|-----|
| `android/.../cubism/Live2DNativeBridge.kt` | JNI bridge — stub `getParameterIds/Value`, missing `setParameterValue` | §1 |
| `android/.../renderer/Live2DGLRenderer.kt` | Renderer — `setParameterValue()` is commented out | §1 |
| `android/.../renderer/Live2DGLSurfaceView.kt` | GL surface — routes `setParameterValue()` to renderer | §1 |
| `android/.../overlay/Live2DOverlayService.kt` | Overlay — `ACTION_SET_PARAMETER` handler | §1 |
| `android/.../Live2DMethodHandler.kt` | Method channel — `setParameter`, `getParameter`, `getParameterIds` | §1 |
| `android/.../cubism/LAppModel.kt` | App model — commented-out eye blink/breathing parameter calls | §1 |
| `android/.../cubism/CubismMotionManager.kt` | Motion playback system | §3 |
| `lib/features/live2d/data/services/live2d_native_bridge.dart` | Dart-side method channel for Live2D | §1, §2 |
| `lib/features/live2d/data/models/model3_data.dart` | `Model3Data`, `Model3Parameter` models | §1, §2, §5 |
| `lib/features/live2d/data/models/live2d_parameter_preset.dart` | `Live2DParameterPreset` model | §3, §6 |
| `lib/features/live2d/data/repositories/live2d_settings_repository.dart` | Preset save/load/export/import | §3, §6 |
| `lib/features/live2d/presentation/screens/live2d_advanced_settings_screen.dart` | Existing 4-tab advanced settings (1464 lines) | §2 |
| `lib/features/live2d/presentation/screens/live2d_pipeline_prototype_screen.dart` | Static Lua/Regex/Directive UI mockup | §4 |
| `lib/features/live2d_llm/services/live2d_directive_service.dart` | XML directive parser + executor | §3, §4 |
| `lib/features/live2d_llm/services/live2d_command_queue.dart` | Serial command queue for directive execution | §3 |
| `lib/features/live2d_llm/models/live2d_emotion_preset.dart` | Emotion preset model (happy, sad, etc.) | §3 |
| `lib/features/lua/services/lua_scripting_service.dart` | Lua hook pipeline | §4 |
| `lib/services/notification_coordinator.dart` | `_prepareAssistantOutput()` — full processing pipeline | §4 |
| `lib/providers/chat_provider.dart` | Main chat `_prepareAssistantOutput()` — same pipeline | §4 |
| `lib/services/api_service.dart` | API calling with Lua `onPromptBuild` hook | §6 |

---

## Risk & Notes

## Code Review (2026-03-02)

- ✅ JNI/Renderer 경로의 파라미터 쓰기/읽기 스텁은 실제 구현으로 교체됨 (`Live2DNativeBridge.kt`, `Live2DNative.cpp`, `Live2DGLRenderer.kt`).
- ✅ Directive 확장(`wait`, `preset`, `reset`, inline, chip formatting)과 alias 해석 로직은 코드 레벨에서 확인됨 (`live2d_directive_service.dart`).
- ✅ Function Test 3탭 및 alias 편집 UI는 동작 경로가 연결됨 (`live2d_function_test_screen.dart`, `live2d_advanced_settings_screen.dart`).
- ⚠️ 미완료/보류: 실기기 수동 검증(§1.3.2, §1.4.*), `dur` 문서화(§3.2.2.2), provider-native `tools` 전송 포맷(§6.3.3).
- ⚠️ 문서 내 JNI 파일명은 `live2d_jni.cpp`로 적혀 있으나 실제 프로젝트 파일은 `android/app/src/main/cpp/Live2DNative.cpp`임.

1. **JNI implementation risk (§1):** The biggest risk is in the C++ JNI layer. `nativeSetParameterValue`, `nativeGetParameterIds`, and `nativeGetParameterValue` need to be implemented in `live2d_jni.cpp`. This requires knowledge of the Cubism Core SDK C API. If the JNI bridge wasn't written by the current developer, this may require studying the Cubism SDK documentation.

2. **Model-specific parameter IDs (§5):** Different models use completely different parameter IDs. The "Sherry" model may use `ParamAngleX` while another model uses `Angle_Head_X`. The alias system in §5 must be robust enough to handle re-mapping when models are switched.

3. **Thread safety of parameter updates (§1):** Parameter updates go from the main thread → Intent → Service → GL thread. The `queueEvent{}` call in `Live2DGLSurfaceView` ensures GL-thread safety, but multiple rapid slider updates could queue excessively. Consider debouncing or replacing (not appending) updates for the same parameter ID.

4. **LLM tool-calling compatibility (§6):** Different LLM providers have different tool-calling formats. OpenAI uses `function_call`/`tool_calls`, Claude uses `tool_use` blocks, and some providers don't support tool calling at all. The implementation must handle provider-specific formats or gracefully fall back to prompt-based JSON output.

5. **Motion Generation scope (§6):** The LLM generating motion presets is creative but unpredictable. Generated presets should always be previewed before saving. The confirmation dialog in §6.4.2 is critical.

6. **Directive pipeline double-processing (§4):** Both `ChatProvider` and `NotificationCoordinator` have their own `_prepareAssistantOutput()` methods. Changes to the pipeline must be applied in BOTH places. Consider refactoring to a shared utility.

7. **Eye blink/breathing interference (§1.3):** Eye blink and breathing use timer-based parameter updates. If a user or LLM sets the same parameters manually, there will be conflicts. Consider: blink/breathe only update if no manual override is active for those parameters.

8. **Performance of parameter animations (§1.2):** If many parameters are being animated simultaneously (10+ lerps), the frame budget on `onDrawFrame` may be impacted. Profile on target devices.

9. **Existing Interaction Test tab vs new Parameter tab:** The existing `_InteractionTestTab` (line 772) already has parameter sliders and motion/expression chips. The new "Parameter Adjustment" tab in §2.2 is intentionally separate — it uses raw parameter IDs only and is focused purely on parameter testing. Consider whether to merge them or keep them separate.

10. **Pipeline Prototype Screen:** The existing `live2d_pipeline_prototype_screen.dart` is a static mockup. It should be either upgraded to use real wiring (connecting to `LuaScriptingService`, `RegexPipelineService`, `Live2DDirectiveService`) or removed in favor of the new Function Test screen.

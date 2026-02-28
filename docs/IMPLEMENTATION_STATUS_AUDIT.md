# Implementation Status Audit — request2.md & Newcastle.md

> **Date:** 2026-02-28  
> **Purpose:** Provide a detailed, actionable gap analysis for an AI agent to understand what has been implemented, what is incomplete, and what is entirely missing — referencing the requirement documents `request2.md` (Part 1: Major Features) and `Newcastle.md` (Notification & Proactive Response).

---

## Table of Contents

1. [Overall Summary](#overall-summary)
2. [request2.md — Part 1: Major Feature Development](#request2md--part-1-major-feature-development)
   - [1.1 Live2D Feature Improvements](#11-live2d-feature-improvements)
   - [1.2 Lua Scripting Engine & Regex Pipeline](#12-lua-scripting-engine--regex-pipeline)
   - [1.3 Live2D–LLM Interaction Architecture](#13-live2dllm-interaction-architecture)
3. [request2.md — Part 2: Baseline Operational Tasks](#request2md--part-2-baseline-operational-tasks)
4. [Newcastle.md — Notification Feature](#newcastlemd--notification-feature)
   - [Prerequisite: Global On/Off Toggle](#prerequisite-global-onoff-toggle)
   - [Prerequisite: Character Name Setting](#prerequisite-character-name-setting)
   - [Prerequisite: Prompt Block Generalization](#prerequisite-prompt-block-generalization)
   - [Prompt Preview Feature](#prompt-preview-feature)
   - [Prompt Preset System](#prompt-preset-system)
   - [Notification Settings & Technical Implementation](#notification-settings--technical-implementation)
   - [Notification Message Format](#notification-message-format)
   - [Notification–AI Chat Integration](#notificationai-chat-integration)
   - [Proactive Response Feature](#proactive-response-feature)
5. [Priority Action Items](#priority-action-items)

---

## Overall Summary

| Document | Total Features | Fully Implemented | Partially Implemented | Not Implemented |
|----------|---------------|-------------------|-----------------------|-----------------|
| **request2.md Part 1** | 3 major systems | 0 | 1 (Live2D display/settings) | 2 (Lua, LLM interaction) |
| **request2.md Part 2** | 2 tasks | 0 | 0 | 2 (blocked by Part 1) |
| **Newcastle.md** | 8 feature groups | 4 | 3 | 1 |

> [!IMPORTANT]
> **Newcastle.md features are significantly more complete** than request2.md Part 1. The Lua scripting engine, regex processing pipeline, and Live2D–LLM interaction architecture (request2.md §1.2, §1.3) are **entirely unimplemented** and represent the largest development gap.

---

## request2.md — Part 1: Major Feature Development

### 1.1 Live2D Feature Improvements

#### 1.1.2 Live2D Display Edit Mode

**Reference:** `request2.md` lines 17–43

| # | Requirement | Status | Evidence / Notes |
|---|-------------|--------|-----------------|
| 1 | Container–Model Relative Sizing | ⚠️ **Partial** | `Live2DDisplayConfig` in `lib/features/live2d/data/models/display_config.dart` stores `relativeScaleRatio`, `containerWidthRatio`, `containerHeightRatio`, `modelScaleX`, `modelScaleY`. The schema exists, but **on-device persistence stability has NOT been verified** — `request2.md` explicitly flags this as a known bug. |
| 2 | Absolute Size Persistence | ⚠️ **Partial** | `containerWidthDp`, `containerHeightDp` fields exist. `Live2DDisplayConfigStore` (singleton) saves via SharedPreferences as JSON. However, **reload fidelity is untested** — the requirement notes data is "lost upon reload." |
| 3 | Position Persistence | ⚠️ **Partial** | `containerXRatio`, `containerYRatio`, `modelOffsetXRatio`, `modelOffsetYRatio`, `modelOffsetXDp`, `modelOffsetYDp` fields exist. Whether these are **correctly applied on restore** is undetermined. |
| 4 | Model Linking | ⚠️ **Partial** | `modelId` and `modelPath` in `Live2DDisplayConfig`. `loadForModel(String modelId)` in `Live2DDisplayConfigStore` provides retrieval by model ID. The requirement says linking is "unstable and frequently breaks" — **the root bug is likely not fixed.** |
| 5 | Edit Mode UI | ⚠️ **Partial** | `setEditMode(bool)` exists in `Live2DNativeBridge`. Display settings screen (`display_settings_screen.dart`, 19KB) exists. Pinch-to-zoom, drag, resize controls need **on-device validation**. "Reset to Default" and "Save" actions exist but their reliability is unknown. |
| 6 | Data Storage Format | ✅ **Implemented** | `Live2DDisplayConfig.toJson()` / `fromJson()` with `schemaVersion` field. JSON stored in SharedPreferences via `Live2DDisplayConfigStore`. All required fields (`modelId`, `containerWidth/Height`, `containerX/Y`, `modelScaleX/Y`, `modelOffsetX/Y`, `relativeScaleRatio`, `schemaVersion`) are present. |
| 7 | Migration & Validation | ⚠️ **Partial** | `migrateLegacy()` method exists in `Live2DDisplayConfigStore`. `isValid` getter exists on `Live2DDisplayConfig`. However, **schema version migration logic** (beyond legacy→current) and **corruption detection with user notification** are not evident. |

> [!WARNING]
> **Critical Gap:** The core problem described in request2.md — "correctly saving and restoring the relationship between the transparent bounding container and the character model" — is **architecturally addressed** (the data model exists), but **functional correctness is unverified**. The requirement explicitly states saved data is lost upon reload. An agent must:
> 1. Write a comprehensive test that saves → kills app → restores → compares all display values.
> 2. Debug the save/restore path end-to-end through `Live2DDisplayConfigStore.save()` → `SharedPreferences` → `loadForModel()` → native bridge application.
> 3. Test across screen rotation and different screen densities using `normalizeWithScreen()`.

**Acceptance Criteria Status:**
- ❌ Save → exit → relaunch → exact restore: **Not verified, likely broken**
- ❌ Multi-model linking isolation: **Not verified**
- ❌ Screen rotation / density resilience: **Not verified**

---

#### 1.1.3 Live2D Advanced Settings

**Reference:** `request2.md` lines 46–71

| # | Requirement | Status | Evidence / Notes |
|---|-------------|--------|-----------------|
| 1 | Motion Inventory Detection | ✅ **Implemented** | `getMotionGroups()`, `getMotionCount(group)`, `getMotionNames(group)` in `Live2DNativeBridge`. `analyzeModel(modelPath)` available. |
| 2 | No-Motion Fallback | ⚠️ **Partial** | Native bridge methods exist but **UI fallback behavior** (hiding controls, displaying notice) is not clearly implemented in the settings screens. Crash safety is not verified. |
| 3 | Automatic Motion Playback | ⚠️ **Partial** | `setAutoMotion(bool)` and `playMotion(group, index, priority)` exist in native bridge. Priority system (idle < normal < forced) **is supported at the API level** (`priority` parameter). However, the **idle looping toggle UI** and **LLM-triggered motion integration** (§1.3) are missing. |
| 4 | Parameter Direct Control | ✅ **Implemented** | `setParameter(paramId, value, durationMs)` and `getParameter(paramId)` exist. `getParameterIds()` available. |
| 5 | Parameter Smoothing | ⚠️ **Partial** | `durationMs` parameter exists in `setParameter()`. Whether native side actually implements smooth interpolation over the specified duration needs verification. Default 200ms as per spec is not enforced — default is 0. |
| 6 | Settings Persistence | ⚠️ **Partial** | `Live2DSettings`, `DisplayPreset`, `InteractionConfig` models exist with serialization. Whether **all advanced settings are persisted per model** (as opposed to globally) needs verification. |
| 7 | Expression Support | ✅ **Implemented** | `getExpressions()`, `setExpression(expressionId)`, `setRandomExpression()` all available in native bridge. |

> [!NOTE]
> The Live2D subsystem has a **rich native bridge API** with 60+ methods. The bridge layer is well-structured. The gaps are primarily in:
> - **UI-level fallback/graceful degradation** for models without motions/expressions
> - **Per-model settings persistence** (vs. global settings)
> - **End-to-end testing** to confirm all API calls work correctly on device

---

### 1.2 Lua Scripting Engine & Regex Pipeline

**Reference:** `request2.md` lines 74–147

#### 1.2.3 Lua Scripting Engine

| # | Requirement | Status | Evidence |
|---|-------------|--------|----------|
| 1 | Embedded Lua Runtime | ❌ **Not Implemented** | No Lua interpreter integration found. No dependency on LuaJ, `lua_dardo`, or any Lua library in `pubspec.yaml`. Zero Lua-related source files in `lib/`. |
| 2 | Script Lifecycle Hooks | ❌ **Not Implemented** | No `onLoad`, `onUserMessage`, `onAssistantMessage`, `onPromptBuild`, `onDisplayRender`, `onUnload` hooks exist. |
| 3 | Live2D Bridge API (Lua-callable) | ❌ **Not Implemented** | The Dart/native bridge API exists (`Live2DNativeBridge`), but **no Lua binding layer** has been created. |
| 4 | Chat Context API | ❌ **Not Implemented** | No `chat.getHistory()`, `chat.getCurrentMessage()`, etc. exposed to scripting. |
| 5 | CSS/Asset Injection API | ❌ **Not Implemented** | No `ui.injectCSS()`, `ui.loadAsset()`, `ui.setMessageHTML()` functions. Chat rendering uses standard Flutter widgets, not WebView/HTML. |
| 6 | Script Management UI | ❌ **Not Implemented** | No UI for importing, enabling/disabling, ordering, or viewing Lua scripts. |
| 7 | Error Handling | ❌ **Not Implemented** | No Lua error catch, timeout, or log viewer. |
| 8 | Security Sandbox | ❌ **Not Implemented** | No sandboxing layer. |

> [!CAUTION]
> **The entire Lua scripting engine is unimplemented.** This is a **foundational dependency** for §1.3 (Live2D–LLM Interaction). An agent would need to:
> 1. Choose a Lua runtime for Flutter/Android (e.g., `lua_dardo` for Dart, or JNI-based native Lua for Kotlin).
> 2. Implement sandbox, lifecycle hooks, and all bridge APIs from scratch.
> 3. Build the script management UI.
> Estimated effort: **Large** (several days+ of focused development).

#### 1.2.4 Regex Processing Pipeline

| # | Requirement | Status | Evidence |
|---|-------------|--------|----------|
| 1 | Rule CRUD | ❌ **Not Implemented** | No `RegexRule` model, no regex rule repository, no rule management UI. |
| 2 | Rule Testing | ❌ **Not Implemented** | No inline test feature. |
| 3 | Ordered Execution | ❌ **Not Implemented** | No pipeline with priority-ordered rule execution. |
| 4 | Scope Control | ❌ **Not Implemented** | No global/per-character/per-session scoping. |
| 5 | Import/Export | ❌ **Not Implemented** | No JSON import/export for regex rules. |
| 6 | Interaction with Lua | ❌ **Not Implemented** | No ordering between regex and Lua. |
| 7 | Performance (cached compilation) | ❌ **Not Implemented** | No regex compilation cache or backtracking timeout. |

> [!CAUTION]
> **The entire regex processing pipeline is unimplemented.** This is also a dependency for §1.3. The `live2d_pipeline_prototype_screen.dart` exists (9KB) and contains some **prototype/experimental** regex processing for Live2D directives, but it is **not** the general-purpose pipeline described in the requirement.

---

### 1.3 Live2D–LLM Interaction Architecture

**Reference:** `request2.md` lines 150–274

| # | Requirement | Status | Evidence |
|---|-------------|--------|----------|
| 1 | Directive Tag Format (`<live2d>` blocks) | ❌ **Not Implemented** | No parser for `<live2d>`, `<param>`, `<motion>`, `<expression>` tags in the codebase. Prototype exists in `live2d_pipeline_prototype_screen.dart` but is **non-functional/experimental only**. |
| 2 | System Prompt Template | ❌ **Not Implemented** | `PromptBuilder.buildSystemPrompt()` builds a character roleplay prompt but does **not** inject Live2D capability descriptions or `<live2d>` tag instructions. |
| 3 | Dynamic Model Capability Injection | ❌ **Not Implemented** | No code queries the loaded model's parameters/motions/expressions and injects them into the system prompt. |
| 4 | Parsing Lua Script (Default) | ❌ **Not Implemented** | No default Lua script ships with the app. |
| 5 | Sequential Command Execution | ❌ **Not Implemented** | No sequential command executor with delays. |
| 6 | Emotion Preset Mapping | ❌ **Not Implemented** | No emotion-to-parameter mapping system. |
| 7 | Fallback & Error Tolerance | ❌ **Not Implemented** | No malformed tag handling. |
| 8 | Streaming Response Support | ❌ **Not Implemented** | No `<live2d>` block buffering in token stream. |
| 9 | Bidirectional Interaction | ❌ **Not Implemented** | No Live2D→prompt injection on tap events. |
| 10 | User Control & Privacy | ❌ **Not Implemented** | No toggle for directive parsing or system prompt injection. |

> [!CAUTION]
> **The entire Live2D–LLM interaction system is unimplemented.** This is the most complex feature in request2.md and depends on both the Lua engine (§1.2.3) and the regex pipeline (§1.2.4). All 10 requirements score ❌.

---

## request2.md — Part 2: Baseline Operational Tasks

**Reference:** `request2.md` lines 278–320

> [!IMPORTANT]
> Per `request2.md` §Part 2 execution condition: *"Part 2 shall only commence after all tasks in Part 1 have been fully completed, tested, and verified."* Since Part 1 is far from complete, **Part 2 is blocked and should NOT be started.**

| Section | Requirement | Status |
|---------|-------------|--------|
| 2.1 | Stabilization & Optimization (full codebase audit, profiling, refactoring) | 🔒 **Blocked** — Part 1 incomplete |
| 2.2 | Feature Supplementation & Enhancement (gap analysis, backlog, implementation) | 🔒 **Blocked** — Part 1 incomplete |

---

## Newcastle.md — Notification Feature

### Prerequisite: Global On/Off Toggle

**Reference:** `Newcastle.md` lines 9–18

| Requirement | Status | Evidence |
|-------------|--------|----------|
| Prominent On/Off button at top of menu | ⚠️ **Partial** | `GlobalRuntimeProvider` exists with `isEnabled` state, persisted via SharedPreferences. However, the **toggle is NOT visible in the menu drawer** (`menu_drawer.dart`). The menu has no global On/Off switch at the top. |
| Controls Live2D overlay + notifications | ✅ **Implemented** | `GlobalRuntimeRegistry` with listener pattern. `ProactiveResponseService`, `NotificationCoordinator` both implement `GlobalRuntimeListener` with `onGlobalEnabled()`/`onGlobalDisabled()`. |
| Cancels in-progress API calls, clears notifications, stops timers | ✅ **Implemented** | `onGlobalDisabled()` in both services stops timers, cancels in-flight requests, clears notifications. |
| Persisted across restarts | ✅ **Implemented** | `SharedPreferences` key `global_runtime_enabled`. |
| Modularized registration interface | ✅ **Implemented** | `GlobalRuntimeListener` abstract class + `GlobalRuntimeRegistry` singleton with `register()`/`unregister()`. Clean listener/callback pattern. |

> [!WARNING]
> **Missing:** The global toggle **must be added to the menu drawer UI** (`menu_drawer.dart`). The backend is fully implemented but the **UI entry point does not exist in the menu**. This is a straightforward UI addition.

---

### Prerequisite: Character Name Setting

**Reference:** `Newcastle.md` lines 21–24

| Requirement | Status | Evidence |
|-------------|--------|----------|
| Character Name display at top of menu | ❌ **Not Implemented** | `menu_drawer.dart` shows "Pocket Waifu" as a static header. No character name display or tap-to-edit. |
| Tap to edit character name | ❌ **Not Implemented** | `SettingsProvider.setCharacterName(String)` exists, and `Character` model has a `name` field, but **no dedicated Character Name UI** exists in the menu. Character name can only be edited deep in the settings screen. |
| Used in notification titles | ⚠️ **Partial** | `NotificationCoordinator` passes a `title` string to notifications. The title can be set to the character name, but there's no direct linkage from a "Character Name setting" in the menu. |

> [!NOTE]
> The data model supports character names (`Character.name`), and `SettingsProvider` can set/get them. The gap is purely **UI**: a tappable character name display at the top of the menu drawer.

---

### Prerequisite: Prompt Block Generalization

**Reference:** `Newcastle.md` lines 27–105

| Requirement | Status | Evidence |
|-------------|--------|----------|
| JSON structure for prompt blocks | ✅ **Implemented** | `PromptBlock` model with `type`, `title`, `content`, `isActive`, `range`, `userHeader`, `charHeader`. JSON serialization via `toMap()`/`fromMap()`. |
| Recognized types: `prompt`, `pastmemory`, `input` | ✅ **Implemented** | `PromptBlock.typePrompt`, `typePastMemory`, `typeInput` constants. `isRecognizedType()` static method. |
| `pastmemory` block behavior (range, headers, chronological order) | ✅ **Implemented** | `PromptBuilder._buildPastMemoryXml()` correctly parses range, applies `userHeader`/`charHeader` as XML tags, orders oldest-to-newest, defaults invalid range to 1. |
| `input` block behavior | ✅ **Implemented** | `PromptBuilder.buildFinalPrompt()` handles `typeInput` correctly. `skipInputBlock` flag supported. |
| Multiple blocks of same type processed in order | ✅ **Implemented** | Blocks are sorted by `order` and iterated — all active blocks contribute to output. |
| Block UI (toggle, name, reorder, type-specific fields) | ✅ **Implemented** | `PromptEditorScreen` (978 lines) with block cards, toggle, add/edit/delete dialogs. Reordering via `reorderBlocks()`. Type-specific edit dialogs. |
| Inactive blocks excluded from API payload | ✅ **Implemented** | `blocks.where((block) => block.isActive)` filter in `buildFinalPrompt()`. |
| No permanently fixed blocks | ✅ **Implemented** | All blocks can be added/removed via UI. No hardcoded blocks. |
| Data migration from legacy system | ✅ **Implemented** | `_migrateLegacyBlocks()` in `PromptBlockProvider` handles migration from old `prompt_blocks` key. |

> [!TIP]
> **This section is fully implemented and appears functional.** Minor testing recommended to confirm edge cases (zero blocks, all blocks inactive, extremely large range values).

---

### Prompt Preview Feature

**Reference:** `Newcastle.md` lines 108–124

| Requirement | Status | Evidence |
|-------------|--------|----------|
| Displays final compiled output as sent to API | ✅ **Implemented** | `PromptPreviewScreen` uses `PromptBuilder.buildFinalPrompt()` with actual blocks and messages. |
| Uses actual chat records from active session | ✅ **Implemented** | `chatProvider.messages` passed to builder. |
| Scrollable for long prompts | ✅ **Implemented** | `SingleChildScrollView` wrapping `SelectableText`. |
| Preset selector at top | ✅ **Implemented** | `DropdownButtonFormField` with all presets. `_selectedPresetId` state variable. |

> [!TIP]
> **Fully implemented.** Also includes character/token count statistics and clipboard copy.

---

### Prompt Preset System

**Reference:** `Newcastle.md` lines 127–152

| Requirement | Status | Evidence |
|-------------|--------|----------|
| Preset bar at bottom of editor (Select, Save, Delete, Add) | ✅ **Implemented** | `_PresetBar` widget in `PromptEditorScreen` with dropdown selector, save/delete/add buttons, and menu actions. |
| Add new preset with name | ✅ **Implemented** | `_showAddPresetDialog()` prompts for name, calls `provider.addPreset(name)`. |
| Load preset with unsaved-changes warning | ✅ **Implemented** | `_handlePresetSwitch()` checks `provider.isDirty` and shows save/discard/cancel dialog. |
| Save current changes | ✅ **Implemented** | `provider.saveActivePreset()`. |
| Delete with minimum-one-preset guard | ✅ **Implemented** | `_confirmDeletePreset()` checks `provider.presets.length > 1`. Shows confirmation popup. |
| Reference handling on deletion | ✅ **Implemented** | `NotificationSettingsProvider.rebindPromptPresets()` reassigns references on preset deletion. |
| Rename preset | ✅ **Implemented** | `_handlePresetMenuAction` includes rename with `provider.renamePreset()`. |
| Export/Import JSON | ✅ **Implemented** | `exportPresetToFile()` and `importPresetFromFile()` in `PromptBlockProvider` using `file_picker`. |
| Default preset on first install | ✅ **Implemented** | `_buildDefaultPreset()` creates a preset with System, Past Memory, and Input blocks. |

> [!TIP]
> **Fully implemented.** The preset system is complete with all CRUD operations, import/export, and reference management.

---

### Notification Settings & Technical Implementation

**Reference:** `Newcastle.md` lines 155–186

| Requirement | Status | Evidence |
|-------------|--------|----------|
| Notification Settings UI screen | ✅ **Implemented** | `NotificationSettingsScreen` (276 lines) with all toggle options. |
| Notifications On/Off toggle | ✅ **Implemented** | `setNotificationsEnabled(bool)` with permission check. |
| Persistent Notification On/Off | ✅ **Implemented** | `setPersistentEnabled(bool)`. Backend uses `FLAG_ONGOING_EVENT` in Kotlin. |
| Output as New Notification On/Off | ✅ **Implemented** | `setOutputAsNewNotification(bool)`. Heads-up channel with `IMPORTANCE_HIGH`. |
| Prompt Block Preset Selection | ✅ **Implemented** | `_PresetDropdown` in notification settings screen. |
| API Preset Selection | ✅ **Implemented** | `_ApiPresetDropdown` in notification settings screen. |
| Foreground Service | ✅ **Implemented** | `NotificationForegroundService.kt` (Kotlin) + `NotificationBridge.startForegroundService()` (Flutter). |
| Notification channels | ✅ **Implemented** | `NotificationHelper.createChannels()` creates persistent (LOW importance) and heads-up (HIGH importance) channels. |
| Android 13+ POST_NOTIFICATIONS permission | ✅ **Implemented** | `permission_handler` package used. `ensureNotificationPermission()` with runtime request. `_showPermissionDialog()` in settings screen. |
| Auto-restore on app relaunch | ⚠️ **Partial** | `NotificationCoordinator._syncPersistentNotification()` exists but whether it fires correctly on cold start needs verification. |

> [!NOTE]
> **Notification Settings screen entry point:** The `NotificationSettingsScreen` exists but **is NOT linked from the menu drawer** (`menu_drawer.dart`). There is no menu item to navigate to notification settings. This must be added.

---

### Notification Message Format

**Reference:** `Newcastle.md` lines 188–219

| Requirement | Status | Evidence |
|-------------|--------|----------|
| Persistent notification (undismissable) | ✅ **Implemented** | `ongoing: true` flag in `buildPersistentNotification()`. |
| Character name in title | ⚠️ **Partial** | Title parameter is passed through, but automatic linkage to Character Name setting is not explicit. |
| Long response with full message (BigTextStyle) | ✅ **Implemented** | `NotificationCompat.BigTextStyle().bigText(statusText)` used. |
| Reply button with inline input | ✅ **Implemented** | `RemoteInput.Builder` with reply action in `buildPersistentNotification()`. |
| Cancel button (for reply) | ✅ **Implemented** | `ACTION_CANCEL_REPLY` action in notification. |
| Touch-Through button | ✅ **Implemented** | `ACTION_TOUCH_THROUGH` action with broadcast receiver. |
| Loading indicator after reply ("Responding...") | ✅ **Implemented** | `isLoading -> "Responding..."` in `buildPersistentNotification()`. |
| API failure error message in notification | ✅ **Implemented** | `isError` flag + `setNotificationError()` in native bridge. |

> [!TIP]
> **Notification message format is well-implemented** with Reply, Cancel, and Touch-Through buttons. Android notification best practices are followed.

---

### Notification–AI Chat Integration

**Reference:** `Newcastle.md` lines 222–243

| Requirement | Status | Evidence |
|-------------|--------|----------|
| Notification uses selected prompt block preset | ✅ **Implemented** | `NotificationCoordinator` resolves prompt preset from `NotificationSettingsProvider`. |
| Notification uses selected API preset | ✅ **Implemented** | `_resolveApiConfig()` in `NotificationCoordinator`. |
| Operates on main active session (not separate) | ✅ **Implemented** | `activeSessionId` from `ChatSessionProvider`. |
| Disabled if no active session | ⚠️ **Partial** | `if (resolvedSessionId == null) return;` — silently skips. **No user-facing message** prompting to create a session. |
| Reply input serves as user input | ✅ **Implemented** | `handleNotificationReply(String message)` processes reply text. |
| AI response delivered as notification | ✅ **Implemented** | Response posted via `showHeadsUpNotification()` and `updatePersistentNotification()`. |
| Main session synchronization | ✅ **Implemented** | Messages appended to session via `sessionProvider.addMessage()` and `saveSessions()`. |
| Thread safety (serialization) | ⚠️ **Partial** | `_requestLock` Completer pattern in `NotificationCoordinator` for mutual exclusion. However, concurrent access between in-app chat and notification reply needs more robust testing. |

---

### Proactive Response Feature

**Reference:** `Newcastle.md` lines 246–380

| Requirement | Status | Evidence |
|-------------|--------|----------|
| Proactive Response settings in menu | ⚠️ **Partial** | Settings are part of `NotificationSettingsScreen` but **the screen itself is not accessible from menu drawer**. |
| Condition configuration (TXT format grammar) | ✅ **Implemented** | `ProactiveConfigParser.parse()` fully implements the grammar (key=min~max, key=0). Supports `overlayon`, `overlayoff`, `screenlandscape`, `screenoff`. Enforces >10s minimum, error messages per line. |
| API preset selection | ✅ **Implemented** | `ProactiveResponseSettings.apiPresetId` + UI dropdown. |
| Prompt preset selection | ✅ **Implemented** | `ProactiveResponseSettings.promptPresetId` + UI. |
| Environment condition priority | ✅ **Implemented** | `_selectRange()` in `ProactiveResponseService` checks `screenoff` > `screenlandscape` > `overlayoff` > `overlayon`. |
| Input block silently skipped | ✅ **Implemented** | `skipInputBlock: true` passed to `triggerProactiveResponse()`. |
| Timer resets after successful response | ✅ **Implemented** | `_reschedule()` called after successful trigger. |
| User reply cancels in-flight proactive API call | ✅ **Implemented** | `cancelInFlightDueToUserReply()` → `cancelProactiveInFlight()`. Timer continues from same interval. |
| Results delivered as notification + synced to main session | ✅ **Implemented** | `triggerProactiveResponse()` calls through `NotificationCoordinator` which syncs to session. |
| API failure → error notification | ✅ **Implemented** | Error handling in `triggerProactiveResponse()` with `setNotificationError()`. |
| Background/Foreground Service keep-alive | ✅ **Implemented** | `NotificationForegroundService` with timer continuation. |
| Doze-mode considerations | ⚠️ **Partial** | Standard `Timer` used — no `setExactAndAllowWhileIdle()`. May drift under Doze mode. |

---

## Priority Action Items

### 🔴 Critical (Must fix before any Part 2 work)

1. **Lua Scripting Engine** (`request2.md` §1.2.3) — **Entirely unimplemented**
   - Choose runtime (recommend `lua_dardo` for Dart or JNI Lua for native)
   - Implement sandbox, lifecycle hooks, bridge APIs
   - Build script management UI
   - **Files to create:** `lib/features/lua/` module (runtime, bridge, models, UI)

2. **Regex Processing Pipeline** (`request2.md` §1.2.4) — **Entirely unimplemented**
   - Create `RegexRule` model, repository, pipeline executor
   - Build rule CRUD UI with testing feature
   - Implement 4 rule types (User Input, AI Output, Prompt Injection, Display-Only)
   - **Files to create:** `lib/features/regex/` module (models, pipeline, UI)

3. **Live2D–LLM Interaction Architecture** (`request2.md` §1.3) — **Entirely unimplemented**
   - Depends on Lua engine + regex pipeline
   - Implement `<live2d>` directive tag parser
   - Dynamic system prompt injection with model capabilities
   - Emotion preset mapping system
   - Streaming response buffering
   - **Files to modify:** `lib/services/prompt_builder.dart`, `lib/services/api_service.dart`
   - **Files to create:** `lib/features/live2d_llm/` module

### 🟡 High Priority (Required for feature completeness)

4. **Global Toggle UI in Menu Drawer** (`Newcastle.md`)
   - Backend is complete (`GlobalRuntimeProvider`, `GlobalRuntimeRegistry`)
   - **Add:** Prominent On/Off switch at the top of `lib/screens/menu_drawer.dart`
   - Effort: Small (30 min)

5. **Character Name Display in Menu** (`Newcastle.md`)
   - Backend exists (`SettingsProvider.setCharacterName()`, `Character.name`)
   - **Add:** Tappable character name at top of menu drawer with edit dialog
   - Link character name to notification titles
   - Effort: Small–Medium (1–2 hours)

6. **Notification Settings Menu Entry** (`Newcastle.md`)
   - `NotificationSettingsScreen` exists (276 lines, fully functional)
   - **Add:** Menu item in `lib/screens/menu_drawer.dart` linking to `NotificationSettingsScreen`
   - Effort: Trivial (15 min)

7. **Live2D Display Edit Mode Verification** (`request2.md` §1.1.2)
   - Data model and native bridge exist
   - **Action:** On-device testing of save → kill → restore cycle
   - Debug and fix any persistence failures
   - Effort: Medium (2–4 hours testing + debugging)

### 🟢 Lower Priority (Polish & robustness)

8. **No-Motion / No-Expression Fallback UI** (`request2.md` §1.1.3 #2)
   - Hide/disable motion controls when model has no motions
   - Show user notice

9. **Parameter Smoothing Default** (`request2.md` §1.1.3 #5)
   - Change default `durationMs` from 0 to 200 for programmatic parameter changes

10. **Session-absent Notification Reply** (`Newcastle.md`)
    - Show error message when no active session exists instead of silently failing

11. **Doze-mode Timer** (`Newcastle.md`)
    - Consider `android_alarm_manager_plus` or `setExactAndAllowWhileIdle()` for proactive response timers

---

## File Reference Summary

### Key Source Files

| Feature Area | Key Files |
|---|---|
| Live2D Display | `lib/features/live2d/data/models/display_config.dart`, `lib/features/live2d/data/services/display_config_store.dart` |
| Live2D Native Bridge | `lib/features/live2d/data/services/live2d_native_bridge.dart` (867 lines, 60+ methods) |
| Live2D Settings UI | `lib/features/live2d/presentation/screens/live2d_settings_screen.dart` (56K), `display_settings_screen.dart` (19K) |
| Prompt Blocks | `lib/models/prompt_block.dart`, `lib/providers/prompt_block_provider.dart` (541 lines) |
| Prompt Presets | `lib/models/prompt_preset.dart`, `lib/screens/prompt_editor_screen.dart` (978 lines) |
| Prompt Preview | `lib/screens/prompt_preview_screen.dart` |
| Prompt Builder | `lib/services/prompt_builder.dart` |
| Global Toggle | `lib/providers/global_runtime_provider.dart`, `lib/services/global_runtime_registry.dart` |
| Notification Bridge | `lib/services/notification_bridge.dart`, `lib/services/notification_coordinator.dart` (365 lines) |
| Notification UI | `lib/screens/notification_settings_screen.dart` |
| Notification Android | `android/.../notifications/NotificationHelper.kt` (205 lines), `NotificationForegroundService.kt`, `NotificationActionReceiver.kt` |
| Proactive Response | `lib/services/proactive_response_service.dart`, `lib/services/proactive_config_parser.dart` |
| Menu Drawer | `lib/screens/menu_drawer.dart` (327 lines) — **needs Global Toggle, Character Name, Notification Settings entry** |
| Settings | `lib/providers/settings_provider.dart`, `lib/models/settings.dart` |

### Requirement Documents

| Document | Path | Scope |
|---|---|---|
| **request2.md** | `docs/request2.md` | Part 1: Live2D improvements, Lua engine, regex pipeline, LLM interaction. Part 2: Stabilization & enhancement (blocked). |
| **Newcastle.md** | `docs/Newcastle.md` | Global toggle, character name, prompt blocks, presets, notifications, proactive response. |

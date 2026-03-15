# Transforms: Regex And Lua

This document explains how text transforms work before and after LLM calls, where regex and Lua are applied, and how to decide which layer should own a new behavior.

## Owned Code Paths

- `lib/features/regex/models/regex_rule.dart`
- `lib/features/regex/services/regex_pipeline_service.dart`
- `lib/features/lua/models/lua_script.dart`
- `lib/features/lua/services/lua_native_bridge.dart`
- `lib/features/lua/services/lua_scripting_service.dart`
- `lib/screens/regex_lua_management_screen.dart`
- `lib/providers/chat_provider.dart`
- `lib/services/api_service.dart`
- `lib/services/notification_coordinator.dart`

## The Two Transform Systems

### Regex pipeline

Use regex when the behavior is:
- deterministic
- text-only
- easy to express as match-and-replace
- sensitive to strict ordering and scope

### Lua pipeline

Use Lua when the behavior is:
- programmable
- easier to express as hook logic than pure replacements
- potentially multi-step or context-sensitive

Neither system owns transport or storage. They only transform strings or hookable lifecycle events.

## Regex Rule Model

`RegexRule` contains:
- rule type
- pattern and replacement
- flags: case-insensitive, multiline, dotAll
- enable flag
- priority
- scope:
  - global
  - perCharacter
  - perSession

### Rule types

- `userInput`
- `aiOutput`
- `promptInjection`
- `displayOnly`

### Execution rules

- only enabled rules with matching type are applied
- scope filters are checked before execution
- rules are sorted by ascending priority
- compiled regex objects are cached by id
- a performance guard skips obviously dangerous patterns

## Lua Script Model

`LuaScript` contains:
- name
- content
- enable flag
- order
- scope:
  - global
  - perCharacter

### Hook names

- `onLoad`
- `onUnload`
- `onUserMessage`
- `onAssistantMessage`
- `onPromptBuild`
- `onDisplayRender`

### Execution strategy

`LuaScriptingService` tries the native Lua bridge first.

If native execution fails or returns no value:
- it falls back to a pseudo-Lua comment-based interpreter

Fallback support is intentionally small. It only preserves lifecycle compatibility and a few deterministic transforms.

## Ordering Rules

Ordering is controlled by `AppSettings.runRegexBeforeLua`.

### User input path

In `ChatProvider` and `NotificationCoordinator`:

- if true:
  - regex `userInput`
  - Lua `onUserMessage`
- if false:
  - Lua `onUserMessage`
  - regex `userInput`

### Assistant output path

- if true:
  - regex `aiOutput`
  - Lua `onAssistantMessage` (includes directive ownership when the editable default script marker is enabled)
- if false:
  - Lua `onAssistantMessage` (includes directive ownership when the editable default script marker is enabled)
  - regex `aiOutput`

### Prompt build path

Inside `ApiService`:

- if true:
  - regex `promptInjection`
  - Lua `onPromptBuild`
- if false:
  - Lua `onPromptBuild`
  - regex `promptInjection`

### Display-only path

After assistant output cleanup/directive ownership:

- if true:
  - regex `displayOnly`
  - Lua `onDisplayRender`
- if false:
  - Lua `onDisplayRender`
  - regex `displayOnly`

## Where These Transforms Run

### Chat flow

Owned by `ChatProvider` plus `ApiService`.

### Notification reply flow

Owned by `NotificationCoordinator` plus `ApiService`.

### Agent mode flow

Agent mode is special.

It uses:
- regex rules embedded inside `AgentPromptPreset`
- optional shared Lua assistant/display hooks
- additional parsing for `notify(...)` and `end()` actions

This means agent mode is not a simple reuse of the normal prompt block transform stack.

## Default Regex Behavior

The shipped default regex set now owns the public assistant directive syntax.

- `aiOutput` rules convert public syntax into internal runtime tokens:
  - `<live2d>...</live2d>` -> `<pwf-live2d>...</pwf-live2d>`
  - `<overlay>...</overlay>` -> `<pwf-overlay>...</pwf-overlay>`
  - `[param:...]`, `[motion:...]`, `[expression:...]`, `[emotion:...]`, `[wait:...]`, `[preset:...]`, `[reset]` -> `[pwf-live2d:...]`
  - `[img_move:...]`, `[img_emotion:...]` -> `[pwf-overlay:...]`
- `displayOnly` rules remove both the public syntax and the internal runtime tokens so chat and notifications stay clean.

This keeps the user-facing syntax editable in Regex/Lua instead of silently owned by hardcoded assistant post-processing.

## Choosing The Right Layer

### Use regex when

- you need stable machine-token cleanup
- you are normalizing formatting
- you are extracting or removing deterministic markers

### Use Lua when

- you want hook-based custom logic
- you need a user-editable programmable stage
- you want the possibility of native Lua runtime expansion later

### Use directives instead when

- the output should directly trigger runtime behavior such as Live2D motion, parameter change, image overlay move, or screenshot-side action coupling

### Use prompt blocks instead when

- the behavior is structural prompt composition, not text post-processing

## Extension Guidance

### Add a new regex phase

This is a structural change. It affects all callers and should only happen if the current four-phase model is no longer sufficient.

### Add a new Lua hook

Update:
- `LuaScriptingService`
- native Lua bridge contract if needed
- docs and UI help text

### Add a new transform-driven feature

Check whether the feature must also run in:
- normal chat
- notification replies
- proactive responses
- agent mode

If parity matters, do not implement it in only one caller.

## Common Failure Modes

- Forgetting that prompt text has its own transform phase inside `ApiService`.
- Implementing a cleanup rule in regex when it should actually be a directive parser.
- Assuming Lua is always native; it can fall back to pseudo-Lua behavior.
- Changing transform order without checking both chat and notification flows.

## Cross-Links

- Base request flow -> `docs/FEATURES/LLM_AND_PROMPTS.md`
- Live2D directives after transform stages -> `docs/FEATURES/LIVE2D_RUNTIME.md`
- Notification and agent-specific flows -> `docs/FEATURES/NOTIFICATIONS.md`

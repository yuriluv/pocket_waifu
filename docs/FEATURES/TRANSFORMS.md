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

### Shipped default Lua template

The shipped default script is an editable template, not a hardcoded semantic owner.

- seed source: `LuaScriptingService._defaultScripts()`
- default script name: `default_runtime_template.lua`
- responsibility: recognize text and emit runtime function tokens such as `[pwf-fn:live2d.motion:name=Idle/0]`

The system contract is now:
- Lua decides what input text means.
- the app only executes exposed runtime functions.
- Regex is for text repair and display cleanup, not for assigning runtime semantics.

The fallback pseudo-Lua runtime exposes helper functions like:
- `pwf.gsub(text, pattern, replacement)`
- `pwf.replace(text, from, to)`
- `pwf.call(functionName, payload)`
- `pwf.emit(text, functionName, payload)`

Those helpers let the default template support legacy XML-like strings while remaining fully user-editable.

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
  - Lua `onAssistantMessage`
  - runtime function execution step
- if false:
  - Lua `onAssistantMessage`
  - regex `aiOutput`
  - runtime function execution step

### Prompt build path

Inside `ApiService`:

- if true:
  - regex `promptInjection`
  - Lua `onPromptBuild`
- if false:
  - Lua `onPromptBuild`
  - regex `promptInjection`

### Display-only path

After assistant output cleanup/runtime function execution:

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

The shipped default regex set is intentionally small.

- it hides Lua-emitted runtime function tokens from final display
- it trims blank lines left after token removal
- it may be extended by the user to repair malformed model output before Lua parses it

Default regex no longer assigns meaning to `<live2d>`, `<overlay>`, or inline command syntax.

## Choosing The Right Layer

### Use regex when

- you need stable machine-token cleanup
- you are normalizing formatting
- you are extracting or removing deterministic markers
- you are repairing malformed control text before Lua parses it

### Use Lua when

- you want hook-based custom logic
- you need a user-editable programmable stage
- you want to map arbitrary text formats to runtime functions
- you want the possibility of native Lua runtime expansion later

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

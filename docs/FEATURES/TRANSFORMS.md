# Transforms: Regex And Lua

This document explains how text transforms work before and after LLM calls, where regex and Lua are applied, and how to decide which layer should own a new behavior.

CBS now sits beside these transforms as a session-aware syntax renderer. It is not stored inside regex or Lua, but it must respect the same caller boundaries.

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

The hardened contract is:
- fallback Lua is the supported safe subset
- full/native Lua behavior is optional and should only be relied on when native Lua availability is verifiably true in the current runtime

### Shipped default Lua template

The shipped default script is an editable template, not a hardcoded semantic owner.

- seed source: `LuaScriptingService._defaultScripts()`
- default script name: `default_runtime_template.lua`
- responsibility: recognize text and directly invoke runtime actions from the hook layer

The system contract is now:
- Lua decides what input text means.
- the app exposes callable runtime functions, and Lua hooks invoke them directly.
- Regex is for text repair and display cleanup, not for assigning runtime semantics.

The fallback pseudo-Lua runtime exposes helper functions like:
- `pwf.gsub(text, pattern, replacement)`
- `pwf.replace(text, from, to)`
- `pwf.call(functionName, payload)`
- `pwf.emit(text, functionName, payload)`
- `pwf.dispatch(text, pattern, functionName, payloadTemplate)`
- `pwf.dispatchKeep(text, pattern, functionName, payloadTemplate)`

Helper `pattern` inputs in fallback mode use Dart `RegExp` semantics, not Lua pattern semantics.

Those helpers let the default template support legacy XML-like strings while directly firing runtime actions and remaining fully user-editable.

### Diagnostics model and visibility

Lua diagnostics now use two reason-coded streams:

- `lua.exec` for hook-stage execution reports (native/fallback stage, elapsed time, high-level reason)
- `lua.diag` for warnings/errors and guardrail events with bounded context

Where diagnostics are visible today:
- runtime emits them into `LuaScriptingService.logs`
- QA asserts them in `test/qa/lua_native_fallback_contract_test.dart`, `test/qa/lua_scripting_diagnostics_test.dart`, and `test/qa/pseudolua_regex_guard_test.dart`
- the Regex/Lua management screen shows a compact Lua diagnostics summary above the raw log list in `lib/screens/regex_lua_management_screen.dart`

High-level reason code groups:
- native-stage outcomes: `native_success`, `native_no_result`, `native_unavailable`, `native_exception`
- fallback-stage outcomes: `fallback_success`, `fallback_exception`
- fallback authoring warnings: `pseudo_missing_hook_body`, `pseudo_unsupported_*`, `pseudo_risky_multiline_helper`
- fallback guardrails: `pseudo_regex_guard_*` and `pseudo_runtime_guard_action_cap`

These codes are contract-level diagnostics labels. Extensions should key tests and triage logic to these stable reason classes, not to ad-hoc log wording.

### Guardrails in the fallback engine

Fallback helper execution is bounded to prevent runaway patterns/actions:

- input size cap before helper regex work
- match cap per helper invocation
- per-hook runtime action cap
- soft runtime limit for helper-heavy paths

When a guard trips, fallback keeps processing deterministically where possible and emits reason-coded diagnostics instead of hanging.

### Shared help ownership (single source)

Fallback help text is owned by `lib/features/lua/lua_help_contract.dart`.

Consumers must read from that source, not duplicate fallback wording:
- `/help` summary in `lib/services/command_parser.dart`
- prompt-preview Lua help in `lib/widgets/prompt_preview_dialog.dart`
- default prompt template hints in `lib/models/settings.dart`

If fallback rules/helpers/examples change, update the shared help contract and all contract tests in the same change to prevent drift.

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
- if false:
  - Lua `onAssistantMessage`
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

After assistant output cleanup/direct Lua dispatch:

- if true:
  - regex `displayOnly`
  - Lua `onDisplayRender`
- if false:
  - Lua `onDisplayRender`
  - regex `displayOnly`

## Where These Transforms Run

### Chat flow

Owned by `ChatProvider` plus `ApiService`.

CBS is applied in `ChatProvider` on user input, prompt-build text, and assistant output before the existing regex/Lua cleanup stages continue.

### Notification reply flow

Owned by `NotificationCoordinator` plus `ApiService`.

CBS runs here too, but against the `menu` variable scope so notification-side state stays isolated from the main chat scope.

### Agent mode flow

Agent mode is special.

It uses:
- regex rules embedded inside `AgentPromptPreset`
- optional shared Lua assistant/display hooks
- additional parsing for `notify(...)` and `end()` actions

This means agent mode is not a simple reuse of the normal prompt block transform stack.

## Default Regex Behavior

The shipped default regex set is intentionally small.

- it hides or repairs residual control text when needed
- it trims blank lines left after direct dispatch removes control strings
- it may be extended by the user to repair malformed model output before Lua parses it

Default regex no longer assigns meaning to `<live2d>`, `<overlay>`, or inline command syntax.

## Choosing The Right Layer

### Use regex when

- you need stable residual control-text cleanup
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
- shared help contract (`lib/features/lua/lua_help_contract.dart`) and any consuming help surfaces
- QA coverage for diagnostics/contract drift
- docs

Lua authoring contract changes are incomplete unless runtime, shared help, and tests are updated together.

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
- Interaction tab and CBS execution details -> `docs/FEATURES/INTERACTIONS_AND_CBS.md`
- Live2D directives after transform stages -> `docs/FEATURES/LIVE2D_RUNTIME.md`
- Notification and agent-specific flows -> `docs/FEATURES/NOTIFICATIONS.md`

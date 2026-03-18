# Transforms: Regex And Lua

This document explains how text transforms work before and after LLM calls, where regex and Lua are applied, and how to decide which layer should own a new behavior.

CBS now sits beside these transforms as a session-aware syntax renderer. It is not stored inside regex or Lua, but it must respect the same caller boundaries.

## Owned Code Paths

- `lib/features/regex/models/regex_rule.dart`
- `lib/features/regex/services/regex_pipeline_service.dart`
- `lib/features/lua/models/lua_script.dart`
- `lib/features/lua/runtime/real_lua_runtime.dart`
- `lib/features/lua/runtime/flutter_embed_lua_runtime.dart`
- `lib/features/lua/runtime/lua_host_api.dart`
- `lib/features/lua/runtime/directive_lua_host_api.dart`
- `lib/features/lua/services/lua_native_bridge.dart`
- `lib/features/lua/services/lua_scripting_service.dart`
- `lib/features/lua/lua_help_contract.dart`
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
- runtime metadata:
  - `schemaVersion`
  - `runtimeMode` (`legacyCompatible` or `realRuntimeNative`)

### Hook names

- `onLoad`
- `onUnload`
- `onUserMessage`
- `onAssistantMessage`
- `onPromptBuild`
- `onDisplayRender`

### Execution strategy

`LuaScriptingService` now routes each script through a staged compatibility pipeline.

For each enabled hook invocation:
- if `LuaScript.runtimeMode == realRuntimeNative`, or the script still carries a real-Lua opt-in marker (`-- pwf:runtime=real-lua` or `-- pocketwaifu:runtime=real-lua`), it tries `RealLuaRuntime` first
- the shipped engine is `FlutterEmbedLuaRuntime`
- the shipped host-action boundary is the typed `LuaHostApi`
- the shipped adapter is `DirectiveLuaHostApi`, which maps typed `overlay.*` and `live2d.*` actions back into the existing directive services

If the real runtime is not selected, returns no result, is unavailable, or errors:
- `LuaScriptingService` continues through the legacy `LuaNativeBridge`
- if that path also fails or returns no value, it falls back to the pseudo-Lua comment/helper interpreter

### Current migration stage

- new installs seed `default_runtime_template.lua` with `runtimeMode=realRuntimeNative`
- `/help`, prompt-preview Lua help, and shipped prompt template hints are now real-runtime-first
- older persisted scripts still load as `legacyCompatible` unless stored metadata or an opt-in marker migrates them
- fallback helper semantics are still required for older scripts and compatibility coverage
- the typed host API already reserves additional domains such as screenshot, session, interaction, and API calls, but `DirectiveLuaHostApi` does not execute those domains yet

### Shipped default Lua template

The shipped default script is now the real-runtime-first editable template.

- seed source: `LuaScriptingService._defaultScripts()`
- default script name: `default_runtime_template.lua`
- default runtime mode: `LuaScriptRuntimeMode.realRuntimeNative`
- responsibility: parse assistant text with normal Lua string/pattern code and invoke explicit host functions such as `overlay.move(...)` and `live2d.motion(...)`

The system contract is now:
- Lua decides what input text means.
- the app exposes callable host functions, and Lua hooks invoke them directly.
- Regex is for text repair and display cleanup, not for assigning runtime semantics.

The template still recognizes legacy XML-like blocks and inline shorthand, but it translates them inside Lua instead of relying on hidden system parsing.

### Legacy compatibility path

Older scripts may still run through the legacy native bridge plus pseudo-Lua helpers.

The fallback pseudo-Lua runtime exposes helper functions like:
- `pwf.gsub(text, pattern, replacement)`
- `pwf.replace(text, from, to)`
- `pwf.call(functionName, payload)`
- `pwf.emit(text, functionName, payload)`
- `pwf.dispatch(text, pattern, functionName, payloadTemplate)`
- `pwf.dispatchKeep(text, pattern, functionName, payloadTemplate)`

Helper `pattern` inputs in fallback mode use Dart `RegExp` semantics, not Lua pattern semantics.

That path exists for migration and older stored scripts. It is no longer the default authoring target for new scripts.

### Diagnostics model and visibility

Lua diagnostics now use two reason-coded streams:

- `lua.exec` for hook-stage execution reports (real-runtime/native/fallback stage, elapsed time, high-level reason)
- `lua.diag` for warnings/errors and guardrail events with bounded context

Where diagnostics are visible today:
- runtime emits them into `LuaScriptingService.logs`
- QA asserts them in `test/qa/lua_native_fallback_contract_test.dart`, `test/qa/lua_scripting_diagnostics_test.dart`, and `test/qa/pseudolua_regex_guard_test.dart`
- the Regex/Lua management screen shows a compact Lua diagnostics summary above the raw log list in `lib/screens/regex_lua_management_screen.dart`

High-level reason code groups:
- real-runtime-stage outcomes: `real_runtime_success`, `real_runtime_no_result`, `real_runtime_unavailable`, `real_runtime_not_initialized`, `real_runtime_error`
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

Real-runtime-first Lua help text is owned by `lib/features/lua/lua_help_contract.dart`.

Consumers must read from that source, not duplicate Lua wording:
- `/help` summary in `lib/services/command_parser.dart`
- prompt-preview Lua help in `lib/widgets/prompt_preview_dialog.dart`
- default prompt template hints in `lib/models/settings.dart`

If host functions, runtime rules, working examples, or legacy migration notes change, update the shared help contract and all contract tests in the same change to prevent drift.

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
- you want explicit host-function calls from Lua into runtime features
- you need a user-editable programmable stage
- you want to map arbitrary text formats to runtime functions
- you need to keep older scripts working while migrating toward the real runtime path

### Use prompt blocks instead when

- the behavior is structural prompt composition, not text post-processing

## Extension Guidance

### Add a new regex phase

This is a structural change. It affects all callers and should only happen if the current four-phase model is no longer sufficient.

### Add a new Lua hook

Update:
- `LuaScriptingService`
- `lib/features/lua/runtime/real_lua_runtime.dart` hook mapping and `FlutterEmbedLuaRuntime` invocation if real-runtime scripts must see the new hook
- `LuaHostApi` / `DirectiveLuaHostApi` if the new hook needs new host calls or domains
- shared help contract (`lib/features/lua/lua_help_contract.dart`) and any consuming help surfaces
- QA coverage for diagnostics/contract drift
- docs

If the change must preserve older scripts, keep legacy compatibility behavior and diagnostics reason codes accurate too.

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
- Implementing a cleanup rule in regex when it should actually be a directive parser or explicit Lua host call.
- Assuming all stored scripts already run in the real runtime; older scripts can still stay `legacyCompatible`.
- Assuming every typed host domain is executable today; the shipped adapter only handles overlay/live2d.
- Changing transform order without checking both chat and notification flows.

## Cross-Links

- Base request flow -> `docs/FEATURES/LLM_AND_PROMPTS.md`
- Interaction tab and CBS execution details -> `docs/FEATURES/INTERACTIONS_AND_CBS.md`
- Live2D directives after transform stages -> `docs/FEATURES/LIVE2D_RUNTIME.md`
- Notification and agent-specific flows -> `docs/FEATURES/NOTIFICATIONS.md`

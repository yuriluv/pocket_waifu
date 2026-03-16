# Interactions And CBS

This document covers the right-side interaction tab, session-scoped chat variables, the board HTML/CSS runtime, and CBS execution timing.

## Owned Code Paths

- UI shell and board surface
  - `lib/screens/chat_screen.dart`
  - `lib/widgets/interaction_drawer.dart`
- Session-scoped state and presets
  - `lib/models/chat_session.dart`
  - `lib/models/chat_variable_scope.dart`
  - `lib/models/session_variable_store.dart`
  - `lib/models/session_interaction_state.dart`
  - `lib/models/interaction_preset.dart`
  - `lib/providers/chat_session_provider.dart`
  - `lib/providers/interaction_preset_provider.dart`
- CBS parsing and execution
  - `lib/features/cbs/services/cbs_service.dart`
  - `lib/providers/chat_provider.dart`
  - `lib/services/notification_coordinator.dart`
  - `lib/screens/prompt_preview_screen.dart`

## Feature Shape

The interaction system is one feature with four layers:

1. Session-scoped chat variables are the data layer.
2. CBS is the syntax and execution layer for reading and mutating those variables.
3. The right-side interaction tab is the user-facing management surface.
4. The board HTML/CSS runtime is the rendering layer scoped to the interaction panel only.

## UI Structure

`ChatScreen` now owns two panel surfaces:

- left `drawer`
  - the existing menu and settings surface.
- right `endDrawer`
  - the interaction tab.

The interaction tab opens from the top-right app bar button and uses the same focus-preservation pattern as the left drawer.

Inside the interaction tab:

- board view
  - white board surface only.
  - user HTML/CSS is rendered here, not in the rest of the Flutter UI.
- settings view
  - chat variable editor
  - CSS editor
  - HTML editor
  - preset management

## Storage Units

### Session-scoped chat variables

Owned by `ChatSession.variableStore`.

Each chat session stores three separate scopes:

- `mainChat`
  - normal chat screen request/response flow.
- `menu`
  - mini-menu, notification reply, proactive, and agent-driven flows.
- `newChat`
  - first-message / new-session bootstrap context.

Variables and aliases are serialized inside the session metadata payload, so switching sessions never shares variable state.

### Interaction tab state

Owned by `ChatSession.interactionState`.

Per session it stores:

- current custom HTML
- current custom CSS
- currently applied preset id

This means two sessions can render different boards even if they use the same global preset library.

### HTML/CSS presets

Owned by `InteractionPresetProvider` and persisted separately from sessions.

Presets are reusable library entries containing:

- preset name
- HTML
- CSS

Sessions only store the applied preset id plus their current live HTML/CSS state.

## Board Runtime And Containment

`interaction_drawer.dart` uses `webview_flutter` to host a panel-local board runtime.

Containment rules:

- HTML/CSS is loaded through `loadHtmlString(...)` into the board WebView only.
- external navigation is blocked through `NavigationDelegate`.
- generated board HTML includes a restrictive CSP so inline board logic works but network access is denied by default.
- the Flutter app tree outside the board is not styled by user CSS.
- variable reads/writes are exposed through a narrow JavaScript bridge (`window.pocketWaifu`).

## CBS Execution Timing

CBS is executed as a text transform layered into existing callers instead of creating a separate request stack.

### Main chat

Owned by `ChatProvider`.

- user input path
  - CBS runs first on the raw user text.
  - regex/Lua still run afterward using the existing order toggle.
- prompt build path
  - CBS runs on the fully assembled prompt text before API submission.
- assistant output path
  - CBS runs before the existing assistant regex/Lua/display cleanup stages.

### Prompt preview

Prompt preview renders CBS for visibility, but it runs in a no-mutation mode so previewing `setvar`/`addvar` expressions does not change real session state.

### Notification and mini-menu

Owned by `NotificationCoordinator`.

The same three CBS stages are reused, but they operate on the `menu` variable scope so that notification-side automation never leaks into `mainChat` variables.

### New-chat bootstrap

Owned by `ChatProvider.initializeChat(...)`.

The character first message is CBS-rendered against the `newChat` scope before it is inserted into a fresh session.

## Supported CBS Behavior

Implementation is based on `/home/ubuntu/userfolder/cbs.md` and currently includes:

- nested inline `{{...}}` expressions
- variable reads/writes such as `getvar`, `setvar`, `addvar`, `gettempvar`, `settempvar`
- conditionals through `{{#when ...}} ... {{:else}} ... {{/when}}`
- array iteration through `{{#each ... slot}} ... {{/each}}`
- math helpers and `{{? ...}}` expressions
- time/date helpers
- string helpers
- array and dictionary helpers
- utility helpers such as `slot`, `random`, `pick`, `roll`, `replace`, `range`, `length`, `br`, and `none`

## Session Isolation Guarantees

- `ChatSessionProvider` remains the canonical owner of session-scoped interaction state.
- variable writes for notification and background-like entrypoints still happen inside `runSerialized(...)` critical sections.
- deleting a session removes its messages and its interaction-variable state because both live under the same session object.

## Cross-Links

- Shared provider and persistence ownership -> `docs/SYSTEM_ARCHITECTURE.md`
- Prompt stack and preview -> `docs/FEATURES/LLM_AND_PROMPTS.md`
- Regex/Lua ordering -> `docs/FEATURES/TRANSFORMS.md`
- Notification and mini-menu callers -> `docs/FEATURES/NOTIFICATIONS.md`

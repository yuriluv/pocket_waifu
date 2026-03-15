# LLM And Prompts

This document covers the base model call pipeline, prompt blocks, prompt preview, prompt presets, agent prompt presets, and API presets.

## Owned Code Paths

- `lib/screens/chat_screen.dart`
- `lib/providers/chat_provider.dart`
- `lib/providers/chat_session_provider.dart`
- `lib/providers/prompt_block_provider.dart`
- `lib/providers/prompt_preset_provider.dart`
- `lib/providers/agent_prompt_preset_provider.dart`
- `lib/services/prompt_builder.dart`
- `lib/services/api_service.dart`
- `lib/models/api_config.dart`
- `lib/models/oauth_account.dart`
- `lib/providers/settings_provider.dart`
- `lib/services/oauth_account_service.dart`
- `lib/screens/prompt_editor_screen.dart`
- `lib/screens/prompt_preview_screen.dart`
- `lib/screens/settings_screen.dart`
- `lib/screens/live2d_llm_settings_screen.dart`
- `lib/services/notification_coordinator.dart`
- `lib/services/agent_mode_service.dart`

## Base LLM Call Flow

There are three major callers:
- normal chat UI
- notification reply/proactive flow
- agent mode loop

They reuse the same building blocks but have different entrypoints.

### Normal chat path

1. `ChatScreen` collects user text and optional image attachments.
2. `ChatProvider.sendMessage` resolves the active session and current API preset from `SettingsProvider`.
3. User input is preprocessed by regex and Lua using the current `runRegexBeforeLua` setting.
4. The prepared user message is appended to `ChatSessionProvider`.
5. `ChatProvider._requestAssistantResponse` resolves prompt blocks from `PromptBlockProvider`.
6. `PromptBuilder` converts blocks + history + current input into API-ready message payloads.
7. `ApiService` transforms prompt text again through the prompt lifecycle hooks:
   - regex `promptInjection`
   - Lua `onPromptBuild`
8. `ApiService` formats and sends the request using the active `ApiConfig`.
9. Assistant output comes back to `ChatProvider` and enters the assistant post-processing pipeline:
    - regex/Lua on assistant text
    - directive parsing through the editable default Lua ownership script
    - display-only regex/Lua cleanup
10. Final assistant text is stored in `ChatSessionProvider`.

### Notification-originated path

1. Android or mini-menu action arrives in Flutter.
2. `NotificationCoordinator` becomes the caller instead of `ChatProvider`.
3. The same prompt block / API preset / regex / Lua / directive pipeline is reused.
4. The final assistant output is both stored in session history and sent back to Android as a notification result.

### Agent-mode path

1. `AgentModeService` starts a periodic loop.
2. It resolves an `AgentPromptPreset`, not a normal prompt block preset.
3. `NotificationCoordinator.triggerAgentModeLoop` builds a direct message list:
   - system prompt from the agent preset
   - recent chat context
   - a generated trigger prompt containing the reply prompt and loop history
4. `ApiService` sends the request.
5. The output is parsed by agent-specific regex rules and optional Lua action parsing.
6. If the output resolves to `notify("...")`, a notification is sent. If it resolves to `end()`, the loop stops.

## Prompt Blocks

Prompt blocks are the canonical prompt authoring system.

### Block types

- `prompt`
  - Static authored prompt text.
- `pastMemory`
  - Conversation history rendered into XML-like tags.
- `input`
  - Current user input placeholder.

### Ownership

`PromptBlockProvider` owns:
- preset list
- active preset id
- working blocks for the currently edited preset
- legacy block migration logic

### Important behavior

- Blocks are sorted by `order`.
- Only active blocks contribute to the final prompt.
- `pastMemory` omits system messages and can include image attachment metadata.
- `input` is skipped for proactive responses when `skipInputBlock` is true.

### Why this matters

- Chat replies, notification replies, and proactive responses all depend on the exact same prompt block semantics.
- If prompt block behavior changes, the impact is wider than the chat UI.

## Prompt Builder

`PromptBuilder` is intentionally simple.

It does not own persistence or UI state. It only knows how to:
- render blocks into one final prompt string
- convert prompt strings into API message payloads
- render multimodal content parts for images

### Practical implication

If you need a new prompt authoring concept, add it to `PromptBlockProvider` and `PromptBuilder` together. Do not hardcode ad hoc prompt assembly in screens or coordinators.

## Prompt Preview

There are two similarly named files with different roles.

### Real prompt preview

- `lib/screens/prompt_preview_screen.dart`

This screen:
- lets the user choose a prompt preset
- uses current session messages from `ChatProvider`
- lets the user type a hypothetical current input
- renders the final prompt exactly as the block system would assemble it

### Not the real prompt preview

- `lib/widgets/prompt_preview_dialog.dart`

This file is a help page for chat commands, Lua hooks, and regex syntax. Keep this distinction in mind when tracing "prompt preview" behavior.

## Prompt Presets

### Standard prompt presets

Owned by `PromptBlockProvider`.

Capabilities:
- active preset switching
- add, rename, delete, duplicate
- import/export JSON
- legacy block migration

Consumers:
- chat requests
- notification reply requests
- proactive responses
- preview UI
- notification and proactive settings store preset ids through `PromptPresetProvider`

### `PromptPresetProvider`

This provider does not own prompt content.

It only exposes stable `PromptPresetReference` values so that other systems can store preset ids without taking a direct dependency on the full editable block model.

## Agent Prompt Presets

Agent mode uses a separate preset model on purpose.

Owned by `AgentPromptPresetProvider`.

An `AgentPromptPreset` includes:
- a system prompt
- a reply prompt
- agent-specific regex rules
- an agent-side Lua script template used to parse `notify(...)` or `end()` style outputs

Why it is separate:
- agent mode is a bounded observe-reason-act loop, not a normal roleplay reply flow
- it needs action parsing semantics, not just a static block-based system prompt

## API Presets

### Ownership

`SettingsProvider` is the canonical owner of all `ApiConfig` values.

`OAuthAccountService` is the canonical owner of OAuth token exchange, refresh, and secure persistence.

Current provider constraint:
- Codex OAuth uses a built-in public client flow.
- Gemini CLI / GCA OAuth uses user-supplied Google OAuth desktop client credentials rather than shipping Google client credentials inside the app.
- Codex OAuth login mirrors the official Codex CLI authorize contract, including `originator=codex_cli_rs` and the connector scopes used by the first-party client.

`ApiConfig` stores:
- display name
- base URL
- API key
- optional linked OAuth account id
- model name
- custom headers
- preset-owned generation params and extra params
- provider-specific behavior flags such as:
  - `hasFirstSystemPrompt`
  - `requiresAlternateRole`
  - `mergeSystemPrompts`
  - `mustStartWithUserInput`
  - `useMaxOutputTokens`
  - `supportsVision`

### Resolution model

- Main chat path uses `SettingsProvider.activeApiConfig`.
- Notification, proactive, and agent flows can optionally resolve a specific preset id through `resolveApiConfigByPreset(...)`.
- If a stored preset id becomes invalid, `NotificationSettingsProvider` rebinding methods fall back to the first valid preset.
- If a preset references an OAuth account, `ApiService` asks `OAuthAccountService` for a valid bearer token before sending the request.

### Preset editor flow

- API presets are now created and edited in a dedicated fullscreen editor rather than a popup dialog.
- The old global parameter-tab workflow is intentionally collapsed into the preset editor, so each preset owns its own generation params.
- The API settings screen keeps OAuth account management separate from preset editing, but preset editing can launch OAuth account login when needed.

### Sending model requests

`ApiService` owns provider-specific request formatting.

It currently supports:
- OpenAI-compatible request bodies
- OpenAI Responses-style request bodies for Codex OAuth / ChatGPT-backed Codex access
- Anthropic request bodies
- Google Code Assist request bodies for Gemini CLI / GCA OAuth access
- legacy compatibility for older provider settings

Important behavior:
- Codex OAuth request bodies move all `system` messages into top-level `instructions`, send non-system turns through `input`, force `store=false`, and force `stream=true`; Codex requests also send Codex-specific headers such as `originator`, `OpenAI-Beta`, and `ChatGPT-Account-Id` when available.
- common generation params are stored per preset in `ApiConfig.additionalParams`; legacy global values are migrated one time into presets for older installs
- Codex presets hide unsupported generation controls and surface a guidance card instead of exposing values like `temperature`, `top_p`, or `max_output_tokens`
- token parameter naming is provider-sensitive and can fall back on retry
- multimodal images are converted to content parts when supported

## Live2D Prompt Capability Preview

`lib/screens/live2d_llm_settings_screen.dart` does not own prompt delivery.

It owns a preview of model runtime capability injection by reading:
- current motion groups
- expressions
- parameter ids
- current runtime parameter values

This preview helps users understand what the model-specific system prompt injection will look like, but the actual request still flows through `PromptBlockProvider` and `ApiService`.

## Extension Guidance

### Add a new prompt block behavior

Edit:
- `lib/models/prompt_block.dart`
- `lib/providers/prompt_block_provider.dart`
- `lib/services/prompt_builder.dart`
- relevant UI in `lib/screens/prompt_editor_screen.dart`
- preview behavior in `lib/screens/prompt_preview_screen.dart`

### Add a new API provider format

Edit:
- `lib/models/api_config.dart`
- `lib/services/api_service.dart`
- `lib/services/oauth_account_service.dart` if the provider uses OAuth instead of raw API keys
- `lib/screens/settings_screen.dart`
- any preset resolution docs if flags or payload contracts change

### Add a new LLM caller

Prefer reusing:
- `PromptBlockProvider`
- `PromptBuilder`
- `ApiService`
- the existing regex/Lua/directive post-processing pipeline

Do not create a parallel prompt stack unless the behavior is intentionally different, as agent mode already is.

## Common Failure Modes

- Confusing `prompt_preview_dialog.dart` with the real prompt preview surface.
- Forgetting that notification/proactive flows use prompt presets too.
- Changing prompt block rendering without checking proactive `skipInputBlock` behavior.
- Adding preset ids without rebinding fallback behavior.
- Treating API preset flags as cosmetic when they are transport-format contracts.

## Cross-Links

- System ownership and channels -> `docs/SYSTEM_ARCHITECTURE.md`
- Regex and Lua ordering -> `docs/FEATURES/TRANSFORMS.md`
- Live2D runtime metadata and directives -> `docs/FEATURES/LIVE2D_RUNTIME.md`
- Notification/proactive/agent callers -> `docs/FEATURES/NOTIFICATIONS.md`

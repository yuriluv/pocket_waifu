# NotificationCoordinator

## Overview
`NotificationCoordinator` is the central orchestration layer for notification-driven actions.
It handles three request origins (`reply`, `proactive`, `agent`) and bridges UI/native actions to
chat session mutation, API calls, and post-processing (regex/lua/live2d directives).

## Internal Structure
- **Action intake**: `_handleAction()` consumes native action events (`reply`, `menu`, `touchThrough`, `cancelReply`).
- **Reply flow**: `_handleNotificationReplyInternal()` serializes user message handling and assistant response rendering.
- **Proactive flow**: `triggerProactiveResponse()` executes proactive generation with request origin tracking.
- **Agent loop flow**: `triggerAgentModeLoop()` runs bounded iterative observe-reason-act style loops.
- **Request lifecycle**: `_bindActiveRequest()` and `_unbindActiveRequest()` manage in-flight cancellation state.

## Cross-Feature Links
- **Notification bridge**: `lib/services/notification_bridge.dart`
- **Chat serialization**: `lib/providers/chat_session_provider.dart`
- **Prompt composition**: `lib/providers/prompt_block_provider.dart`, `lib/services/prompt_builder.dart`
- **Proactive automation**: `lib/services/proactive_response_service.dart`
- **Agent automation**: `lib/services/agent_mode_service.dart`
- **Live2D/Lua/Regex processing**: `lib/features/live2d_llm/services/live2d_directive_service.dart`,
  `lib/features/lua/services/lua_scripting_service.dart`, `lib/features/regex/services/regex_pipeline_service.dart`

## Known Risks
- This file is a high-coupling hotspot; avoid broad rewrites in a single change.
- Cancellation semantics are sensitive; preserve request origin checks when modifying.
- Changes to action type strings must stay compatible with Android native receivers.

## Change Checklist
1. Keep request origin and cancellation behavior consistent.
2. Preserve `runSerialized` boundaries for chat session writes.
3. Validate proactive/agent/reply flows all still route correctly.
4. Update related feature docs if request orchestration behavior changes.

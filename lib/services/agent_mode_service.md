# AgentModeService

## Overview
`AgentModeService` runs periodic agent-mode loops that can autonomously evaluate context and
emit notifications using selected prompt/API presets.

## Internal Structure
- **Attach and listeners**: `attach()` binds settings, preset provider, chat session changes, and user-reply hooks.
- **Session-aware cancellation**: `_handleChatSessionChanged()` cancels in-flight loops when a new user message appears.
- **Scheduler gate**: `_maybeStart()` starts/stops periodic timer based on mode + runtime settings.
- **Loop trigger**: `_trigger()` resolves session/preset/config and calls `NotificationCoordinator.triggerAgentModeLoop()`.

## Cross-Feature Links
- **Request execution**: `lib/services/notification_coordinator.dart`
- **Agent presets**: `lib/providers/agent_prompt_preset_provider.dart`, `lib/models/agent_prompt_preset.dart`
- **Notification and mode settings**: `lib/providers/notification_settings_provider.dart`
- **Global runtime**: `lib/providers/global_runtime_provider.dart`

## Known Risks
- Agent-mode intervals and max iterations can increase request load quickly.
- Session-change cancellation is state-sensitive; keep message signature logic stable.
- API preset fallback behavior must remain aligned with proactive/reply flows.

## Change Checklist
1. Preserve timer start/stop conditions and interval clamping.
2. Keep user-reply and session-change cancellation semantics.
3. Verify preset loading flow (`ensureLoaded`) remains non-blocking for periodic triggers.
4. Validate no conflict regression with proactive in-flight behavior.

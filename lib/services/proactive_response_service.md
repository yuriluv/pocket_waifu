# ProactiveResponseService

## Overview
`ProactiveResponseService` schedules and triggers proactive assistant responses based on
runtime environment and user-defined schedule settings.

## Internal Structure
- **Attach and lifecycle**: `attach()` wires providers/listeners and registers global runtime listener.
- **Environment sync**: `updateEnvironment()` updates overlay/orientation/screen-off state and timer recalculation.
- **Scheduler gate**: `_maybeStart()` decides whether proactive automation should run.
- **Trigger execution**: `_trigger()` calls `NotificationCoordinator.triggerProactiveResponse()`.
- **Debug telemetry**: `debugSnapshot` and `debugLogs` provide real-time timer state + event history.

## Cross-Feature Links
- **Timer engine**: `lib/services/pre_response_timer.dart`
- **Proactive schedule parsing**: `lib/services/proactive_config_parser.dart`
- **Settings source**: `lib/providers/notification_settings_provider.dart`
- **Global runtime gating**: `lib/providers/global_runtime_provider.dart`, `lib/services/global_runtime_registry.dart`
- **Notification request execution**: `lib/services/notification_coordinator.dart`
- **Debug UI**: `lib/screens/proactive_debug_screen.dart`

## Known Risks
- Schedule parsing failures can silently stop proactive execution if not surfaced in UI/logs.
- Environment updates (screen off/on) affect timer pause/resume behavior; test both transitions.
- Any change to trigger conditions can impact battery usage and notification frequency.

## Change Checklist
1. Preserve start/stop guard semantics (`notificationsEnabled`, `proactiveEnabled`, `globalEnabled`).
2. Keep user-reply cancellation behavior intact.
3. Verify debug snapshot/log fields stay consistent with UI consumers.
4. Re-check timer fallback behavior for invalid/legacy schedules.

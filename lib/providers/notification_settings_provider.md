# NotificationSettingsProvider

## Overview
`NotificationSettingsProvider` is the persistence and state hub for notification-related settings:
base notification toggles, proactive settings, and agent-mode settings.

## Internal Structure
- **Storage load/save**: `_load()` and `_save()` synchronize settings with `SharedPreferences`.
- **Notification settings API**: `setNotificationsEnabled()`, preset selection, output mode.
- **Proactive settings API**: proactive enable toggle, schedule update/validation, proactive presets.
- **Agent-mode settings API**: mode enable toggle, presets, interval/max-iteration/timeout values.
- **Rebinding utilities**: `rebindPromptPresets()`, `rebindAgentPromptPresets()`, `rebindApiPresets()`.

## Cross-Feature Links
- **Notification coordinator**: `lib/services/notification_coordinator.dart`
- **Proactive automation**: `lib/services/proactive_response_service.dart`
- **Agent automation**: `lib/services/agent_mode_service.dart`
- **Settings UI**: `lib/screens/notification_settings_screen.dart`, `lib/screens/agent_mode_settings_screen.dart`

## Known Risks
- Storage key changes break backward compatibility; avoid renaming keys without migration.
- Rebinding logic affects multiple features; validate notification/proactive/agent preset integrity together.
- Async permission path (`setNotificationsEnabled`) has different semantics from sync setters; preserve behavior.

## Change Checklist
1. Keep storage key compatibility and load defaults stable.
2. Preserve notify/save semantics for sync vs async update methods.
3. Ensure rebind methods do not introduce accidental preset resets.
4. Re-test all three consumers: notification, proactive, and agent-mode services.

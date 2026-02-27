# Newcastle Requirement Verification (Codebase Traceability)

Date: 2026-02-27
Scope source: `docs/Newcastle.md`
Repository: `pocket_waifu`

## Verification Summary Checklist

- [ ] Global On/Off toggle with modular listener registration and full cancellation/cleanup behavior
- [ ] Character Name control at top of menu with editor flow
- [~] Prompt block generalization/persistence/import-export/migration (partially implemented, currently inconsistent)
- [~] Prompt preset data layer (partially implemented), editor + preview preset selectors and full UX rules
- [ ] Notification settings menu and notification-specific prompt/API preset binding
- [~] Persistent foreground notification exists for Live2D overlay only (not Newcastle chat/proactive notification feature)
- [ ] Notification reply UX (inline reply, cancel, touch-through button, loading/error states)
- [ ] Notification-AI chat integration with shared main session and serialized concurrent access
- [ ] Proactive response settings/grammar/priority/timer/cancellation and notification delivery
- [~] Android permission declarations exist (`POST_NOTIFICATIONS`, `FOREGROUND_SERVICE`, `SYSTEM_ALERT_WINDOW`); runtime flow is partial and not tied to notification settings feature

## Traceability Matrix

| Requirement Area (Newcastle) | Status | Evidence in Codebase | Notes |
|---|---|---|---|
| Global On/Off at top of menu, persisted, modular feature registration | Missing | `lib/screens/menu_drawer.dart:25-185` | No global app master toggle, no feature registration contract, no global cancellation orchestration. |
| Off-state must cancel in-flight API calls, clear pending notifications, stop proactive timers | Missing | `lib/providers/chat_provider.dart:63-144`, `lib/services/api_service.dart:25-149` | No cancellation tokens/abort path for active HTTP call; no proactive timer subsystem; no notification queue clear path for chat feature. |
| Character Name setting at top of menu, edit on tap | Missing/Partial | `lib/providers/settings_provider.dart:259-261`, `lib/models/character.dart:5-93`, `lib/screens/menu_drawer.dart:25-185` | Character model and setter exist, but no top-of-menu Character Name editor entry in drawer. |
| Prompt block JSON types (`prompt`, `pastmemory`, `input`) + multiplicity/order + inactive exclusion | Partial | `lib/models/prompt_block.dart:8-106`, `lib/models/prompt_preset.dart:57-92` | New block schema supports required types and `isActive`. |
| Pastmemory range validation and XML header behavior | Missing/Incorrect | `lib/models/prompt_block.dart:124-133`, `lib/services/prompt_builder.dart:54-100` | Builder uses legacy fields and hardcoded tag format (`<user chat n>`), not `userHeader/charHeader` behavior from Newcastle. |
| Prompt block reordering/removal/addition UI | Partial | `lib/screens/prompt_editor_screen.dart:72-91`, `lib/providers/prompt_block_provider.dart:145-159` | Reorder UI exists, but provider/screen rely on legacy model API not matching current `PromptBlock` type (build-risk). |
| Prompt preview equals final compiled API payload; uses active session real history | Partial/Incorrect | `lib/widgets/prompt_preview_dialog.dart:151-191` | Uses real chat messages, but preview logic uses legacy block types (`past_memory`, `user_input`) and not finalized payload compiler behavior. |
| Prompt preset CRUD + keep at least one preset + rename + default preset | Partial | `lib/providers/prompt_preset_provider.dart:202-226`, `lib/models/prompt_preset.dart:95-115` | Data-layer supports add/update/delete guard/rename/default. |
| Preset switch warning for unsaved changes, delete confirmation, reassignment for notification/proactive references | Missing/Partial | `lib/providers/prompt_preset_provider.dart:202-214` | Provider has minimum-one guard but no notification/proactive reference rebinding logic found. UI flows for unsaved-change prompt not found. |
| Preset export/import external JSON | Partial (data model only) | `lib/models/prompt_preset.dart:57-80` | Serialization helpers exist; no confirmed file-picker/export UI wiring in inspected screens. |
| Prompt preview top preset selector | Missing | `lib/widgets/prompt_preview_dialog.dart:193-269` | No preset selector UI present. |
| Notification settings section with required toggles and preset selections | Missing | `lib/screens/menu_drawer.dart:63-185`, `lib/screens/settings_screen.dart:34-50` | No dedicated notification settings screen or controls matching Newcastle spec. |
| Persistent notification via foreground service | Partial (Live2D only) | `android/app/src/main/kotlin/com/example/flutter_application_1/live2d/overlay/Live2DOverlayService.kt:1129-1163` | Foreground channel + ongoing notification implemented for overlay service, not Newcastle chat notification feature. |
| Android 13+ notification permission flow tied to notification enablement | Partial | `android/app/src/main/kotlin/com/example/flutter_application_1/MainActivity.kt:51-75` | Permission requested at app startup, not first-enable flow in Notification Settings with settings guidance path. |
| Notification message format (title uses character name, big-text, reply/cancel/touch-through actions) | Missing | `android/app/src/main/kotlin/com/example/flutter_application_1/live2d/overlay/Live2DOverlayService.kt:1145-1162` | Service notification is simple service status only; no remote input actions for chat replies. |
| Notification-AI chat integration and shared session synchronization | Missing | `lib/providers/chat_provider.dart:63-144`, `lib/providers/chat_session_provider.dart` (no notification entrypoints found by search) | No notification reply pipeline writing into active main session. |
| Concurrency serialization for notification reply/in-app/proactive race prevention | Missing | `lib/providers/chat_provider.dart:63-144` | No queue/mutex around chat request entrypoints in Dart layer. |
| Proactive response condition grammar/parser/priority/timers | Missing | `rg` scan showed no `overlayon/overlayoff/screenoff/screenlandscape` implementation outside Newcastle doc | No parser/timer subsystem found for proactive response spec. |
| Required permission declarations | Implemented (manifest-level) | `android/app/src/main/AndroidManifest.xml:10-31` | Includes `POST_NOTIFICATIONS`, `FOREGROUND_SERVICE`, `SYSTEM_ALERT_WINDOW`. |

## Static Validation and Test Evidence

Because the environment lacks Flutter/Dart SDKs, runtime/unit/widget/integration tests could not be executed.

### Environment/tooling checks

```bash
which flutter || true && flutter --version || true
which dart || true && dart --version || true
```

Observed result:
- `flutter`: not found (`/bin/bash: flutter: command not found`)
- `dart`: not found (`/bin/bash: dart: command not found`)

### Fallback static checks executed

```bash
# Requirements and implementation grep traceability
rg -n "global|toggle|characterName|pastmemory|prompt preset|notification|foreground service|POST_NOTIFICATIONS|proactive|screenoff|overlayon|mutex|queue|cancel" lib android docs test pubspec.yaml README.md

# Manifest and core implementation inspection
sed -n '1,240p' android/app/src/main/AndroidManifest.xml
sed -n '1,260p' lib/providers/settings_provider.dart
sed -n '1,340p' lib/providers/prompt_preset_provider.dart
sed -n '1,260p' lib/models/prompt_block.dart
nl -ba android/app/src/main/kotlin/com/example/flutter_application_1/live2d/overlay/Live2DOverlayService.kt | sed -n '1120,1195p'

# Legacy/new prompt-model consistency check
rg -n "isEnabled|isActive|TYPE_USER_INPUT|TYPE_CHARACTER|TYPE_SYSTEM_PROMPT|past_memory|user_input|fromMap\(|toMap\(|systemPrompt\(|character\(|pastMemory\(|userInput\(" \
  lib/services/prompt_builder.dart lib/providers/prompt_block_provider.dart lib/screens/prompt_editor_screen.dart lib/widgets/prompt_preview_dialog.dart lib/models/prompt_block.dart

# Markdown relative-link sanity pass (best-effort shell check)
# (No confirmed broken local doc links requiring edits)
```

### Additional blocker from repo scripts

`scripts/web_smoke_test.sh` requires Flutter (`flutter pub get`, `flutter analyze`, `flutter test`, `flutter build web`) and cannot run until SDK is installed.

## Unresolved Risks

1. Prompt system appears mid-migration and internally inconsistent (`PromptBlock` new API vs provider/screen/builder legacy API usage), which is a high risk for build/runtime breakage.
2. No implemented Newcastle notification/proactive architecture means critical functional scope is still absent.
3. No request-cancellation mechanism for in-flight network calls; cannot satisfy required immediate stop behavior.
4. No verified session serialization around concurrent writers; risk of ordering/race defects if notification/proactive flows are added without coordination primitives.
5. Android notification permission UX does not match requirement trigger semantics (requested on launch instead of feature-enable path).

## Explicit Blockers

1. Flutter SDK missing in current environment (`flutter` command unavailable).
2. Dart SDK missing in current environment (`dart` command unavailable).
3. Therefore, `flutter analyze`, `flutter test`, and runtime validation for Newcastle behavior are blocked.

## Doc Link Fixes Applied

- No confirmed broken local documentation links were found that required modification during this verification pass.


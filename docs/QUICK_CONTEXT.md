# Pocket Waifu Quick Context

Read this first if you have very little context window.

## One-Screen Mental Model

- App bootstrap lives in `lib/main.dart`.
- Main interactive UI lives in `lib/screens/chat_screen.dart`.
- Persistent app state lives in providers under `lib/providers/`.
- Cross-feature orchestration lives in services under `lib/services/`.
- Feature-specific runtime logic lives under `lib/features/`.
- Native Android contracts live under `android/app/src/main/kotlin/com/example/flutter_application_1/`.

## The Fastest Ownership Map

- LLM call path -> `lib/providers/chat_provider.dart`, `lib/services/prompt_builder.dart`, `lib/services/api_service.dart`
- Prompt blocks/presets -> `lib/providers/prompt_block_provider.dart`, `lib/providers/prompt_preset_provider.dart`
- Agent prompts -> `lib/providers/agent_prompt_preset_provider.dart`
- API presets and OAuth accounts -> `lib/providers/settings_provider.dart`, `lib/models/api_config.dart`, `lib/models/oauth_account.dart`, `lib/services/oauth_account_service.dart`
- Notifications/proactive/agent mode -> `lib/services/notification_coordinator.dart`, `lib/services/proactive_response_service.dart`, `lib/services/agent_mode_service.dart`
- Regex/Lua transforms -> `lib/features/regex/services/regex_pipeline_service.dart`, `lib/features/lua/services/lua_scripting_service.dart`
- Live2D runtime -> `lib/features/live2d/`, `lib/features/live2d_llm/`
- Image overlay -> `lib/features/image_overlay/`
- Screenshots -> `lib/services/unified_capture_service.dart`, `lib/services/adb_screen_capture_service.dart`
- Native overlay and mini menu -> `android/app/src/main/kotlin/com/example/flutter_application_1/live2d/overlay/Live2DOverlayService.kt`

## Four Shared Pipelines

1. Chat/UI -> prompt build -> `ApiService` -> transforms/directives -> session write
2. Notification/proactive/agent -> `NotificationCoordinator` -> same LLM pipeline -> notification/native sync
3. Live2D/image overlay -> shared bridge -> shared Android overlay service
4. Screenshot capture -> shared `ImageAttachment` output -> same multimodal message path as normal images

## Read Next Based On Task

- Low-context general map -> `docs/START_HERE.md`
- Provider graph, lifecycle, channels, permissions -> `docs/SYSTEM_ARCHITECTURE.md`
- Prompts and model calls -> `docs/FEATURES/LLM_AND_PROMPTS.md`
- Live2D/image overlay behavior -> `docs/FEATURES/OVERLAYS.md`
- Model parsing, parameters, auto motion -> `docs/FEATURES/LIVE2D_RUNTIME.md`
- Regex/Lua -> `docs/FEATURES/TRANSFORMS.md`
- Notifications/proactive/agent/mini menu -> `docs/FEATURES/NOTIFICATIONS.md`
- Screenshots -> `docs/FEATURES/SCREENSHOTS.md`
- Safe modification workflow -> `docs/EXTENSION_PLAYBOOK.md`

## Do Not Forget

- Live2D and image overlay share the same native overlay runtime.
- Notification replies do not have a separate LLM stack.
- Mini menu is native Android overlay UI, not Flutter widget UI.
- If you change a contract or ownership boundary, update the matching doc in the same change.

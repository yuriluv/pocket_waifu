# Lua Feature

## Overview
`lua` provides scriptable hooks to transform user/assistant/display text and execute
custom runtime behavior through Lua scripts.

## Main Structure
- **Scripting service**: `lib/features/lua/services/lua_scripting_service.dart`
- **Native bridge**: `lib/features/lua/services/lua_native_bridge.dart`
- **Script model**: `lib/features/lua/models/lua_script.dart`

## Cross-Feature Links
- **Notification coordinator and chat provider**: invoke Lua hooks during text processing.
- **Live2D directive pipeline**: Lua output can influence directive text and rendering.
- **Regex pipeline**: execution order (`runRegexBeforeLua`) changes final output behavior.

## Known Risks
- Hook ordering changes can alter user-visible output unexpectedly.
- Script errors can degrade response pipelines if not handled defensively.
- Lua behavior may differ between debug/runtime conditions.

## Change Checklist
1. Verify hook order against `runRegexBeforeLua` setting.
2. Test onUserMessage/onAssistantMessage/onDisplayRender paths.
3. Validate error handling and fallback output behavior.

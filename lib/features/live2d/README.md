# Live2D Feature

## Overview
`live2d` is the core runtime feature for model loading, overlay rendering, gesture interaction,
display configuration, and persistence of Live2D-related settings.

## Main Structure
- **Data models**: `lib/features/live2d/data/models/*`
- **Runtime services**: `lib/features/live2d/data/services/*`
- **Repositories**: `lib/features/live2d/data/repositories/*`
- **Presentation**: `lib/features/live2d/presentation/*`

## Cross-Feature Links
- **Directive integration**: `lib/features/live2d_llm/services/live2d_directive_service.dart`
- **Regex/Lua output pipeline**: via notification/chat service processing
- **Image overlay coordination**: `lib/features/image_overlay/*` bridges and sync paths

## Known Risks
- Native bridge + overlay behavior is sensitive to lifecycle and thread timing.
- Interaction and render parameters can regress quickly when adding new directives.
- Feature spans many files; prefer incremental changes with small commits.

## Change Checklist
1. Verify model load/render lifecycle across app resume/pause.
2. Re-check gesture/touch-through behavior after changes.
3. Validate compatibility with directive parsing and regex/lua output transforms.

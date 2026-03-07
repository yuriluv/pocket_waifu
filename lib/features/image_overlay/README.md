# Image Overlay Feature

## Overview
`image_overlay` manages image-based overlay mode, related presets/settings, and synchronization
between overlay state and runtime controls.

## Main Structure
- **Data models**: `lib/features/image_overlay/data/models/*`
- **Data services**: `lib/features/image_overlay/data/services/*`
- **Presentation**: `lib/features/image_overlay/presentation/*`
- **Feature services**: `lib/features/image_overlay/services/*`

## Cross-Feature Links
- **Live2D runtime**: native bridge and touch-through interactions coordinate with live2d settings.
- **Notification/runtime gating**: global runtime controls can affect overlay behavior.
- **Directive path**: image-overlay directives may be processed from assistant output.

## Known Risks
- Overlay state synchronization can drift if multiple controllers update same flags.
- Native bridge behavior differs by device/runtime state; test enable/disable transitions.
- Preset persistence and runtime sync are tightly coupled.

## Change Checklist
1. Validate overlay enable/disable and touch-through transitions.
2. Re-check preset load/save and character sync behavior.
3. Confirm no regression in interplay with live2d overlay controls.

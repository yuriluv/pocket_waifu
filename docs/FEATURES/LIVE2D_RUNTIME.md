# Live2D Runtime

This document covers model metadata loading, parameter ownership, alias generation, parameter presets, directive execution targets, and auto motion.

## Owned Code Paths

- Dart-side metadata and settings
  - `lib/features/live2d/data/models/live2d_settings.dart`
  - `lib/features/live2d/data/models/model3_data.dart`
  - `lib/features/live2d/data/models/live2d_parameter_preset.dart`
  - `lib/features/live2d/data/models/parameter_alias_map.dart`
  - `lib/features/live2d/data/models/auto_motion_config.dart`
  - `lib/features/live2d/data/repositories/live2d_settings_repository.dart`
  - `lib/features/live2d/data/services/model3_json_parser.dart`
  - `lib/features/live2d/data/services/auto_motion_service.dart`
  - `lib/features/live2d_llm/services/live2d_directive_service.dart`
- Native runtime
  - `android/app/src/main/kotlin/com/example/flutter_application_1/live2d/core/Live2DManager.kt`
  - `android/app/src/main/kotlin/com/example/flutter_application_1/live2d/core/Live2DModel.kt`
  - `android/app/src/main/kotlin/com/example/flutter_application_1/live2d/core/Model3JsonParser.kt`
  - `android/app/src/main/kotlin/com/example/flutter_application_1/live2d/renderer/Live2DGLRenderer.kt`

## Runtime Model Loading

### Persistent selection

`Live2DSettings` stores:
- whether Live2D is enabled
- selected model path/id
- overlay geometry and interaction settings

### Load path

1. Flutter chooses a model path.
2. `Live2DNativeBridge.loadModel` sends the model path to Android.
3. Android overlay service loads the model into the native Live2D runtime.
4. Flutter can query runtime metadata through bridge methods such as:
   - `getModelInfo`
   - `getMotionGroups`
   - `getExpressions`
   - `getParameterIds`
   - `getRuntimeParameterValues`

This means metadata can come from both sides:
- runtime-reported info from the loaded Android model
- Dart-side file parsing from `model3.json` and linked files

## Dart-Side `model3.json` Parsing

`Model3JsonParser` on Dart does more than parse the main file.

### It loads

- `model3.json`
- linked `DisplayInfo` (`cdi3`) if present
- linked `Physics` (`physics3`) if present

### It extracts

- motion groups and motion file names
- expressions
- parameter ids, names, and min/default/max values
- hit areas
- part names
- physics metadata and per-setting summaries

### Why this matters

Runtime bridge data is not always enough for editor-quality tooling.

The Dart parser gives higher-level information needed for:
- prompt capability previews
- alias generation
- parameter preset authoring
- editor displays for parts and physics

## Parameter Loading Strategy

Parameter ownership is split between the native runtime and Dart metadata.

### Source 1: native runtime

`Live2DDirectiveService._ensureParameterBoundsLoaded()` first asks the loaded runtime for `getModelInfo()` and current parameter values.

If the runtime provides parameter metadata, it is used immediately.

### Source 2: parsed model files

If the current model path exists on disk, the same method parses `model3.json` through the Dart parser and enriches the parameter bounds map.

### Source 3: fallback

If no metadata can be found, the service falls back to current runtime ids and very wide bounds.

This is intentionally permissive so directive execution still works even with incomplete metadata.

## Alias Generation And Storage

Parameter aliases exist to make prompts and directives easier to author.

### Ownership

`Live2DSettingsRepository` stores aliases per model path.

### Generation rule

If a model has no existing alias map, aliases are auto-generated as:
- `parameter1`
- `parameter2`
- `parameter3`
- ...

These are mapped to sorted real parameter ids.

### Why this matters

- Prompt authors can reference stable shorthand aliases.
- `Live2DDirectiveService` resolves aliases back to real parameter ids before writing values.

## Parameter Presets

Parameter presets are per-model snapshots of parameter overrides.

### Storage

Unlike many other settings, parameter presets are stored as JSON files under the app documents directory.

Repository owner:
- `Live2DSettingsRepository.loadParameterPresets(...)`
- `Live2DSettingsRepository.saveParameterPresets(...)`

### Purpose

They are used by directives such as `<preset name="..."/>` and by editor/test tooling.

### Important distinction

- a parameter preset is not the same thing as an emotion preset
- an emotion preset in the directive layer is a hardcoded semantic bundle such as `happy` or `sad`

## Directive Execution Targets

`Live2DDirectiveService` is the bridge between assistant output and the Live2D runtime.

### Supported directive concepts

- parameter writes
- waits
- motions
- expressions
- semantic emotions
- named parameter presets
- reset to defaults

### Execution model

- public assistant syntax such as `<live2d>...</live2d>`, `[param:...]`, `[emotion:...]`, `<overlay>...</overlay>`, and `[img_emotion:...]` is first owned by the default Regex/Lua layer
- the regex defaults rewrite that public syntax into internal runtime tokens before execution
- `Live2DDirectiveService` parses only the internal Live2D tokens (`<pwf-live2d>...</pwf-live2d>` and `[pwf-live2d:...]`)
- commands are serialized through `Live2DCommandQueue`
- parameter writes are clamped to known bounds when possible
- alias names are resolved before runtime writes

### Important ownership rule

`Live2DDirectiveService` does not render anything itself. It only translates assistant-side intent into bridge calls.

## Auto Motion

`AutoMotionService` is a timer-driven runtime automation layer.

### Owned behavior

- motion group selection
- interval timing
- sequential vs random motion choice
- optional expression cycling
- eye blink enablement and interval
- breathing enablement and cycle/weight
- look-at enablement
- physics enablement and tuning

### Runtime flow

1. Config is loaded from `SharedPreferences`.
2. A model's `Model3Data` is supplied to the service.
3. `applyConfig(...)` writes runtime toggles through `Live2DNativeBridge`.
4. If enabled, a periodic timer starts.
5. Each tick selects a motion index from the configured motion group.
6. If configured, expression changes are applied too.

### Important distinction

Auto motion is independent of LLM directives.

That means a model can:
- keep auto motion running in the background
- still react to LLM-driven emotion or parameter directives on top of that

## Physics, Blink, Breath, Look-At

These are runtime behavior toggles exposed through bridge calls, not prompt-layer abstractions.

The current owner is `AutoMotionService`, but any future runtime-control surface should still use the same bridge contract rather than mutating the native runtime directly from a screen.

## Extension Guidance

### Add a new Live2D directive

Update:
- `lib/features/live2d_llm/services/live2d_directive_service.dart`
- `lib/features/live2d/data/services/live2d_native_bridge.dart`
- Android method handling and native overlay/runtime code

### Add new parameter metadata

Keep the three-layer model in mind:
- runtime bridge metadata
- Dart-side `model3.json` parsing
- repository persistence for aliases/display names/presets

Do not put model-specific hardcoded assumptions into the UI layer.

### Add new automation behavior

Prefer extending `AutoMotionService` if the behavior is timer-based and model-runtime-local. Use the directive layer only when the behavior is assistant-output-driven.

## Common Failure Modes

- Assuming runtime metadata alone is authoritative. The Dart parser may know more.
- Forgetting that aliases are stored per model path.
- Forgetting to clamp parameter writes.
- Treating auto motion as an LLM feature when it is actually a timer-based runtime feature.
- Mixing up parameter presets and semantic emotion presets.

## Cross-Links

- Shared overlay host -> `docs/FEATURES/OVERLAYS.md`
- LLM call flow and prompt capability injection -> `docs/FEATURES/LLM_AND_PROMPTS.md`
- Regex/Lua transform order before directives -> `docs/FEATURES/TRANSFORMS.md`

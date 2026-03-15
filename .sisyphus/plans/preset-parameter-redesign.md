# API Preset Parameter Redesign Plan

## Goal

Redesign API settings so each API preset owns its own generation parameters and users edit presets in a fullscreen flow instead of popup dialogs.

## Scope

- Remove the separate parameter-tab workflow for API generation params.
- Move generation parameter editing into preset editing.
- Replace popup preset editors with a fullscreen editor that handles both normal presets and OAuth presets.
- Add Codex-specific parameter guidance and guardrails for fixed or unsupported values.
- Preserve non-API app settings in `AppSettings`.

## Planned Changes

1. Data model and migration
   - Keep preset-scoped params in `ApiConfig.additionalParams`.
   - Stop treating `AppSettings.temperature`, `topP`, `maxTokens`, `frequencyPenalty`, and `presencePenalty` as the runtime source of truth for API requests.
   - Add migration in `SettingsProvider.loadSettings()` so older global generation params are copied into existing presets when those presets do not already define equivalent values.
   - Keep the old `AppSettings` fields for compatibility unless removal is clearly safe in this change.

2. Request building
   - Update `ApiService` so request bodies read generation params from `ApiConfig.additionalParams` first, not from global settings sliders.
   - Keep provider-specific field-name translation and fixed Codex constraints (`instructions`, `store=false`, `stream=true`, Codex-managed headers).
   - Prevent Codex presets from sending known unsupported params where evidence is strong.

3. Settings UI architecture
   - Simplify `SettingsScreen` tabs to API presets + OAuth.
   - Replace `_ApiPresetEditDialog` and OAuth preset dialog flows with a dedicated fullscreen preset editor screen.
   - Route both create and edit actions into the fullscreen editor.

4. Fullscreen preset editor UX
   - Support normal presets and OAuth presets in one screen.
   - Include sections for basic info, auth/account binding, transport options, custom headers, and preset-owned generation params.
   - Show provider-specific guidance text.
   - For Codex presets, explain fixed values and unsupported params instead of exposing misleading controls.

5. Docs and tests
   - Update architecture docs for preset ownership and settings surface changes.
   - Add or update tests for migration, preset-owned request params, and Codex guidance/constraints where practical.

## Risks

- Legacy users may have only global params saved.
- OAuth preset creation currently lives in a separate widget file and needs a clean integration path.
- Some settings UI content in the old parameter tab is unrelated to API params and may need relocation rather than deletion.

## Verification

- LSP diagnostics on all modified Dart files.
- Focused Flutter tests for settings/api contract changes.
- `flutter analyze`.

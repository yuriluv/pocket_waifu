import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/api_config.dart';
import '../models/prompt_preset_reference.dart';
import '../providers/agent_prompt_preset_provider.dart';
import '../providers/global_runtime_provider.dart';
import '../providers/notification_settings_provider.dart';
import '../providers/settings_provider.dart';

class AgentModeSettingsScreen extends StatelessWidget {
  const AgentModeSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final notificationProvider = context.watch<NotificationSettingsProvider>();
    final runtimeProvider = context.watch<GlobalRuntimeProvider>();
    final settingsProvider = context.watch<SettingsProvider>();
    final agentPresetProvider = context.watch<AgentPromptPresetProvider>();

    final modeSettings = notificationProvider.agentModeSettings;
    final apiConfigs = settingsProvider.apiConfigs;
    final promptPresets = agentPresetProvider.references;

    return Scaffold(
      appBar: AppBar(title: const Text('Agent Mode')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (!runtimeProvider.isEnabled)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                'All features are paused. Toggle Master Switch to resume.',
              ),
            ),

          Card(
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('Agent Mode Enabled'),
                  subtitle: const Text(
                    'Run periodic observe-reason-act loop independently from proactive replies.',
                  ),
                  value: modeSettings.enabled,
                  onChanged: runtimeProvider.isEnabled
                      ? notificationProvider.setAgentModeEnabled
                      : null,
                ),
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      _PresetDropdown(
                        label: 'Agent Prompt Preset',
                        value: modeSettings.promptPresetId,
                        presets: promptPresets,
                        onChanged: runtimeProvider.isEnabled
                            ? notificationProvider.setAgentPromptPreset
                            : null,
                      ),
                      const SizedBox(height: 12),
                      _ApiPresetDropdown(
                        label: 'Agent API Preset',
                        value: modeSettings.apiPresetId,
                        apiConfigs: apiConfigs,
                        onChanged: runtimeProvider.isEnabled
                            ? notificationProvider.setAgentApiPreset
                            : null,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Trigger Interval: ${modeSettings.triggerIntervalMinutes} min',
                  ),
                  Slider(
                    value: modeSettings.triggerIntervalMinutes.toDouble(),
                    min: 1,
                    max: 120,
                    divisions: 119,
                    onChanged: runtimeProvider.isEnabled
                        ? (value) => notificationProvider
                              .setAgentTriggerIntervalMinutes(value.round())
                        : null,
                  ),
                  const SizedBox(height: 8),
                  Text('Max Iterations: ${modeSettings.maxIterations}'),
                  Slider(
                    value: modeSettings.maxIterations.toDouble(),
                    min: 1,
                    max: 10,
                    divisions: 9,
                    onChanged: runtimeProvider.isEnabled
                        ? (value) =>
                              notificationProvider.setAgentMaxIterations(value.round())
                        : null,
                  ),
                  const SizedBox(height: 8),
                  Text('Loop Timeout: ${modeSettings.loopTimeoutSeconds} sec'),
                  Slider(
                    value: modeSettings.loopTimeoutSeconds.toDouble(),
                    min: 30,
                    max: 300,
                    divisions: 27,
                    onChanged: runtimeProvider.isEnabled
                        ? (value) => notificationProvider
                              .setAgentLoopTimeoutSeconds(value.round())
                        : null,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),
          Card(
            color: Theme.of(context).colorScheme.tertiaryContainer,
            child: const Padding(
              padding: EdgeInsets.all(12),
              child: Text(
                'Agent Mode can issue multiple API calls per trigger. Keep max iterations conservative to control cost.',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PresetDropdown extends StatelessWidget {
  const _PresetDropdown({
    required this.label,
    required this.value,
    required this.presets,
    required this.onChanged,
  });

  final String label;
  final String? value;
  final List<PromptPresetReference> presets;
  final ValueChanged<String?>? onChanged;

  @override
  Widget build(BuildContext context) {
    String? effectiveValue;
    if (presets.any((preset) => preset.id == value)) {
      effectiveValue = value;
    } else if (presets.isNotEmpty) {
      effectiveValue = presets.first.id;
    }
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: effectiveValue,
          isExpanded: true,
          items: presets
              .map(
                (preset) => DropdownMenuItem<String>(
                  value: preset.id,
                  child: Text(preset.name),
                ),
              )
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _ApiPresetDropdown extends StatelessWidget {
  const _ApiPresetDropdown({
    required this.label,
    required this.value,
    required this.apiConfigs,
    required this.onChanged,
  });

  final String label;
  final String? value;
  final List<ApiConfig> apiConfigs;
  final ValueChanged<String?>? onChanged;

  @override
  Widget build(BuildContext context) {
    String? effectiveValue;
    if (apiConfigs.any((config) => config.id == value)) {
      effectiveValue = value;
    } else if (apiConfigs.isNotEmpty) {
      effectiveValue = apiConfigs.first.id;
    }
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: effectiveValue,
          isExpanded: true,
          items: apiConfigs
              .map(
                (config) => DropdownMenuItem<String>(
                  value: config.id,
                  child: Text(config.name),
                ),
              )
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/api_config.dart';
import '../models/prompt_preset_reference.dart';
import '../providers/agent_prompt_preset_provider.dart';
import '../providers/global_runtime_provider.dart';
import '../providers/notification_settings_provider.dart';
import '../providers/prompt_preset_provider.dart';
import '../providers/settings_provider.dart';
import '../utils/ui_feedback.dart';

class AgentModeSettingsScreen extends StatefulWidget {
  const AgentModeSettingsScreen({super.key});

  @override
  State<AgentModeSettingsScreen> createState() =>
      _AgentModeSettingsScreenState();
}

class _AgentModeSettingsScreenState extends State<AgentModeSettingsScreen> {
  late final TextEditingController _proactiveScheduleController;

  @override
  void initState() {
    super.initState();
    final scheduleText = context
        .read<NotificationSettingsProvider>()
        .proactiveSettings
        .scheduleText;
    _proactiveScheduleController = TextEditingController(text: scheduleText);
  }

  @override
  void dispose() {
    _proactiveScheduleController.dispose();
    super.dispose();
  }

  void _syncProactiveScheduleText(String scheduleText) {
    if (_proactiveScheduleController.text == scheduleText) return;
    _proactiveScheduleController.value = TextEditingValue(
      text: scheduleText,
      selection: TextSelection.collapsed(offset: scheduleText.length),
    );
  }

  @override
  Widget build(BuildContext context) {
    final notificationProvider = context.watch<NotificationSettingsProvider>();
    final runtimeProvider = context.watch<GlobalRuntimeProvider>();
    final settingsProvider = context.watch<SettingsProvider>();
    final promptPresetProvider = context.watch<PromptPresetProvider>();
    final agentPresetProvider = context.watch<AgentPromptPresetProvider>();

    final modeSettings = notificationProvider.agentModeSettings;
    final proactiveSettings = notificationProvider.proactiveSettings;
    final apiConfigs = settingsProvider.apiConfigs;
    final promptPresets = promptPresetProvider.presets;
    final agentPromptPresets = agentPresetProvider.references;

    notificationProvider.rebindPromptPresets(promptPresets);
    notificationProvider.rebindAgentPromptPresets(agentPromptPresets);
    notificationProvider.rebindApiPresets(apiConfigs);
    _syncProactiveScheduleText(proactiveSettings.scheduleText);

    return Scaffold(
      appBar: AppBar(title: const Text('에이전트 모드 설정')),
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
                '전체 기능이 일시 중지되었습니다. 전체 기능 On/Off를 켜면 다시 동작합니다.',
              ),
            ),

          Card(
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('에이전트 모드 사용'),
                  subtitle: const Text(
                    '선응답과 별개로 관찰-판단-행동 루프를 주기적으로 실행합니다.',
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
                        label: '에이전트 프롬프트 프리셋',
                        value: modeSettings.promptPresetId,
                        presets: agentPromptPresets,
                        onChanged: runtimeProvider.isEnabled
                            ? notificationProvider.setAgentPromptPreset
                            : null,
                      ),
                      const SizedBox(height: 12),
                      _ApiPresetDropdown(
                        label: '에이전트 API 프리셋',
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
                    '선응답(프로액티브) 설정',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('선응답 사용'),
                    subtitle: const Text('조건 충족 시 자동 선응답을 실행합니다.'),
                    value: proactiveSettings.enabled,
                    onChanged: runtimeProvider.isEnabled
                        ? notificationProvider.setProactiveEnabled
                        : null,
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _proactiveScheduleController,
                    maxLines: 6,
                    enabled: runtimeProvider.isEnabled,
                    decoration: const InputDecoration(
                      labelText: '프로액티브 스케줄',
                      border: OutlineInputBorder(),
                      helperText:
                          '예: base=30m\ndeviation=10\noverlayon=-20m\nscreenlandscape=+20m\nscreenoff=inf',
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.check),
                      label: const Text('스케줄 검증 및 저장'),
                      onPressed: runtimeProvider.isEnabled
                          ? () {
                              final scheduleText =
                                  _proactiveScheduleController.text.trim();
                              try {
                                notificationProvider.validateProactiveSchedule(
                                  scheduleText,
                                );
                                notificationProvider.updateProactiveSchedule(
                                  scheduleText,
                                );
                                context.showInfoSnackBar(
                                  '프로액티브 스케줄을 저장했습니다.',
                                );
                              } catch (e) {
                                context.showErrorSnackBar(e.toString());
                              }
                            }
                          : null,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _PresetDropdown(
                    label: '프로액티브 프롬프트 프리셋',
                    value: proactiveSettings.promptPresetId,
                    presets: promptPresets,
                    onChanged: runtimeProvider.isEnabled
                        ? notificationProvider.setProactivePromptPreset
                        : null,
                  ),
                  const SizedBox(height: 12),
                  _ApiPresetDropdown(
                    label: '프로액티브 API 프리셋',
                    value: proactiveSettings.apiPresetId,
                    apiConfigs: apiConfigs,
                    onChanged: runtimeProvider.isEnabled
                        ? notificationProvider.setProactiveApiPreset
                        : null,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('최대 반복 횟수: ${modeSettings.maxIterations}회'),
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
                  Text('루프 제한 시간: ${modeSettings.loopTimeoutSeconds}초'),
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
                '에이전트 모드는 한 번의 실행에서 여러 API 호출이 발생할 수 있습니다. 비용 관리를 위해 최대 반복 횟수는 보수적으로 설정하세요.',
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

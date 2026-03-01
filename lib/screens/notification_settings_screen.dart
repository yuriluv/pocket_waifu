import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import '../models/prompt_preset_reference.dart';
import '../providers/notification_settings_provider.dart';
import '../providers/prompt_preset_provider.dart';
import '../providers/settings_provider.dart';
import '../models/api_config.dart';
import '../utils/ui_feedback.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  late TextEditingController _proactiveController;

  @override
  void initState() {
    super.initState();
    final provider = context
        .read<NotificationSettingsProvider>()
        .proactiveSettings;
    _proactiveController = TextEditingController(text: provider.scheduleText);
  }

  @override
  void dispose() {
    _proactiveController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settingsProvider = context.watch<NotificationSettingsProvider>();
    final notificationSettings = settingsProvider.notificationSettings;
    final proactiveSettings = settingsProvider.proactiveSettings;
    final apiConfigs = context.watch<SettingsProvider>().apiConfigs;
    final promptPresets = context.watch<PromptPresetProvider>().presets;
    settingsProvider.rebindPromptPresets(promptPresets);
    settingsProvider.rebindApiPresets(apiConfigs);

    return Scaffold(
      appBar: AppBar(title: const Text('알림 설정')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SectionTitle(title: '알림'),
          SwitchListTile(
            title: const Text('알림 사용'),
            subtitle: const Text('선응답(프로액티브) 대화 알림을 사용합니다.'),
            value: notificationSettings.notificationsEnabled,
            onChanged: (value) async {
              final enabled = await settingsProvider.setNotificationsEnabled(
                value,
              );
              if (!mounted) return;
              if (!enabled) {
                _showPermissionDialog();
              }
            },
          ),
          SwitchListTile(
            title: const Text('출력을 새 알림으로'),
            subtitle: const Text('AI 응답을 헤드업 알림으로 표시합니다.'),
            value: notificationSettings.outputAsNewNotification,
            onChanged: settingsProvider.setOutputAsNewNotification,
          ),
          const Divider(height: 32),
          _SectionTitle(title: '프로액티브 응답'),
          SwitchListTile(
            title: const Text('프로액티브 응답 사용'),
            subtitle: const Text('랜덤 간격 응답을 활성화합니다.'),
            value: proactiveSettings.enabled,
            onChanged: settingsProvider.setProactiveEnabled,
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _proactiveController,
            maxLines: 6,
            decoration: const InputDecoration(
              labelText: '프로액티브 스케줄',
              border: OutlineInputBorder(),
              helperText:
                  '예: base=30m\ndeviation=10\noverlayon=-20m\nscreenlandscape=+20m\nscreenoff=inf',
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.check),
                  label: const Text('검증 & 저장'),
                  onPressed: () {
                    try {
                      settingsProvider.validateProactiveSchedule(
                        _proactiveController.text.trim(),
                      );
                      settingsProvider.updateProactiveSchedule(
                        _proactiveController.text.trim(),
                      );
                      context.showInfoSnackBar('프로액티브 스케줄 저장됨');
                    } catch (e) {
                      context.showErrorSnackBar(e.toString());
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _PresetDropdown(
            label: '프로액티브 프롬프트 프리셋',
            value: proactiveSettings.promptPresetId,
            presets: promptPresets,
            onChanged: settingsProvider.setProactivePromptPreset,
          ),
          const SizedBox(height: 12),
          _ApiPresetDropdown(
            label: '프로액티브 API 프리셋',
            value: proactiveSettings.apiPresetId,
            apiConfigs: apiConfigs,
            onChanged: settingsProvider.setProactiveApiPreset,
          ),
        ],
      ),
    );
  }

  void _showPermissionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('알림 권한 필요'),
        content: const Text('알림을 사용하려면 권한이 필요합니다. 설정에서 허용하세요.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('닫기'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              openAppSettings();
            },
            child: const Text('설정 열기'),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: Theme.of(
          context,
        ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
      ),
    );
  }
}

class _PresetDropdown extends StatelessWidget {
  final String label;
  final String? value;
  final List<PromptPresetReference> presets;
  final ValueChanged<String?> onChanged;

  const _PresetDropdown({
    required this.label,
    required this.value,
    required this.presets,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value ?? (presets.isNotEmpty ? presets.first.id : null),
          isExpanded: true,
          items: presets
              .map(
                (preset) => DropdownMenuItem(
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
  final String label;
  final String? value;
  final List<ApiConfig> apiConfigs;
  final ValueChanged<String?> onChanged;

  const _ApiPresetDropdown({
    required this.label,
    required this.value,
    required this.apiConfigs,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value ?? (apiConfigs.isNotEmpty ? apiConfigs.first.id : null),
          isExpanded: true,
          items: apiConfigs
              .map<DropdownMenuItem<String>>(
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

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import '../models/prompt_preset_reference.dart';
import '../providers/chat_session_provider.dart';
import '../providers/global_runtime_provider.dart';
import '../providers/notification_settings_provider.dart';
import '../providers/prompt_preset_provider.dart';
import '../providers/settings_provider.dart';
import '../models/api_config.dart';
import '../services/notification_bridge.dart';
import '../utils/ui_feedback.dart';
import 'proactive_debug_screen.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  late TextEditingController _proactiveController;
  late TextEditingController _testCharNameController;
  late TextEditingController _testMessageController;

  @override
  void initState() {
    super.initState();
    final provider =
        context.read<NotificationSettingsProvider>().proactiveSettings;
    final characterName = context.read<SettingsProvider>().character.name;
    _proactiveController = TextEditingController(text: provider.scheduleText);
    _testCharNameController = TextEditingController(text: characterName);
    _testMessageController = TextEditingController();
  }

  @override
  void dispose() {
    _proactiveController.dispose();
    _testCharNameController.dispose();
    _testMessageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settingsProvider = context.watch<NotificationSettingsProvider>();
    final globalRuntimeProvider = context.watch<GlobalRuntimeProvider>();
    final masterEnabled = globalRuntimeProvider.isEnabled;
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
          if (!masterEnabled)
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
          Opacity(
            opacity: masterEnabled ? 1 : 0.4,
            child: IgnorePointer(
              ignoring: !masterEnabled,
              child: Column(
                children: [
          _SectionTitle(title: '알림'),
          SwitchListTile(
            title: const Text('알림 사용'),
            subtitle: const Text('알림 및 선응답(프로액티브) 기능을 사용합니다.'),
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
          _SectionTitle(title: '알림 답장 프리셋'),
          Opacity(
            opacity: notificationSettings.notificationsEnabled ? 1 : 0.5,
            child: IgnorePointer(
              ignoring: !notificationSettings.notificationsEnabled,
              child: Column(
                children: [
                  _PresetDropdown(
                    label: '답장 프롬프트 프리셋',
                    value: notificationSettings.promptPresetId,
                    presets: promptPresets,
                    onChanged: settingsProvider.setNotificationPromptPreset,
                  ),
                  const SizedBox(height: 12),
                  _ApiPresetDropdown(
                    label: '답장 API 프리셋',
                    value: notificationSettings.apiPresetId,
                    apiConfigs: apiConfigs,
                    onChanged: settingsProvider.setNotificationApiPreset,
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 32),
          _SectionTitle(title: '프로액티브 응답'),
          Opacity(
            opacity: notificationSettings.notificationsEnabled ? 1 : 0.5,
            child: IgnorePointer(
              ignoring: !notificationSettings.notificationsEnabled,
              child: Column(
                children: [
                  SwitchListTile(
                    title: const Text('선응답 사용'),
                    subtitle: const Text('조건 충족 시 자동 선응답을 실행합니다.'),
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
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.bug_report_outlined),
              label: const Text('선응답 디버그'),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const ProactiveDebugScreen(),
                  ),
                );
              },
            ),
          ),
          const Divider(height: 32),
          _SectionTitle(title: '알림 테스트'),
          TextField(
            controller: _testCharNameController,
            decoration: const InputDecoration(
              labelText: '캐릭터 이름',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _testMessageController,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: '메세지',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: ElevatedButton(
              onPressed: () async {
                final charName = _testCharNameController.text.trim();
                final message = _testMessageController.text.trim();
                if (charName.isEmpty || message.isEmpty) {
                  context.showErrorSnackBar('캐릭터 이름과 메세지를 입력하세요.');
                  return;
                }
                final activeSessionId =
                    context.read<ChatSessionProvider>().activeSessionId;
                debugPrint(
                  'Notification test: send title=$charName sessionId=$activeSessionId',
                );
                if (activeSessionId == null) {
                  context.showErrorSnackBar('활성 세션이 없습니다. 채팅 세션을 먼저 생성하세요.');
                  return;
                }
                await NotificationBridge.instance.showPreResponseNotification(
                  title: charName,
                  message: message,
                  sessionId: activeSessionId,
                );
                if (!context.mounted) return;
                context.showInfoSnackBar('테스트 알림을 전송했습니다.');
              },
              child: const Text('테스트 알림 보내기'),
            ),
          ),
                ],
              ),
            ),
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

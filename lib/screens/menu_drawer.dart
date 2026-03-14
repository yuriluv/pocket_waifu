// ============================================================================
// ============================================================================
// ============================================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/chat_session_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/global_runtime_provider.dart';
import 'prompt_editor_screen.dart';
import 'chat_list_screen.dart';
import 'theme_editor_screen.dart';
import 'settings_screen.dart';
import 'screen_share_settings_screen.dart';
import 'notification_settings_screen.dart';
import 'agent_mode_settings_screen.dart';
import 'regex_lua_management_screen.dart';
import '../features/live2d/live2d_module.dart';
import '../features/image_overlay/presentation/screens/image_overlay_settings_screen.dart';
import '../widgets/prompt_preview_dialog.dart';
import 'prompt_preview_screen.dart';
import '../utils/ui_feedback.dart';

class MenuDrawer extends StatelessWidget {
  const MenuDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final chatSessionProvider = Provider.of<ChatSessionProvider>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final settingsProvider = Provider.of<SettingsProvider>(context);
    final globalRuntimeProvider = Provider.of<GlobalRuntimeProvider>(context);

    return Drawer(
      child: Column(
        children: [
          _DrawerHeader(
            themeProvider: themeProvider,
            characterName: settingsProvider.character.name,
            onEditCharacterName: () =>
                _showCharacterNameDialog(context, settingsProvider),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: _GlobalRuntimeToggleTile(
              isEnabled: globalRuntimeProvider.isEnabled,
              isLoading: globalRuntimeProvider.isLoading,
              onChanged: globalRuntimeProvider.setEnabled,
            ),
          ),

          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                const _SectionTitle(title: '채팅'),

                _DrawerMenuItem(
                  icon: Icons.add_comment,
                  title: '새 채팅',
                  onTap: () {
                    chatSessionProvider.createNewSession();
                    Navigator.pop(context);
                    context.showInfoSnackBar('새 채팅을 시작했습니다.');
                  },
                ),

                _DrawerMenuItem(
                  icon: Icons.list,
                  title: '채팅 목록',
                  subtitle: '${chatSessionProvider.sessions.length}개의 채팅',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ChatListScreen(),
                      ),
                    );
                  },
                ),

                const Divider(),

                const _SectionTitle(title: '설정'),

                _DrawerMenuItem(
                  icon: Icons.key,
                  title: 'API 설정',
                  subtitle: 'API 키, OAuth, 모델 설정',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const SettingsScreen(),
                      ),
                    );
                  },
                ),

                _DrawerMenuItem(
                  icon: Icons.notifications,
                  title: '알림 설정',
                  subtitle: '알림/프로액티브 응답 설정',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            const NotificationSettingsScreen(),
                      ),
                    );
                  },
                ),

                _DrawerMenuItem(
                  icon: Icons.smart_toy_outlined,
                  title: '에이전트 모드',
                  subtitle: '자율 관찰/판단/행동 루프 설정',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const AgentModeSettingsScreen(),
                      ),
                    );
                  },
                ),

                _DrawerMenuItem(
                  icon: Icons.rule_folder,
                  title: 'Regex / Lua 관리',
                  subtitle: '규칙·스크립트 CRUD 및 Live2D-LLM 옵션',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const RegexLuaManagementScreen(),
                      ),
                    );
                  },
                ),

                const Divider(),

                const _SectionTitle(title: '프롬프트'),

                _DrawerMenuItem(
                  icon: Icons.edit_note,
                  title: '프롬프트 블록 편집',
                  subtitle: '프롬프트 구조 커스터마이징',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const PromptEditorScreen(),
                      ),
                    );
                  },
                ),

                _DrawerMenuItem(
                  icon: Icons.preview,
                  title: '프롬프트 미리보기',
                  subtitle: '실제 API 전송 프롬프트 확인',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const PromptPreviewScreen(),
                      ),
                    );
                  },
                ),

                const Divider(),

                const _SectionTitle(title: '테마'),

                _DrawerMenuItem(
                  icon: Icons.palette,
                  title: '테마 설정',
                  subtitle: themeProvider.activePreset?.name ?? '기본 테마',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ThemeEditorScreen(),
                      ),
                    );
                  },
                ),

                SwitchListTile(
                  secondary: Icon(
                    themeProvider.themeMode == ThemeMode.dark
                        ? Icons.dark_mode
                        : Icons.light_mode,
                  ),
                  title: const Text('다크 모드'),
                  value: themeProvider.themeMode == ThemeMode.dark,
                  onChanged: (value) {
                    themeProvider.setThemeMode(
                      value ? ThemeMode.dark : ThemeMode.light,
                    );
                  },
                ),

                const Divider(),

                const _SectionTitle(title: 'Live2D'),

                const _SectionTitle(title: '오버레이'),

                _DrawerMenuItem(
                  icon: Icons.face,
                  title: 'Live2D 설정',
                  subtitle: '오버레이 캐릭터 설정',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const Live2DSettingsScreen(),
                      ),
                    );
                  },
                ),

                _DrawerMenuItem(
                  icon: Icons.image,
                  title: '이미지 오버레이 설정',
                  subtitle: '이미지 오버레이 모드',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ImageOverlaySettingsScreen(),
                      ),
                    );
                  },
                ),

                _DrawerMenuItem(
                  icon: Icons.screen_share_outlined,
                  title: 'Screen Share',
                  subtitle: 'Permission & capture options',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ScreenShareSettingsScreen(),
                      ),
                    );
                  },
                ),

                const Divider(),

                const _SectionTitle(title: '도움말'),

                _DrawerMenuItem(
                  icon: Icons.terminal,
                  title: '명령어 도움말',
                  subtitle: '/del, /send, /edit 등',
                  onTap: () {
                    Navigator.pop(context);
                    CommandHelpDialog.show(context);
                  },
                ),

                _DrawerMenuItem(
                  icon: Icons.info_outline,
                  title: '앱 정보',
                  onTap: () {
                    Navigator.pop(context);
                    _showAboutDialog(context);
                  },
                ),
              ],
            ),
          ),

          Container(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Pocket Waifu v1.0.0+1',
              style: TextStyle(color: Colors.grey[500], fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  void _showCharacterNameDialog(
    BuildContext context,
    SettingsProvider settingsProvider,
  ) {
    final controller = TextEditingController(
      text: settingsProvider.character.name,
    );
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('캐릭터 이름 변경'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              hintText: '캐릭터 이름',
            ),
            onSubmitted: (_) => _saveCharacterName(
              dialogContext,
              settingsProvider,
              controller.text,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('취소'),
            ),
            ElevatedButton(
              onPressed: () => _saveCharacterName(
                dialogContext,
                settingsProvider,
                controller.text,
              ),
              child: const Text('저장'),
            ),
          ],
        );
      },
    );
  }

  void _saveCharacterName(
    BuildContext dialogContext,
    SettingsProvider settingsProvider,
    String raw,
  ) {
    final name = raw.trim();
    if (name.isEmpty) return;
    settingsProvider.setCharacterName(name);
    Navigator.pop(dialogContext);
  }

  void _showAboutDialog(BuildContext context) {
    showAboutDialog(
      context: context,
      applicationName: 'Pocket Waifu',
      applicationVersion: '1.0.0+1',
      applicationIcon: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(Icons.favorite, color: Colors.white, size: 28),
      ),
      applicationLegalese:
          '© 2024 Pocket Waifu\n\n'
          'SillyTavern 스타일의 AI 채팅 앱입니다.\n'
          'OpenAI, Anthropic, GitHub Copilot API를 지원합니다.\n'
          'Live2D 오버레이 기능을 지원합니다.',
    );
  }
}

class _DrawerHeader extends StatelessWidget {
  final ThemeProvider themeProvider;
  final String characterName;
  final VoidCallback onEditCharacterName;

  const _DrawerHeader({
    required this.themeProvider,
    required this.characterName,
    required this.onEditCharacterName,
  });

  @override
  Widget build(BuildContext context) {
    return DrawerHeader(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Theme.of(context).colorScheme.primary,
            Theme.of(context).colorScheme.secondary,
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.favorite, color: Colors.white, size: 32),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: onEditCharacterName,
                  borderRadius: BorderRadius.circular(6),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Text(
                      characterName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: onEditCharacterName,
                icon: const Icon(Icons.edit, color: Colors.white),
                tooltip: '캐릭터 이름 편집',
              ),
            ],
          ),
          Text(
            'AI 캐릭터와 대화하세요',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

class _GlobalRuntimeToggleTile extends StatelessWidget {
  final bool isEnabled;
  final bool isLoading;
  final ValueChanged<bool> onChanged;

  const _GlobalRuntimeToggleTile({
    required this.isEnabled,
    required this.isLoading,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final statusColor = isEnabled ? Colors.green : colorScheme.error;
    final statusText = isEnabled ? 'ON' : 'OFF';

    return Material(
      color: colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: isLoading ? null : () => onChanged(!isEnabled),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Icon(
                isEnabled ? Icons.power : Icons.power_off,
                color: statusColor,
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  '전체 기능 On/Off',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              if (isLoading)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else ...[
                Text(
                  statusText,
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 8),
                Switch(value: isEnabled, onChanged: onChanged),
              ],
            ],
          ),
        ),
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
      padding: const EdgeInsets.only(left: 16, top: 16, bottom: 4),
      child: Text(
        title,
        style: TextStyle(
          color: Theme.of(context).colorScheme.primary,
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _DrawerMenuItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  const _DrawerMenuItem({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: subtitle != null ? Text(subtitle!) : null,
      onTap: onTap,
    );
  }
}

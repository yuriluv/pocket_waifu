// ============================================================================
// 메뉴 드로어 (Menu Drawer)
// ============================================================================
// 앱의 메인 네비게이션 드로어입니다.
// 채팅 목록, 설정, 프롬프트 편집, 테마 설정 등에 접근할 수 있습니다.
// ============================================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/chat_session_provider.dart';
import '../providers/theme_provider.dart';
import 'prompt_editor_screen.dart';
import 'chat_list_screen.dart';
import 'theme_editor_screen.dart';
import 'settings_screen.dart';
import 'live2d_settings_screen.dart';
import '../widgets/prompt_preview_dialog.dart';

/// 메뉴 드로어 위젯
class MenuDrawer extends StatelessWidget {
  const MenuDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final chatSessionProvider = Provider.of<ChatSessionProvider>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Drawer(
      child: Column(
        children: [
          // === 드로어 헤더 ===
          _DrawerHeader(themeProvider: themeProvider),

          // === 메뉴 목록 ===
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                // ▶ 채팅 섹션
                const _SectionTitle(title: '채팅'),

                // 새 채팅 시작
                _DrawerMenuItem(
                  icon: Icons.add_comment,
                  title: '새 채팅',
                  onTap: () {
                    // v2.0.4: 세션 생성만 하면 ChatProvider가 자동 연동
                    chatSessionProvider.createNewSession();
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('새 채팅을 시작했습니다.'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                ),

                // 채팅 목록
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

                // ▶ 설정 섹션
                const _SectionTitle(title: '설정'),

                // API 설정
                _DrawerMenuItem(
                  icon: Icons.key,
                  title: 'API 설정',
                  subtitle: 'API 키 및 모델 설정',
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

                const Divider(),

                // ▶ 프롬프트 섹션
                const _SectionTitle(title: '프롬프트'),

                // 프롬프트 블록 편집
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

                // 프롬프트 미리보기 (⭐ v2.0.3: 실제 API 전송 프롬프트 보기)
                _DrawerMenuItem(
                  icon: Icons.preview,
                  title: '프롬프트 미리보기',
                  subtitle: '실제 API 전송 프롬프트 확인',
                  onTap: () {
                    Navigator.pop(context);
                    PromptPreviewDialog.showWithRealPrompt(context);
                  },
                ),

                const Divider(),

                // ▶ 테마 섹션
                const _SectionTitle(title: '테마'),

                // 테마 설정
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

                // 다크 모드 토글
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

                // ▶ Live2D 섹션
                const _SectionTitle(title: 'Live2D'),

                // Live2D 설정
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

                const Divider(),

                // ▶ 도움말 섹션
                const _SectionTitle(title: '도움말'),

                // 명령어 도움말
                _DrawerMenuItem(
                  icon: Icons.terminal,
                  title: '명령어 도움말',
                  subtitle: '/del, /send, /edit 등',
                  onTap: () {
                    Navigator.pop(context);
                    CommandHelpDialog.show(context);
                  },
                ),

                // 앱 정보
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

          // === 하단 버전 정보 ===
          Container(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Pocket Waifu v2.0.0',
              style: TextStyle(color: Colors.grey[500], fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  /// 앱 정보 다이얼로그 표시
  void _showAboutDialog(BuildContext context) {
    showAboutDialog(
      context: context,
      applicationName: 'Pocket Waifu',
      applicationVersion: '2.0.0',
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

/// 드로어 헤더 위젯
class _DrawerHeader extends StatelessWidget {
  final ThemeProvider themeProvider;

  const _DrawerHeader({required this.themeProvider});

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
          // 앱 아이콘
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
          // 앱 이름
          const Text(
            'Pocket Waifu',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          // 서브타이틀
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

/// 섹션 타이틀 위젯
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

/// 드로어 메뉴 아이템 위젯
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

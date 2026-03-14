// ============================================================================
// ============================================================================
// ============================================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/api_config.dart';
import '../providers/global_runtime_provider.dart';
import '../providers/settings_provider.dart';
import '../services/image_cache_manager.dart';
import 'api_preset_editor_screen.dart';
import 'live2d_llm_settings_screen.dart';
import '../widgets/empty_state_view.dart';
import '../widgets/oauth_management_widgets.dart';
import '../utils/ui_feedback.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final runtimeProvider = context.watch<GlobalRuntimeProvider>();
    return Scaffold(
        appBar: AppBar(
        title: const Text('API 설정'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.api), text: 'API 프리셋'),
            Tab(icon: Icon(Icons.verified_user), text: 'OAuth'),
            Tab(icon: Icon(Icons.build_outlined), text: '보조'),
          ],
        ),
      ),
      body: Column(
        children: [
          if (!runtimeProvider.isEnabled)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              color: Colors.amber.withValues(alpha: 0.18),
              child: Row(
                children: const [
                  Icon(Icons.warning_amber_rounded, size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Master is OFF - changes will take effect when turned ON',
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
                children: const [
                  _ApiPresetsTab(),
                  OAuthAccountsTab(),
                  _ApiUtilitiesTab(),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ============================================================================
// ============================================================================

class _ApiPresetsTab extends StatelessWidget {
  const _ApiPresetsTab();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final settingsProvider = context.watch<SettingsProvider>();
    final apiConfigs = settingsProvider.apiConfigs;
    final activeConfigId = settingsProvider.activeApiConfigId;

    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: colorScheme.primaryContainer.withValues(alpha: 0.45),
            border: Border(
              bottom: BorderSide(
                color: colorScheme.outlineVariant.withValues(alpha: 0.45),
              ),
            ),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, size: 18, color: colorScheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'API 프리셋을 선택하거나 새로 만들어 사용하세요.\n'
                   '각 프리셋은 Base URL, 인증 방식, 모델, 헤더, 생성 파라미터를 독립적으로 가집니다.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
            ],
          ),
        ),

        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _showPresetTemplateDialog(context),
                  icon: const Icon(Icons.add),
                  label: const Text('프리셋 템플릿으로 추가'),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: () => _openPresetEditor(
                  context,
                  seedConfig: ApiConfig.custom(),
                ),
                icon: const Icon(Icons.edit_note),
                label: const Text('커스텀'),
              ),
            ],
          ),
        ),

        const Divider(height: 1),

        Expanded(
          child: apiConfigs.isEmpty
              ? const EmptyStateView(
                  icon: Icons.api,
                  title: 'API 프리셋이 없습니다',
                  subtitle: '위 버튼을 눌러 프리셋을 추가하세요',
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: apiConfigs.length,
                  itemBuilder: (context, index) {
                    final config = apiConfigs[index];
                    final isActive = config.id == activeConfigId;
                    final oauthAccount = settingsProvider.getOAuthAccountById(
                      config.oauthAccountId,
                    );
                    return _ApiPresetCard(
                      config: config,
                      oauthAccountLabel: oauthAccount?.displayLabel,
                      isActive: isActive,
                      onTap: () =>
                          settingsProvider.setActiveApiConfig(config.id),
                      onEdit: () {
                        _openPresetEditor(context, existingConfig: config);
                      },
                      onDelete: () => _confirmDeletePreset(context, config),
                    );
                  },
                ),
        ),

        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerLow,
            border: Border(
              top: BorderSide(
                color: colorScheme.outlineVariant.withValues(alpha: 0.45),
              ),
            ),
          ),
          child: Row(
            children: [
              const Icon(Icons.person, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  initialValue: settingsProvider.userName,
                  decoration: const InputDecoration(
                    labelText: '사용자 이름',
                    hintText: '예: 마스터, 주인님...',
                    border: OutlineInputBorder(),
                    isDense: true,
                    helperText: 'AI가 당신을 부를 이름',
                  ),
                  onChanged: settingsProvider.updateUserName,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showPresetTemplateDialog(BuildContext context) {
    final screenContext = context;
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('프리셋 템플릿 선택'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(
            shrinkWrap: true,
            children: [
              _TemplateOption(
                icon: Icons.code,
                title: 'GitHub Copilot',
                subtitle: 'Copilot API (gho_ 토큰 필요)',
                onTap: () {
                  Navigator.pop(dialogContext);
                  _openPresetEditor(
                    screenContext,
                    seedConfig: ApiConfig.copilotDefault(),
                  );
                },
              ),
              _TemplateOption(
                icon: Icons.smart_toy,
                title: 'OpenAI',
                subtitle: 'GPT 모델 (sk- API 키 필요)',
                onTap: () {
                  Navigator.pop(dialogContext);
                  _openPresetEditor(
                    screenContext,
                    seedConfig: ApiConfig.openaiDefault(),
                  );
                },
              ),
              _TemplateOption(
                icon: Icons.psychology,
                title: 'Anthropic',
                subtitle: 'Claude 모델 (sk-ant- API 키 필요)',
                onTap: () {
                  Navigator.pop(dialogContext);
                  _openPresetEditor(
                    screenContext,
                    seedConfig: ApiConfig.anthropicDefault(),
                  );
                },
              ),
              _TemplateOption(
                icon: Icons.router,
                title: 'OpenRouter',
                subtitle: '여러 모델 지원 (openrouter.ai)',
                onTap: () {
                  Navigator.pop(dialogContext);
                  _openPresetEditor(
                    screenContext,
                    seedConfig: ApiConfig.openRouterDefault(),
                  );
                },
              ),
              _TemplateOption(
                icon: Icons.verified_user,
                title: 'Codex OAuth',
                subtitle: 'Codex 계정 기반 프리셋',
                onTap: () {
                  Navigator.pop(dialogContext);
                  _openPresetEditor(
                    screenContext,
                    seedConfig: ApiConfig(
                      name: 'Codex OAuth',
                      baseUrl: 'https://chatgpt.com/backend-api/codex/responses',
                      modelName: 'gpt-5.3-codex',
                      format: ApiFormat.openAIResponses,
                      additionalParams: const {},
                    ),
                  );
                },
              ),
              _TemplateOption(
                icon: Icons.auto_awesome,
                title: 'Gemini CLI OAuth',
                subtitle: 'Gemini CLI / GCA 계정 기반 프리셋',
                onTap: () {
                  Navigator.pop(dialogContext);
                  _openPresetEditor(
                    screenContext,
                    seedConfig: ApiConfig(
                      name: 'Gemini CLI OAuth',
                      baseUrl:
                          'https://cloudcode-pa.googleapis.com/v1internal:generateContent',
                      modelName: 'gemini-2.5-pro',
                      format: ApiFormat.googleCodeAssist,
                      additionalParams: const {},
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('취소'),
          ),
        ],
      ),
    );
  }

  Future<void> _openPresetEditor(
    BuildContext context, {
    ApiConfig? existingConfig,
    ApiConfig? seedConfig,
  }) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => ApiPresetEditorScreen(
          existingConfig: existingConfig,
          seedConfig: seedConfig,
        ),
      ),
    );
  }

  void _confirmDeletePreset(BuildContext context, ApiConfig config) {
    final colorScheme = Theme.of(context).colorScheme;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('프리셋 삭제'),
        content: Text('"${config.name}" 프리셋을 삭제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              context.read<SettingsProvider>().removeApiConfig(config.id);
            },
            style: TextButton.styleFrom(foregroundColor: colorScheme.error),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
  }
}

class _TemplateOption extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _TemplateOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
      title: Text(title),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
      onTap: onTap,
    );
  }
}

class _ApiPresetCard extends StatelessWidget {
  final ApiConfig config;
  final String? oauthAccountLabel;
  final bool isActive;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ApiPresetCard({
    required this.config,
    this.oauthAccountLabel,
    required this.isActive,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final hasCredential = config.usesOAuth || config.apiKey.isNotEmpty;
    final apiKeyStatusColor = hasCredential
        ? colorScheme.tertiary
        : colorScheme.error;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      elevation: isActive ? 3 : 1,
      color: isActive
          ? colorScheme.primaryContainer.withValues(alpha: 0.25)
          : theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: isActive
            ? BorderSide(color: colorScheme.primary, width: 2)
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Icon(
                isActive ? Icons.radio_button_checked : Icons.radio_button_off,
                color: isActive
                    ? colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 8),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            config.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (config.isDefault) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: colorScheme.tertiaryContainer.withValues(
                                alpha: 0.55,
                              ),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '기본',
                              style: TextStyle(
                                fontSize: 10,
                                color: colorScheme.onTertiaryContainer,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    if (config.usesOAuth) ...[
                      Text(
                        'OAuth: ${oauthAccountLabel ?? '연결된 계정'}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 2),
                    ],
                    Text(
                      config.modelName,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      config.baseUrl,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant.withValues(
                          alpha: 0.9,
                        ),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          hasCredential ? Icons.check_circle : Icons.warning_amber,
                          size: 14,
                          color: apiKeyStatusColor,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          config.usesOAuth
                              ? 'OAuth 계정 연결됨'
                              : hasCredential
                                  ? 'API 키 설정됨'
                                  : 'API 키 필요',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: apiKeyStatusColor,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              Column(
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit, size: 20),
                    onPressed: onEdit,
                    tooltip: '편집',
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 20),
                    onPressed: onDelete,
                    tooltip: '삭제',
                    color: colorScheme.error,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ApiUtilitiesTab extends StatelessWidget {
  const _ApiUtilitiesTab();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _SectionTitle(title: '보조 설정'),
        const SizedBox(height: 8),
        Text(
          'API 생성 파라미터는 이제 각 프리셋 편집 화면에서 관리합니다. 이 탭은 캐시와 연동 도구만 다룹니다.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),

        const SizedBox(height: 24),
        const _ImageCacheManagementSection(),

        const SizedBox(height: 24),
        Card(
          child: ListTile(
            leading: const Icon(Icons.animation_outlined),
            title: const Text('Live2D-LLM Integration Settings'),
            subtitle: const Text('Directive/Lua/Prompt 통합 설정'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const Live2DLlmSettingsScreen(),
                ),
              );
            },
          ),
        ),

        // Note: Additional/Jailbreak prompts removed in v2.0.6
      ],
    );
  }
}

class _ImageCacheManagementSection extends StatefulWidget {
  const _ImageCacheManagementSection();

  @override
  State<_ImageCacheManagementSection> createState() =>
      _ImageCacheManagementSectionState();
}

class _ImageCacheManagementSectionState
    extends State<_ImageCacheManagementSection> {
  static const String _maxImagesKey = 'image_cache_max_images_per_session';
  static const String _compressionKey = 'image_cache_compression_quality';
  static const String _resolutionKey = 'image_cache_max_resolution';

  int _maxImagesPerSession = 20;
  int _compressionQuality = 85;
  String _maxResolution = '1080p';
  int _cacheSizeBytes = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final cacheSize = await ImageCacheManager.instance.totalSizeBytes();
    if (!mounted) return;
    setState(() {
      _maxImagesPerSession = prefs.getInt(_maxImagesKey) ?? 20;
      _compressionQuality = prefs.getInt(_compressionKey) ?? 85;
      _maxResolution = prefs.getString(_resolutionKey) ?? '1080p';
      _cacheSizeBytes = cacheSize;
    });
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_maxImagesKey, _maxImagesPerSession);
    await prefs.setInt(_compressionKey, _compressionQuality);
    await prefs.setString(_resolutionKey, _maxResolution);
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 MB used';
    final mb = bytes / (1024 * 1024);
    return '${mb.toStringAsFixed(2)} MB used';
  }

  Future<void> _clearAllCache() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Image Cache'),
        content: const Text('모든 캐시 이미지를 삭제합니다. 계속할까요?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    await ImageCacheManager.instance.clearAll();
    await _load();
    if (!mounted) return;
    context.showInfoSnackBar('이미지 캐시를 삭제했습니다.');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle(title: 'Image Cache Management'),
        const SizedBox(height: 8),
        Text(
          '채팅 이미지 캐시 동작을 제어합니다.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Max images per session: $_maxImagesPerSession'),
                Slider(
                  value: _maxImagesPerSession.toDouble(),
                  min: 4,
                  max: 100,
                  divisions: 24,
                  onChanged: (v) {
                    setState(() => _maxImagesPerSession = v.round());
                    _save();
                  },
                ),
                const SizedBox(height: 8),
                Text('Compression quality: $_compressionQuality'),
                Slider(
                  value: _compressionQuality.toDouble(),
                  min: 0,
                  max: 100,
                  divisions: 20,
                  onChanged: (v) {
                    setState(() => _compressionQuality = v.round());
                    _save();
                  },
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: _maxResolution,
                  decoration: const InputDecoration(
                    labelText: 'Max resolution',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: '720p', child: Text('720p')),
                    DropdownMenuItem(value: '1080p', child: Text('1080p')),
                    DropdownMenuItem(value: 'original', child: Text('original')),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _maxResolution = value);
                    _save();
                  },
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: Text(_formatBytes(_cacheSizeBytes))),
                    TextButton.icon(
                      onPressed: _load,
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text('새로고침'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                FilledButton.icon(
                  onPressed: _clearAllCache,
                  icon: const Icon(Icons.delete_sweep_outlined),
                  label: const Text('Clear All Image Cache'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// ============================================================================

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Text(
      title,
      style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
    );
  }
}

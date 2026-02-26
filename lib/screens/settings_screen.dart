// ============================================================================
// ============================================================================
// ============================================================================

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/api_config.dart';
import '../providers/settings_provider.dart';
import '../services/api_service.dart';
import '../widgets/empty_state_view.dart';
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
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('설정'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.api), text: 'API 프리셋'),
            Tab(icon: Icon(Icons.tune), text: '파라미터'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [_ApiPresetsTab(), _ParameterSettingsTab()],
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
              Icon(
                Icons.info_outline,
                size: 18,
                color: colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'API 프리셋을 선택하거나 새로 만들어 사용하세요.\n'
                  '각 프리셋은 Base URL, API Key, 모델, 헤더를 자유롭게 설정할 수 있습니다.',
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
                onPressed: () => _showEditPresetDialog(context, null),
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
                    return _ApiPresetCard(
                      config: config,
                      isActive: isActive,
                      onTap: () =>
                          settingsProvider.setActiveApiConfig(config.id),
                      onEdit: () => _showEditPresetDialog(context, config),
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
    final settingsProvider = context.read<SettingsProvider>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
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
                  Navigator.pop(context);
                  settingsProvider.addApiConfig(ApiConfig.copilotDefault());
                },
              ),
              _TemplateOption(
                icon: Icons.smart_toy,
                title: 'OpenAI',
                subtitle: 'GPT 모델 (sk- API 키 필요)',
                onTap: () {
                  Navigator.pop(context);
                  settingsProvider.addApiConfig(ApiConfig.openaiDefault());
                },
              ),
              _TemplateOption(
                icon: Icons.psychology,
                title: 'Anthropic',
                subtitle: 'Claude 모델 (sk-ant- API 키 필요)',
                onTap: () {
                  Navigator.pop(context);
                  settingsProvider.addApiConfig(ApiConfig.anthropicDefault());
                },
              ),
              _TemplateOption(
                icon: Icons.router,
                title: 'OpenRouter',
                subtitle: '여러 모델 지원 (openrouter.ai)',
                onTap: () {
                  Navigator.pop(context);
                  settingsProvider.addApiConfig(ApiConfig.openRouterDefault());
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
        ],
      ),
    );
  }

  void _showEditPresetDialog(BuildContext context, ApiConfig? existingConfig) {
    showDialog(
      context: context,
      builder: (context) =>
          _ApiPresetEditDialog(existingConfig: existingConfig),
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
  final bool isActive;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ApiPresetCard({
    required this.config,
    required this.isActive,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final hasApiKey = config.apiKey.isNotEmpty;
    final apiKeyStatusColor = hasApiKey
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
              Radio<bool>(
                value: true,
                groupValue: isActive,
                onChanged: (_) => onTap(),
              ),

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
                          hasApiKey ? Icons.check_circle : Icons.warning_amber,
                          size: 14,
                          color: apiKeyStatusColor,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          hasApiKey ? 'API 키 설정됨' : 'API 키 필요',
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

class _ApiPresetEditDialog extends StatefulWidget {
  final ApiConfig? existingConfig;

  const _ApiPresetEditDialog({this.existingConfig});

  @override
  State<_ApiPresetEditDialog> createState() => _ApiPresetEditDialogState();
}

class _ApiPresetEditDialogState extends State<_ApiPresetEditDialog> {
  late TextEditingController _nameController;
  late TextEditingController _baseUrlController;
  late TextEditingController _apiKeyController;
  late TextEditingController _modelController;
  late Map<String, String> _customHeaders;
  bool _showAdvanced = false;
  bool _isTesting = false;
  String? _testResult;

  late ApiFormat _format;
  late bool _useStreaming;
  late bool _hasFirstSystemPrompt;
  late bool _requiresAlternateRole;
  late bool _mergeSystemPrompts;
  late bool _mustStartWithUserInput;
  late bool _useMaxOutputTokens;

  @override
  void initState() {
    super.initState();
    final config = widget.existingConfig;
    _nameController = TextEditingController(text: config?.name ?? '새 프리셋');
    _baseUrlController = TextEditingController(
      text: config?.baseUrl ?? 'https://api.openai.com/v1/chat/completions',
    );
    _apiKeyController = TextEditingController(text: config?.apiKey ?? '');
    _modelController = TextEditingController(
      text: config?.modelName ?? 'gpt-4o',
    );
    _customHeaders = Map.from(config?.customHeaders ?? {});

    _format = config?.format ?? ApiFormat.openAICompatible;
    _useStreaming = config?.useStreaming ?? true;
    _hasFirstSystemPrompt = config?.hasFirstSystemPrompt ?? true;
    _requiresAlternateRole = config?.requiresAlternateRole ?? true;
    _mergeSystemPrompts = config?.mergeSystemPrompts ?? false;
    _mustStartWithUserInput = config?.mustStartWithUserInput ?? false;
    _useMaxOutputTokens = config?.useMaxOutputTokens ?? false;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _baseUrlController.dispose();
    _apiKeyController.dispose();
    _modelController.dispose();
    super.dispose();
  }

  Future<void> _testConnection() async {
    setState(() {
      _isTesting = true;
      _testResult = null;
    });

    final testConfig = ApiConfig.custom(
      name: _nameController.text.trim(),
      baseUrl: _baseUrlController.text.trim(),
      apiKey: _apiKeyController.text,
      modelName: _modelController.text.trim(),
      customHeaders: _customHeaders,
    ).copyWith(format: _format);

    debugPrint('>>> 연결 테스트 시작: ${testConfig.baseUrl}');

    final apiService = ApiService();
    final (success, message) = await apiService.testConnection(testConfig);

    setState(() {
      _isTesting = false;
      _testResult = success ? '✅ $message' : '❌ $message';
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        constraints: const BoxConstraints(maxHeight: 700),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.existingConfig == null ? '새 프리셋 만들기' : '프리셋 편집',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),

            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: '프리셋 이름',
                        hintText: '예: My OpenAI, Copilot...',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.label),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Base URL
                    TextFormField(
                      controller: _baseUrlController,
                      decoration: const InputDecoration(
                        labelText: 'Base URL',
                        hintText: 'https://api.openai.com/v1/chat/completions',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.link),
                        helperText: 'API 엔드포인트 URL (⭐ 변경 시 반드시 저장)',
                      ),
                    ),
                    const SizedBox(height: 16),

                    // API Key
                    TextFormField(
                      controller: _apiKeyController,
                      decoration: const InputDecoration(
                        labelText: 'API Key',
                        hintText: 'sk-..., gho_...',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.key),
                        helperText: '여러 키는 줄바꿈으로 구분',
                      ),
                      obscureText: true,
                      maxLines: 1,
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _modelController,
                      decoration: const InputDecoration(
                        labelText: '모델',
                        hintText: 'gpt-4o, claude-3-opus...',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.memory),
                      ),
                    ),
                    const SizedBox(height: 16),

                    DropdownButtonFormField<ApiFormat>(
                      value: _format,
                      decoration: const InputDecoration(
                        labelText: 'API 규격',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.api),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: ApiFormat.openAICompatible,
                          child: Text('OpenAI Compatible'),
                        ),
                        DropdownMenuItem(
                          value: ApiFormat.anthropic,
                          child: Text('Anthropic Claude'),
                        ),
                        DropdownMenuItem(
                          value: ApiFormat.openRouter,
                          child: Text('OpenRouter'),
                        ),
                        DropdownMenuItem(
                          value: ApiFormat.google,
                          child: Text('Google Gemini'),
                        ),
                        DropdownMenuItem(
                          value: ApiFormat.custom,
                          child: Text('Custom'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) setState(() => _format = value);
                      },
                    ),
                    const SizedBox(height: 16),

                    InkWell(
                      onTap: () =>
                          setState(() => _showAdvanced = !_showAdvanced),
                      child: Row(
                        children: [
                          Icon(
                            _showAdvanced
                                ? Icons.expand_less
                                : Icons.expand_more,
                          ),
                          const SizedBox(width: 8),
                          const Text('고급 설정'),
                        ],
                      ),
                    ),

                    if (_showAdvanced) ...[
                      const SizedBox(height: 12),
                      _buildAdvancedOptions(),
                      const SizedBox(height: 12),
                      _buildHeadersEditor(),
                    ],

                    if (_testResult != null) ...[
                      const SizedBox(height: 16),
                      Builder(
                        builder: (context) {
                          final isSuccess = _testResult!.startsWith('✅');
                          final statusBackground = isSuccess
                              ? colorScheme.tertiaryContainer.withValues(
                                  alpha: 0.5,
                                )
                              : colorScheme.errorContainer.withValues(
                                  alpha: 0.65,
                                );
                          final statusBorder = isSuccess
                              ? colorScheme.tertiary.withValues(alpha: 0.65)
                              : colorScheme.error.withValues(alpha: 0.7);
                          final statusTextColor = isSuccess
                              ? colorScheme.onTertiaryContainer
                              : colorScheme.onErrorContainer;

                          return Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: statusBackground,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: statusBorder),
                            ),
                            child: Text(
                              _testResult!,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: statusTextColor,
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            Wrap(
              alignment: WrapAlignment.end,
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: _isTesting ? null : _testConnection,
                  icon: _isTesting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.wifi_tethering, size: 18),
                  label: Text(_isTesting ? '테스트 중...' : '연결 테스트'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('취소'),
                ),
                ElevatedButton(
                  onPressed: _saveConfig,
                  child: Text(widget.existingConfig == null ? '추가' : '저장'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdvancedOptions() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.secondaryContainer.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.45),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '고급 옵션',
            style: theme.textTheme.titleSmall?.copyWith(
              color: colorScheme.onSecondaryContainer,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          CheckboxListTile(
            title: const Text('스트리밍 사용'),
            subtitle: const Text('응답을 실시간으로 표시'),
            value: _useStreaming,
            onChanged: (v) => setState(() => _useStreaming = v ?? true),
            dense: true,
          ),
          CheckboxListTile(
            title: const Text('첫 시스템 프롬프트 포함'),
            subtitle: const Text('시스템 메시지를 첫 번째로'),
            value: _hasFirstSystemPrompt,
            onChanged: (v) => setState(() => _hasFirstSystemPrompt = v ?? true),
            dense: true,
          ),
          CheckboxListTile(
            title: const Text('역할 교대 필수'),
            subtitle: const Text('user-assistant 번갈아 배치'),
            value: _requiresAlternateRole,
            onChanged: (v) =>
                setState(() => _requiresAlternateRole = v ?? true),
            dense: true,
          ),
          CheckboxListTile(
            title: const Text('시스템 프롬프트 합치기'),
            subtitle: const Text('여러 system을 하나로'),
            value: _mergeSystemPrompts,
            onChanged: (v) => setState(() => _mergeSystemPrompts = v ?? false),
            dense: true,
          ),
          CheckboxListTile(
            title: const Text('사용자 입력으로 시작 필수'),
            value: _mustStartWithUserInput,
            onChanged: (v) =>
                setState(() => _mustStartWithUserInput = v ?? false),
            dense: true,
          ),
          CheckboxListTile(
            title: const Text('max_output_tokens 사용'),
            subtitle: const Text('max_tokens 대신 사용'),
            value: _useMaxOutputTokens,
            onChanged: (v) => setState(() => _useMaxOutputTokens = v ?? false),
            dense: true,
          ),
        ],
      ),
    );
  }

  Widget _buildHeadersEditor() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.45),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '커스텀 HTTP 헤더',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextButton.icon(
                onPressed: _addHeader,
                icon: const Icon(Icons.add, size: 16),
                label: const Text('추가'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_customHeaders.isEmpty)
            Text(
              '커스텀 헤더가 없습니다',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            )
          else
            ..._customHeaders.entries.map((entry) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: Text(
                        entry.key,
                        style: const TextStyle(fontFamily: 'monospace'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 3,
                      child: Text(
                        entry.value,
                        style: const TextStyle(fontFamily: 'monospace'),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, size: 18),
                      onPressed: () {
                        setState(() => _customHeaders.remove(entry.key));
                      },
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  void _addHeader() {
    final keyController = TextEditingController();
    final valueController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('헤더 추가'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: keyController,
              decoration: const InputDecoration(
                labelText: '헤더 이름',
                hintText: 'X-Custom-Header',
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: valueController,
              decoration: const InputDecoration(
                labelText: '헤더 값',
                hintText: 'value',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () {
              if (keyController.text.isNotEmpty) {
                setState(() {
                  _customHeaders[keyController.text] = valueController.text;
                });
              }
              Navigator.pop(context);
            },
            child: const Text('추가'),
          ),
        ],
      ),
    );
  }

  void _saveConfig() {
    final settingsProvider = context.read<SettingsProvider>();

    if (_nameController.text.trim().isEmpty ||
        _baseUrlController.text.trim().isEmpty ||
        _modelController.text.trim().isEmpty) {
      context.showErrorSnackBar('이름, Base URL, 모델은 필수 입력 항목입니다.');
      return;
    }

    final newConfig =
        ApiConfig.custom(
          id: widget.existingConfig?.id,
          name: _nameController.text.trim(),
          baseUrl: _baseUrlController.text.trim(),
          apiKey: _apiKeyController.text,
          modelName: _modelController.text.trim(),
          customHeaders: _customHeaders,
        ).copyWith(
          format: _format,
          useStreaming: _useStreaming,
          hasFirstSystemPrompt: _hasFirstSystemPrompt,
          requiresAlternateRole: _requiresAlternateRole,
          mergeSystemPrompts: _mergeSystemPrompts,
          mustStartWithUserInput: _mustStartWithUserInput,
          useMaxOutputTokens: _useMaxOutputTokens,
        );

    debugPrint('╔════════════════════════════════════════════════════════════');
    debugPrint('║ >>> API Config 저장');
    debugPrint('║ >>> ID: ${newConfig.id}');
    debugPrint('║ >>> Name: ${newConfig.name}');
    debugPrint('║ >>> URL: ${newConfig.baseUrl}');
    debugPrint('║ >>> Model: ${newConfig.modelName}');
    debugPrint('║ >>> Format: ${newConfig.format.name}');
    debugPrint('╚════════════════════════════════════════════════════════════');

    if (widget.existingConfig == null) {
      settingsProvider.addApiConfig(newConfig);
    } else {
      settingsProvider.updateApiConfig(newConfig);
    }

    Navigator.pop(context);

    context.showInfoSnackBar('${newConfig.name} 프리셋이 저장되었습니다.');
  }
}

// ============================================================================
// ============================================================================

class _ParameterSettingsTab extends StatelessWidget {
  const _ParameterSettingsTab();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final settingsProvider = context.watch<SettingsProvider>();
    final settings = settingsProvider.settings;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _SectionTitle(title: '생성 파라미터'),
        const SizedBox(height: 8),
        Text(
          'AI가 텍스트를 생성할 때 사용하는 설정입니다.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),

        const SizedBox(height: 16),

        _ParameterSlider(
          label: 'Temperature (온도)',
          value: settings.temperature,
          min: 0.0,
          max: 2.0,
          divisions: 20,
          description: '높을수록 창의적이고 다양한 응답, 낮을수록 일관적인 응답',
          onChanged: settingsProvider.setTemperature,
        ),

        const SizedBox(height: 16),

        _ParameterSlider(
          label: 'Top-P',
          value: settings.topP,
          min: 0.0,
          max: 1.0,
          divisions: 20,
          description: '단어 선택의 다양성을 조절합니다 (보통 1.0 권장)',
          onChanged: settingsProvider.setTopP,
        ),

        const SizedBox(height: 16),

        TextFormField(
          initialValue: settings.maxTokens.toString(),
          decoration: const InputDecoration(
            labelText: 'Max Tokens (최대 토큰)',
            hintText: '1024',
            border: OutlineInputBorder(),
            helperText: 'AI 응답의 최대 길이 (1000 토큰 ≈ 한글 500자)',
          ),
          keyboardType: TextInputType.number,
          onChanged: (value) {
            final int? tokens = int.tryParse(value);
            if (tokens != null && tokens > 0) {
              settingsProvider.setMaxTokens(tokens);
            }
          },
        ),

        const SizedBox(height: 16),

        _ParameterSlider(
          label: 'Frequency Penalty (빈도 패널티)',
          value: settings.frequencyPenalty,
          min: -2.0,
          max: 2.0,
          divisions: 40,
          description: '같은 단어의 반복을 억제합니다',
          onChanged: settingsProvider.setFrequencyPenalty,
        ),

        const SizedBox(height: 16),

        _ParameterSlider(
          label: 'Presence Penalty (존재 패널티)',
          value: settings.presencePenalty,
          min: -2.0,
          max: 2.0,
          divisions: 40,
          description: '새로운 주제로 대화를 유도합니다',
          onChanged: settingsProvider.setPresencePenalty,
        ),

        // Note: Additional/Jailbreak prompts removed in v2.0.6
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

class _ParameterSlider extends StatelessWidget {
  final String label;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final String description;
  final ValueChanged<double> onChanged;

  const _ParameterSlider({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.description,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
            Text(
              value.toStringAsFixed(2),
              style: TextStyle(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        Slider(
          value: value,
          min: min,
          max: max,
          divisions: divisions,
          onChanged: onChanged,
        ),
        Text(
          description,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

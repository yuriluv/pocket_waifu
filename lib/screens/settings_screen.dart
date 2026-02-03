// ============================================================================
// 설정 화면 (Settings Screen) - v2
// ============================================================================
// 이 파일은 앱의 설정 화면 UI를 담당합니다.
// API 프리셋 관리, 생성 파라미터 등을 변경할 수 있습니다.
// SillyTavern 스타일의 범용 API 설정 시스템을 사용합니다.
// ============================================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/api_config.dart';
import '../providers/settings_provider.dart';

/// 설정 화면 위젯
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with SingleTickerProviderStateMixin {
  // 탭 컨트롤러 - API 프리셋 / 파라미터 설정 탭
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
        children: const [
          _ApiPresetsTab(),
          _ParameterSettingsTab(),
        ],
      ),
    );
  }
}

// ============================================================================
// API 프리셋 탭 (새로운 범용 시스템)
// ============================================================================

class _ApiPresetsTab extends StatelessWidget {
  const _ApiPresetsTab();

  @override
  Widget build(BuildContext context) {
    final settingsProvider = context.watch<SettingsProvider>();
    final apiConfigs = settingsProvider.apiConfigs;
    final activeConfigId = settingsProvider.activeApiConfigId;

    return Column(
      children: [
        // 상단 안내문
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          color: Colors.blue.withValues(alpha: 0.1),
          child: Row(
            children: [
              const Icon(Icons.info_outline, size: 18, color: Colors.blue),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'API 프리셋을 선택하거나 새로 만들어 사용하세요.\n'
                  '각 프리셋은 Base URL, API Key, 모델, 헤더를 자유롭게 설정할 수 있습니다.',
                  style: TextStyle(fontSize: 12, color: Colors.blue[700]),
                ),
              ),
            ],
          ),
        ),

        // 프리셋 추가 버튼
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

        // 프리셋 목록
        Expanded(
          child: apiConfigs.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.api, size: 64, color: Colors.grey[300]),
                      const SizedBox(height: 16),
                      Text(
                        'API 프리셋이 없습니다',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        '위 버튼을 눌러 프리셋을 추가하세요',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
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
                      onTap: () => settingsProvider.setActiveApiConfig(config.id),
                      onEdit: () => _showEditPresetDialog(context, config),
                      onDelete: () => _confirmDeletePreset(context, config),
                    );
                  },
                ),
        ),

        // 하단 사용자 이름 설정
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            border: Border(top: BorderSide(color: Colors.grey[200]!)),
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

  /// 프리셋 템플릿 선택 다이얼로그
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

  /// 프리셋 편집 다이얼로그 (신규 또는 수정)
  void _showEditPresetDialog(BuildContext context, ApiConfig? existingConfig) {
    showDialog(
      context: context,
      builder: (context) => _ApiPresetEditDialog(existingConfig: existingConfig),
    );
  }

  /// 프리셋 삭제 확인
  void _confirmDeletePreset(BuildContext context, ApiConfig config) {
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
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
  }
}

/// 템플릿 선택 옵션 위젯
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

/// API 프리셋 카드 위젯
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
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      elevation: isActive ? 3 : 1,
      color: isActive ? Colors.blue.withValues(alpha: 0.05) : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: isActive
            ? BorderSide(color: Theme.of(context).colorScheme.primary, width: 2)
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // 선택 라디오
              Radio<bool>(
                value: true,
                groupValue: isActive,
                onChanged: (_) => onTap(),
              ),

              // 프리셋 정보
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
                              color: Colors.green.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              '기본',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.green,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      config.modelName,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      config.baseUrl,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[500],
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    // API 키 상태
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          config.apiKey.isEmpty
                              ? Icons.warning_amber
                              : Icons.check_circle,
                          size: 14,
                          color: config.apiKey.isEmpty
                              ? Colors.orange
                              : Colors.green,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          config.apiKey.isEmpty
                              ? 'API 키 필요'
                              : 'API 키 설정됨',
                          style: TextStyle(
                            fontSize: 11,
                            color: config.apiKey.isEmpty
                                ? Colors.orange
                                : Colors.green,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // 편집/삭제 버튼
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
                    color: Colors.red[400],
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

/// API 프리셋 편집 다이얼로그
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

  @override
  void initState() {
    super.initState();
    final config = widget.existingConfig;
    _nameController = TextEditingController(text: config?.name ?? '새 프리셋');
    _baseUrlController = TextEditingController(
      text: config?.baseUrl ?? 'https://api.openai.com/v1/chat/completions',
    );
    _apiKeyController = TextEditingController(text: config?.apiKey ?? '');
    _modelController = TextEditingController(text: config?.modelName ?? 'gpt-4o');
    _customHeaders = Map.from(config?.customHeaders ?? {});
  }

  @override
  void dispose() {
    _nameController.dispose();
    _baseUrlController.dispose();
    _apiKeyController.dispose();
    _modelController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        constraints: const BoxConstraints(maxHeight: 600),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 헤더
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.existingConfig == null ? '새 프리셋 만들기' : '프리셋 편집',
                  style: const TextStyle(
                    fontSize: 18,
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

            // 폼 필드
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 프리셋 이름
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
                        helperText: 'API 엔드포인트 URL',
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
                        helperText: '비밀번호처럼 안전하게 저장됩니다',
                      ),
                      obscureText: true,
                    ),
                    const SizedBox(height: 16),

                    // 모델
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

                    // 고급 설정 토글
                    InkWell(
                      onTap: () => setState(() => _showAdvanced = !_showAdvanced),
                      child: Row(
                        children: [
                          Icon(
                            _showAdvanced
                                ? Icons.expand_less
                                : Icons.expand_more,
                          ),
                          const SizedBox(width: 8),
                          const Text('고급 설정 (커스텀 헤더)'),
                        ],
                      ),
                    ),

                    if (_showAdvanced) ...[
                      const SizedBox(height: 12),
                      _buildHeadersEditor(),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // 버튼
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('취소'),
                ),
                const SizedBox(width: 8),
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

  Widget _buildHeadersEditor() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '커스텀 HTTP 헤더',
                style: TextStyle(fontWeight: FontWeight.bold),
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
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
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
    
    final newConfig = ApiConfig.custom(
      id: widget.existingConfig?.id,  // null이면 새 ID 생성
      name: _nameController.text.trim(),
      baseUrl: _baseUrlController.text.trim(),
      apiKey: _apiKeyController.text,
      modelName: _modelController.text.trim(),
      customHeaders: _customHeaders,
    );

    if (widget.existingConfig == null) {
      settingsProvider.addApiConfig(newConfig);
    } else {
      settingsProvider.updateApiConfig(newConfig);
    }

    Navigator.pop(context);
  }
}

// ============================================================================
// 파라미터 설정 탭
// ============================================================================

class _ParameterSettingsTab extends StatelessWidget {
  const _ParameterSettingsTab();

  @override
  Widget build(BuildContext context) {
    final settingsProvider = context.watch<SettingsProvider>();
    final settings = settingsProvider.settings;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // === 생성 파라미터 ===
        _SectionTitle(title: '생성 파라미터'),
        const SizedBox(height: 8),
        Text(
          'AI가 텍스트를 생성할 때 사용하는 설정입니다.',
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),

        const SizedBox(height: 16),

        // Temperature 슬라이더
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

        // Top-P 슬라이더
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

        // Max Tokens 입력
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

        // Frequency Penalty 슬라이더
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

        // Presence Penalty 슬라이더
        _ParameterSlider(
          label: 'Presence Penalty (존재 패널티)',
          value: settings.presencePenalty,
          min: -2.0,
          max: 2.0,
          divisions: 40,
          description: '새로운 주제로 대화를 유도합니다',
          onChanged: settingsProvider.setPresencePenalty,
        ),

        const SizedBox(height: 24),

        // === 프롬프트 설정 ===
        _SectionTitle(title: '추가 프롬프트'),
        const SizedBox(height: 8),

        // 시스템 프롬프트
        TextFormField(
          initialValue: settings.systemPrompt,
          decoration: const InputDecoration(
            labelText: '추가 시스템 프롬프트',
            hintText: 'AI에게 추가로 전달할 지시사항...',
            border: OutlineInputBorder(),
            alignLabelWithHint: true,
            helperText: '캐릭터 설정 외에 추가로 전달할 지시사항',
          ),
          maxLines: 4,
          onChanged: settingsProvider.setSystemPrompt,
        ),

        const SizedBox(height: 16),

        // 탈옥 프롬프트 사용 여부
        SwitchListTile(
          title: const Text('탈옥 프롬프트 사용'),
          subtitle: Text(
            '주의: 이 기능은 AI의 안전 제한을 우회하려는 시도입니다',
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
          value: settings.useJailbreak,
          onChanged: settingsProvider.setUseJailbreak,
        ),

        // 탈옥 프롬프트 입력
        if (settings.useJailbreak) ...[
          const SizedBox(height: 8),
          TextFormField(
            initialValue: settings.jailbreakPrompt,
            decoration: const InputDecoration(
              labelText: '탈옥 프롬프트',
              hintText: '특별 지시사항...',
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
            maxLines: 4,
            onChanged: settingsProvider.setJailbreakPrompt,
          ),
        ],
      ],
    );
  }
}

// ============================================================================
// 공통 위젯
// ============================================================================

/// 섹션 제목 위젯
class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
      ),
    );
  }
}

/// 파라미터 슬라이더 위젯
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 라벨과 현재 값
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
            Text(
              value.toStringAsFixed(2),
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        // 슬라이더
        Slider(
          value: value,
          min: min,
          max: max,
          divisions: divisions,
          onChanged: onChanged,
        ),
        // 설명
        Text(
          description,
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
      ],
    );
  }
}

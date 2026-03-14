import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/api_config.dart';
import '../models/oauth_account.dart';
import '../providers/settings_provider.dart';
import '../services/api_service.dart';
import '../utils/api_preset_parameter_policy.dart';
import '../utils/ui_feedback.dart';
import '../widgets/oauth_management_widgets.dart';

enum _ApiPresetEditorKind { standard, codexOAuth, geminiOAuth }

class ApiPresetEditorScreen extends StatefulWidget {
  const ApiPresetEditorScreen({
    super.key,
    this.existingConfig,
    this.seedConfig,
  });

  final ApiConfig? existingConfig;
  final ApiConfig? seedConfig;

  @override
  State<ApiPresetEditorScreen> createState() => _ApiPresetEditorScreenState();
}

class _ApiPresetEditorScreenState extends State<ApiPresetEditorScreen> {
  late final ApiConfig _draft;
  late final TextEditingController _nameController;
  late final TextEditingController _baseUrlController;
  late final TextEditingController _apiKeyController;
  late final TextEditingController _modelController;
  late _ApiPresetEditorKind _kind;
  late ApiFormat _format;
  late bool _useStreaming;
  late bool _hasFirstSystemPrompt;
  late bool _requiresAlternateRole;
  late bool _mergeSystemPrompts;
  late bool _mustStartWithUserInput;
  late bool _useMaxOutputTokens;
  late Map<String, String> _customHeaders;
  late Map<String, dynamic> _additionalParams;
  String? _selectedAccountId;
  bool _isTesting = false;
  bool _isSaving = false;
  String? _testResult;

  @override
  void initState() {
    super.initState();
    final seed = widget.existingConfig ?? widget.seedConfig ?? ApiConfig.custom();
    _draft = seed.copyWith();
    _kind = _inferKind(_draft);
    _format = _normalizeStandardFormat(_draft.format);
    _nameController = TextEditingController(text: _draft.name);
    _baseUrlController = TextEditingController(text: _draft.baseUrl);
    _apiKeyController = TextEditingController(text: _draft.apiKey);
    _modelController = TextEditingController(text: _draft.modelName);
    _useStreaming = _draft.useStreaming;
    _hasFirstSystemPrompt = _draft.hasFirstSystemPrompt;
    _requiresAlternateRole = _draft.requiresAlternateRole;
    _mergeSystemPrompts = _draft.mergeSystemPrompts;
    _mustStartWithUserInput = _draft.mustStartWithUserInput;
    _useMaxOutputTokens = _draft.useMaxOutputTokens;
    _customHeaders = Map<String, String>.from(_draft.customHeaders);
    _additionalParams = Map<String, dynamic>.from(
      ApiPresetParameterPolicy.sanitizeAdditionalParams(_draft),
    );
    _selectedAccountId = _draft.oauthAccountId;
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
    final theme = Theme.of(context);
    final settingsProvider = context.watch<SettingsProvider>();
    final accounts = _accountsForKind(settingsProvider);
    _normalizeAccountSelection(accounts);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existingConfig == null ? '새 API 프리셋' : 'API 프리셋 편집'),
        actions: [
          TextButton.icon(
            onPressed: _isTesting ? null : () => _testConnection(settingsProvider),
            icon: _isTesting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.wifi_tethering),
            label: Text(_isTesting ? '테스트 중' : '연결 테스트'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                children: [
                  _EditorHeroCard(kind: _kind),
                  const SizedBox(height: 16),
                  _EditorSection(
                    title: '프리셋 유형',
                    description: '프리셋이 사용할 인증 방식과 요청 계약을 먼저 고릅니다.',
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _ApiPresetEditorKind.values.map((kind) {
                        return ChoiceChip(
                          label: Text(_kindLabel(kind)),
                          selected: _kind == kind,
                          onSelected: (selected) {
                            if (!selected) return;
                            setState(() => _applyKind(kind, settingsProvider));
                          },
                        );
                      }).toList(growable: false),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildBasicsSection(theme),
                  const SizedBox(height: 16),
                  _buildAuthSection(settingsProvider, accounts),
                  const SizedBox(height: 16),
                  _buildParametersSection(theme),
                  const SizedBox(height: 16),
                  _buildAdvancedSection(theme),
                  const SizedBox(height: 16),
                  _buildHeadersSection(theme),
                  if (_testResult != null) ...[
                    const SizedBox(height: 16),
                    _TestResultCard(message: _testResult!),
                  ],
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                border: Border(
                  top: BorderSide(
                    color: theme.colorScheme.outlineVariant.withValues(alpha: 0.45),
                  ),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isSaving ? null : () => Navigator.pop(context),
                      child: const Text('취소'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _isSaving ? null : () => _save(settingsProvider),
                      icon: _isSaving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.save_outlined),
                      label: Text(_isSaving ? '저장 중...' : '프리셋 저장'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBasicsSection(ThemeData theme) {
    return _EditorSection(
      title: '기본 정보',
      description: '이름, 모델, 엔드포인트를 정합니다. OAuth 프리셋은 엔드포인트가 고정됩니다.',
      child: Column(
        children: [
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: '프리셋 이름',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.label_outline),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _modelController,
            decoration: const InputDecoration(
              labelText: '모델',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.memory_outlined),
            ),
          ),
          const SizedBox(height: 12),
          if (_kind == _ApiPresetEditorKind.standard) ...[
            DropdownButtonFormField<ApiFormat>(
              initialValue: _format,
              decoration: const InputDecoration(
                labelText: 'API 규격',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.api_outlined),
              ),
              items: ApiPresetParameterPolicy.supportedStandardFormats
                  .map(
                    (format) => DropdownMenuItem<ApiFormat>(
                      value: format,
                      child: Text(_formatLabel(format)),
                    ),
                  )
                  .toList(growable: false),
              onChanged: (value) {
                if (value == null) return;
                setState(() => _format = value);
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _baseUrlController,
              decoration: const InputDecoration(
                labelText: 'Base URL',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.link_outlined),
              ),
            ),
          ] else ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: theme.colorScheme.outlineVariant.withValues(alpha: 0.55),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '고정 엔드포인트',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 6),
                  SelectableText(
                    _baseUrlController.text,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAuthSection(
    SettingsProvider settingsProvider,
    List<OAuthAccount> accounts,
  ) {
    final theme = Theme.of(context);
    final isOAuth = _kind != _ApiPresetEditorKind.standard;

    return _EditorSection(
      title: '인증',
      description: isOAuth
          ? '프리셋이 연결할 OAuth 계정을 고릅니다.'
          : '일반 프리셋은 API 키를 직접 저장합니다.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isOAuth) ...[
            TextField(
              controller: _apiKeyController,
              decoration: const InputDecoration(
                labelText: 'API Key',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.key_outlined),
                helperText: '여러 키는 줄바꿈으로 구분할 수 있습니다.',
              ),
              obscureText: true,
            ),
          ] else if (accounts.isEmpty) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.errorContainer.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${_oauthProviderForKind(_kind).displayName} 계정이 없습니다.',
                    style: theme.textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'OAuth 탭에서 계정을 먼저 추가하거나, 여기서 바로 로그인할 수 있습니다.',
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () => _createOAuthAccount(settingsProvider),
                    icon: const Icon(Icons.person_add_alt_1),
                    label: const Text('OAuth 계정 추가'),
                  ),
                ],
              ),
            ),
          ] else ...[
            DropdownButtonFormField<String>(
              initialValue: _selectedAccountId,
              decoration: const InputDecoration(
                labelText: '연결할 OAuth 계정',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.verified_user_outlined),
              ),
              items: accounts.map((account) {
                return DropdownMenuItem<String>(
                  value: account.id,
                  child: Text(account.displayLabel),
                );
              }).toList(growable: false),
              onChanged: (value) => setState(() => _selectedAccountId = value),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _createOAuthAccount(settingsProvider),
                  icon: const Icon(Icons.person_add_alt_1),
                  label: const Text('새 OAuth 계정 추가'),
                ),
                OutlinedButton.icon(
                  onPressed: () async {
                    await settingsProvider.reloadOAuthAccounts();
                    if (!mounted) return;
                    setState(() {});
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('계정 목록 새로고침'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildParametersSection(ThemeData theme) {
    if (_kind == _ApiPresetEditorKind.codexOAuth) {
      return _EditorSection(
        title: 'Codex 파라미터 가이드',
        description: 'Codex는 일반 OpenAI 호환 프리셋보다 훨씬 엄격해서 고정값과 금지값을 따로 안내합니다.',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _GuidanceList(
              title: '고정값',
              items: ApiPresetParameterPolicy.codexFixedValueGuidance(),
            ),
            const SizedBox(height: 12),
            _GuidanceList(
              title: '숨김/차단되는 값',
              items: ApiPresetParameterPolicy.codexUnsupportedGuidance(),
            ),
          ],
        ),
      );
    }

    return _EditorSection(
      title: '프리셋 전용 생성 파라미터',
      description: '이 프리셋이 사용할 생성 파라미터입니다. 더 이상 전역 파라미터 탭을 덮어쓰지 않습니다.',
      child: Column(
        children: [
          _PresetSliderField(
            label: 'Temperature',
            description: '높을수록 다양하고 창의적입니다.',
            min: 0,
            max: 2,
            divisions: 20,
            value: _readDouble(ApiPresetParameterPolicy.temperatureKey, 0.9),
            onChanged: (value) => _setDouble(ApiPresetParameterPolicy.temperatureKey, value),
          ),
          const SizedBox(height: 16),
          _PresetSliderField(
            label: 'Top-P',
            description: '후보 토큰 풀의 폭을 조절합니다.',
            min: 0,
            max: 1,
            divisions: 20,
            value: _readDouble(ApiPresetParameterPolicy.topPKey, 1.0),
            onChanged: (value) => _setDouble(ApiPresetParameterPolicy.topPKey, value),
          ),
          const SizedBox(height: 16),
          TextFormField(
            initialValue: _readInt(ApiPresetParameterPolicy.maxTokensKey, 1024)
                .toString(),
            decoration: const InputDecoration(
              labelText: 'Max Tokens',
              border: OutlineInputBorder(),
              helperText: '프리셋별 최대 응답 길이입니다.',
            ),
            keyboardType: TextInputType.number,
            onChanged: (value) {
              final parsed = int.tryParse(value);
              if (parsed != null && parsed > 0) {
                _additionalParams[ApiPresetParameterPolicy.maxTokensKey] = parsed;
              }
            },
          ),
          const SizedBox(height: 16),
          _PresetSliderField(
            label: 'Frequency Penalty',
            description: '같은 단어 반복을 억제합니다.',
            min: -2,
            max: 2,
            divisions: 40,
            value: _readDouble(ApiPresetParameterPolicy.frequencyPenaltyKey, 0.0),
            onChanged: (value) => _setDouble(ApiPresetParameterPolicy.frequencyPenaltyKey, value),
          ),
          const SizedBox(height: 16),
          _PresetSliderField(
            label: 'Presence Penalty',
            description: '새 주제로 전환하려는 성향을 높입니다.',
            min: -2,
            max: 2,
            divisions: 40,
            value: _readDouble(ApiPresetParameterPolicy.presencePenaltyKey, 0.0),
            onChanged: (value) => _setDouble(ApiPresetParameterPolicy.presencePenaltyKey, value),
          ),
        ],
      ),
    );
  }

  Widget _buildAdvancedSection(ThemeData theme) {
    return _EditorSection(
      title: '고급 동작',
      description: '메시지 포맷과 호환성 플래그입니다. Codex에서 고정되는 값은 잠깁니다.',
      child: Column(
        children: [
          SwitchListTile.adaptive(
            value: _kind == _ApiPresetEditorKind.codexOAuth ? true : _useStreaming,
            onChanged: _kind == _ApiPresetEditorKind.codexOAuth
                ? null
                : (value) => setState(() => _useStreaming = value),
            title: const Text('스트리밍 사용'),
            subtitle: Text(
              _kind == _ApiPresetEditorKind.codexOAuth
                  ? 'Codex는 `stream=true`로 고정됩니다.'
                  : '응답을 실시간으로 표시합니다.',
            ),
          ),
          SwitchListTile.adaptive(
            value: _hasFirstSystemPrompt,
            onChanged: (value) => setState(() => _hasFirstSystemPrompt = value),
            title: const Text('첫 시스템 프롬프트 포함'),
          ),
          SwitchListTile.adaptive(
            value: _requiresAlternateRole,
            onChanged: (value) => setState(() => _requiresAlternateRole = value),
            title: const Text('역할 교대 필수'),
          ),
          SwitchListTile.adaptive(
            value: _mergeSystemPrompts,
            onChanged: (value) => setState(() => _mergeSystemPrompts = value),
            title: const Text('시스템 프롬프트 합치기'),
          ),
          SwitchListTile.adaptive(
            value: _mustStartWithUserInput,
            onChanged: (value) => setState(() => _mustStartWithUserInput = value),
            title: const Text('사용자 입력으로 시작 필수'),
          ),
          if (_kind != _ApiPresetEditorKind.codexOAuth)
            SwitchListTile.adaptive(
              value: _useMaxOutputTokens,
              onChanged: (value) => setState(() => _useMaxOutputTokens = value),
              title: const Text('max_output_tokens 사용'),
            ),
        ],
      ),
    );
  }

  Widget _buildHeadersSection(ThemeData theme) {
    final autoManagedHeaders = _kind == _ApiPresetEditorKind.codexOAuth
        ? const [
            'Authorization',
            'Content-Type',
            'Accept',
            'originator',
            'OpenAI-Beta',
            'User-Agent',
            'ChatGPT-Account-Id',
          ]
        : const <String>[];
    return _EditorSection(
      title: '커스텀 헤더',
      description: '필요한 헤더만 저장하세요. Codex 자동 헤더는 여기서 편집하지 않습니다.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (autoManagedHeaders.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: autoManagedHeaders
                    .map((header) => Chip(label: Text(header)))
                    .toList(growable: false),
              ),
            ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: _addHeader,
              icon: const Icon(Icons.add),
              label: const Text('헤더 추가'),
            ),
          ),
          if (_customHeaders.isEmpty)
            Text(
              '커스텀 헤더가 없습니다.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            )
          else
            ..._customHeaders.entries.map((entry) {
              return ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(entry.key, style: const TextStyle(fontFamily: 'monospace')),
                subtitle: Text(
                  entry.value,
                  style: const TextStyle(fontFamily: 'monospace'),
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => setState(() => _customHeaders.remove(entry.key)),
                ),
              );
            }),
        ],
      ),
    );
  }

  Future<void> _createOAuthAccount(SettingsProvider settingsProvider) async {
    await showOAuthAccountLoginDialog(context);
    await settingsProvider.reloadOAuthAccounts();
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _testConnection(SettingsProvider settingsProvider) async {
    final config = _buildConfig(settingsProvider, validateOnly: true);
    if (config == null) {
      return;
    }
    setState(() {
      _isTesting = true;
      _testResult = null;
    });
    final apiService = ApiService();
    final (success, message) = await apiService.testConnection(config);
    if (!mounted) return;
    setState(() {
      _isTesting = false;
      _testResult = success ? '✅ $message' : '❌ $message';
    });
  }

  Future<void> _save(SettingsProvider settingsProvider) async {
    final config = _buildConfig(settingsProvider);
    if (config == null) {
      return;
    }
    setState(() => _isSaving = true);
    if (widget.existingConfig == null) {
      settingsProvider.addApiConfig(config);
    } else {
      settingsProvider.updateApiConfig(config);
    }
    if (!mounted) return;
    setState(() => _isSaving = false);
    context.showInfoSnackBar('${config.name} 프리셋을 저장했습니다.');
    Navigator.pop(context, config);
  }

  ApiConfig? _buildConfig(
    SettingsProvider settingsProvider, {
    bool validateOnly = false,
  }) {
    final name = _nameController.text.trim();
    final model = _modelController.text.trim();
    final baseUrl = _baseUrlController.text.trim();

    if (name.isEmpty || model.isEmpty) {
      if (!validateOnly) {
        context.showErrorSnackBar('프리셋 이름과 모델은 필수입니다.');
      }
      return null;
    }

    if (_kind == _ApiPresetEditorKind.standard && baseUrl.isEmpty) {
      if (!validateOnly) {
        context.showErrorSnackBar('Base URL은 필수입니다.');
      }
      return null;
    }

    final selectedAccount = settingsProvider.getOAuthAccountById(_selectedAccountId);
    if (_kind != _ApiPresetEditorKind.standard && selectedAccount == null) {
      if (!validateOnly) {
        context.showErrorSnackBar('OAuth 계정을 선택하세요.');
      }
      return null;
    }

    final next = _draft.copyWith(
      name: name,
      baseUrl: _resolvedBaseUrl(),
      apiKey: _kind == _ApiPresetEditorKind.standard ? _apiKeyController.text : '',
      modelName: model,
      customHeaders: _sanitizedCustomHeaders(),
      additionalParams: _sanitizedAdditionalParamsForSave(selectedAccount),
      format: _resolvedFormat(),
      useStreaming: _kind == _ApiPresetEditorKind.codexOAuth ? true : _useStreaming,
      hasFirstSystemPrompt: _hasFirstSystemPrompt,
      requiresAlternateRole: _requiresAlternateRole,
      mergeSystemPrompts: _mergeSystemPrompts,
      mustStartWithUserInput: _mustStartWithUserInput,
      useMaxOutputTokens:
          _kind == _ApiPresetEditorKind.codexOAuth ? false : _useMaxOutputTokens,
      oauthAccountId: _kind == _ApiPresetEditorKind.standard ? null : _selectedAccountId,
      clearOAuthAccount: _kind == _ApiPresetEditorKind.standard,
    );
    return next;
  }

  void _applyKind(_ApiPresetEditorKind kind, SettingsProvider settingsProvider) {
    _kind = kind;
    switch (kind) {
      case _ApiPresetEditorKind.standard:
        if (_baseUrlController.text.trim().isEmpty) {
          _baseUrlController.text = 'https://api.openai.com/v1/chat/completions';
        }
        _format = _normalizeStandardFormat(_format);
        break;
      case _ApiPresetEditorKind.codexOAuth:
        _baseUrlController.text = 'https://chatgpt.com/backend-api/codex/responses';
        _format = ApiFormat.openAIResponses;
        _apiKeyController.clear();
        _useStreaming = true;
        _useMaxOutputTokens = false;
        _additionalParams.removeWhere(
          (key, _) => ApiPresetParameterPolicy.codexBlockedParamKeys.contains(key),
        );
        break;
      case _ApiPresetEditorKind.geminiOAuth:
        _baseUrlController.text =
            'https://cloudcode-pa.googleapis.com/v1internal:generateContent';
        _format = ApiFormat.googleCodeAssist;
        _apiKeyController.clear();
        break;
    }
    _normalizeAccountSelection(_accountsForKind(settingsProvider));
  }

  ApiFormat _normalizeStandardFormat(ApiFormat format) {
    switch (format) {
      case ApiFormat.google:
      case ApiFormat.openAIResponses:
      case ApiFormat.googleCodeAssist:
        return ApiFormat.custom;
      case ApiFormat.openAICompatible:
      case ApiFormat.anthropic:
      case ApiFormat.openRouter:
      case ApiFormat.custom:
        return format;
    }
  }

  _ApiPresetEditorKind _inferKind(ApiConfig config) {
    if (config.isCodexPreset) {
      return _ApiPresetEditorKind.codexOAuth;
    }
    if (config.isGeminiCodeAssistPreset) {
      return _ApiPresetEditorKind.geminiOAuth;
    }
    return _ApiPresetEditorKind.standard;
  }

  String _resolvedBaseUrl() {
    switch (_kind) {
      case _ApiPresetEditorKind.standard:
        return _baseUrlController.text.trim();
      case _ApiPresetEditorKind.codexOAuth:
        return 'https://chatgpt.com/backend-api/codex/responses';
      case _ApiPresetEditorKind.geminiOAuth:
        return 'https://cloudcode-pa.googleapis.com/v1internal:generateContent';
    }
  }

  ApiFormat _resolvedFormat() {
    switch (_kind) {
      case _ApiPresetEditorKind.standard:
        return _format;
      case _ApiPresetEditorKind.codexOAuth:
        return ApiFormat.openAIResponses;
      case _ApiPresetEditorKind.geminiOAuth:
        return ApiFormat.googleCodeAssist;
    }
  }

  OAuthAccountProvider _oauthProviderForKind(_ApiPresetEditorKind kind) {
    return kind == _ApiPresetEditorKind.geminiOAuth
        ? OAuthAccountProvider.geminiGca
        : OAuthAccountProvider.codex;
  }

  List<OAuthAccount> _accountsForKind(SettingsProvider settingsProvider) {
    if (_kind == _ApiPresetEditorKind.standard) {
      return const [];
    }
    final provider = _oauthProviderForKind(_kind);
    return settingsProvider.oauthAccounts
        .where((account) => account.provider == provider)
        .toList(growable: false);
  }

  void _normalizeAccountSelection(List<OAuthAccount> accounts) {
    if (_kind == _ApiPresetEditorKind.standard) {
      _selectedAccountId = null;
      return;
    }
    if (_selectedAccountId != null &&
        accounts.any((account) => account.id == _selectedAccountId)) {
      return;
    }
    _selectedAccountId = accounts.isEmpty ? null : accounts.first.id;
  }

  Map<String, dynamic> _sanitizedAdditionalParamsForSave(OAuthAccount? account) {
    final additional = Map<String, dynamic>.from(_additionalParams);
    for (final key in ApiPresetParameterPolicy.tokenLimitAliases) {
      additional.remove(key);
    }

    if (_kind == _ApiPresetEditorKind.codexOAuth) {
      additional.removeWhere(
        (key, _) => ApiPresetParameterPolicy.codexBlockedParamKeys.contains(key),
      );
    } else {
      additional[ApiPresetParameterPolicy.temperatureKey] =
          _readDouble(ApiPresetParameterPolicy.temperatureKey, 0.9);
      additional[ApiPresetParameterPolicy.topPKey] =
          _readDouble(ApiPresetParameterPolicy.topPKey, 1.0);
      additional[ApiPresetParameterPolicy.maxTokensKey] =
          _readInt(ApiPresetParameterPolicy.maxTokensKey, 1024);
      additional[ApiPresetParameterPolicy.frequencyPenaltyKey] =
          _readDouble(ApiPresetParameterPolicy.frequencyPenaltyKey, 0.0);
      additional[ApiPresetParameterPolicy.presencePenaltyKey] =
          _readDouble(ApiPresetParameterPolicy.presencePenaltyKey, 0.0);
    }

    if (_kind == _ApiPresetEditorKind.geminiOAuth) {
      final project = account?.cloudProjectId?.trim();
      if (project != null && project.isNotEmpty) {
        additional['googleCloudProject'] = project;
      } else {
        additional.remove('googleCloudProject');
      }
    }

    return additional;
  }

  Map<String, String> _sanitizedCustomHeaders() {
    final headers = Map<String, String>.from(_customHeaders);
    if (_kind == _ApiPresetEditorKind.codexOAuth) {
      const blocked = {
        'authorization',
        'content-type',
        'accept',
        'originator',
        'openai-beta',
        'user-agent',
        'chatgpt-account-id',
      };
      headers.removeWhere((key, _) => blocked.contains(key.toLowerCase()));
    }
    return headers;
  }

  double _readDouble(String key, double fallback) {
    return ApiPresetParameterPolicy.readDouble(_additionalParams, key) ?? fallback;
  }

  int _readInt(String key, int fallback) {
    if (key == ApiPresetParameterPolicy.maxTokensKey) {
      return ApiPresetParameterPolicy.readMaxTokens(_additionalParams) ?? fallback;
    }
    return ApiPresetParameterPolicy.readInt(_additionalParams, key) ?? fallback;
  }

  void _setDouble(String key, double value) {
    setState(() {
      _additionalParams[key] = value;
    });
  }

  void _addHeader() {
    final keyController = TextEditingController();
    final valueController = TextEditingController();

    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('헤더 추가'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: keyController,
              decoration: const InputDecoration(labelText: '헤더 이름'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: valueController,
              decoration: const InputDecoration(labelText: '헤더 값'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () {
              final key = keyController.text.trim();
              if (key.isEmpty) {
                return;
              }
              setState(() {
                _customHeaders[key] = valueController.text;
              });
              Navigator.pop(context);
            },
            child: const Text('추가'),
          ),
        ],
      ),
    );
  }

  String _kindLabel(_ApiPresetEditorKind kind) {
    switch (kind) {
      case _ApiPresetEditorKind.standard:
        return '일반 API';
      case _ApiPresetEditorKind.codexOAuth:
        return 'Codex OAuth';
      case _ApiPresetEditorKind.geminiOAuth:
        return 'Gemini CLI OAuth';
    }
  }

  String _formatLabel(ApiFormat format) {
    switch (format) {
      case ApiFormat.openAICompatible:
        return 'OpenAI Compatible';
      case ApiFormat.anthropic:
        return 'Anthropic Claude';
      case ApiFormat.openRouter:
        return 'OpenRouter';
      case ApiFormat.custom:
        return 'Custom';
      case ApiFormat.google:
        return 'Google Gemini';
      case ApiFormat.googleCodeAssist:
        return 'Google Code Assist';
      case ApiFormat.openAIResponses:
        return 'OpenAI Responses';
    }
  }
}

class _EditorHeroCard extends StatelessWidget {
  const _EditorHeroCard({required this.kind});

  final _ApiPresetEditorKind kind;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final (icon, title, subtitle) = switch (kind) {
      _ApiPresetEditorKind.standard => (
          Icons.api_outlined,
          '프리셋 중심 설정',
          '이제 생성 파라미터가 프리셋에 귀속됩니다. 프리셋마다 다른 모델 성격을 안정적으로 저장하세요.',
        ),
      _ApiPresetEditorKind.codexOAuth => (
          Icons.code_outlined,
          'Codex 전용 가드레일',
          'Codex는 지원하지 않는 파라미터가 많아서, 고정값은 잠그고 안전한 계약만 안내합니다.',
        ),
      _ApiPresetEditorKind.geminiOAuth => (
          Icons.auto_awesome_outlined,
          'Gemini CLI 계정 연동',
          'OAuth 계정과 프리셋을 묶어서 모델/프로젝트 구성을 한 화면에서 관리합니다.',
        ),
    };

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            colorScheme.primaryContainer,
            colorScheme.secondaryContainer,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colorScheme.surface.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 6),
                Text(subtitle),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EditorSection extends StatelessWidget {
  const _EditorSection({
    required this.title,
    required this.description,
    required this.child,
  });

  final String title;
  final String description;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            description,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _PresetSliderField extends StatelessWidget {
  const _PresetSliderField({
    required this.label,
    required this.description,
    required this.min,
    required this.max,
    required this.divisions,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final String description;
  final double min;
  final double max;
  final int divisions;
  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
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

class _GuidanceList extends StatelessWidget {
  const _GuidanceList({required this.title, required this.items});

  final String title;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        ...items.map(
          (item) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 6),
                  child: Icon(Icons.circle, size: 8),
                ),
                const SizedBox(width: 8),
                Expanded(child: Text(item)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _TestResultCard extends StatelessWidget {
  const _TestResultCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final isSuccess = message.startsWith('✅');
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isSuccess
            ? theme.colorScheme.tertiaryContainer.withValues(alpha: 0.45)
            : theme.colorScheme.errorContainer.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(message),
    );
  }
}

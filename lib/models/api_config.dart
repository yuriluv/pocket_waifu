// ============================================================================
// ============================================================================
// ============================================================================

import 'package:uuid/uuid.dart';

import '../utils/api_preset_parameter_policy.dart';

enum ApiFormat {
  openAICompatible,
  openAIResponses,
  anthropic, // Anthropic Claude
  google, // Google Gemini
  googleCodeAssist,
  openRouter, // OpenRouter
  custom,
}

class ApiConfig {
  final String id;
  String name;
  String baseUrl;
  String apiKey;
  String modelName;
  Map<String, String> customHeaders;
  Map<String, dynamic> additionalParams;
  String? oauthAccountId;
  bool isDefault;
  DateTime createdAt;

  ApiFormat format;
  String tokenizer;

  bool useStreaming;
  bool hasFirstSystemPrompt;
  bool requiresAlternateRole;
  bool mergeSystemPrompts;
  bool mustStartWithUserInput;
  bool useMaxOutputTokens;
  bool supportsVision;

  int? reasoningEffort; // verbosity/reasoning_effort (0-100)
  String? thinkingLevel; // Gemini thinking_level
  bool useDeepSeekReasoning;
  String? openRouterProvider;

  double inputPrice; // Input Price per 1M tokens
  double outputPrice; // Output Price per 1M tokens
  double cachedPrice; // Cached Price per 1M tokens

  ApiConfig({
    String? id,
    required this.name,
    this.baseUrl = '',
    this.apiKey = '',
    this.modelName = '',
    Map<String, String>? customHeaders,
    Map<String, dynamic>? additionalParams,
    this.oauthAccountId,
    this.isDefault = false,
    DateTime? createdAt,
    this.format = ApiFormat.openAICompatible,
    this.tokenizer = 'o200k_base',
    this.useStreaming = true,
    this.hasFirstSystemPrompt = true,
    this.requiresAlternateRole = true,
    this.mergeSystemPrompts = false,
    this.mustStartWithUserInput = false,
    this.useMaxOutputTokens = false,
    this.supportsVision = true,
    this.reasoningEffort,
    this.thinkingLevel,
    this.useDeepSeekReasoning = false,
    this.openRouterProvider,
    this.inputPrice = 0.0,
    this.outputPrice = 0.0,
    this.cachedPrice = 0.0,
  }) : id = id ?? const Uuid().v4(),
       customHeaders = customHeaders ?? {},
       additionalParams = additionalParams ?? _defaultParams(),
       createdAt = createdAt ?? DateTime.now();

  static Map<String, dynamic> _defaultParams() {
    return {
      ApiPresetParameterPolicy.temperatureKey: 0.9,
      ApiPresetParameterPolicy.topPKey: 1.0,
      ApiPresetParameterPolicy.maxTokensKey: 1024,
      ApiPresetParameterPolicy.frequencyPenaltyKey: 0.0,
      ApiPresetParameterPolicy.presencePenaltyKey: 0.0,
    };
  }

  bool get hasApiKey => apiKey.isNotEmpty;

  bool get usesOAuth => oauthAccountId != null && oauthAccountId!.isNotEmpty;

  bool get hasValidUrl => baseUrl.isNotEmpty && baseUrl.startsWith('http');

  bool get isConfigured => (hasApiKey || usesOAuth) && hasValidUrl && modelName.isNotEmpty;

  bool get isCodexPreset => ApiPresetParameterPolicy.isCodexPreset(this);

  bool get isGeminiCodeAssistPreset =>
      ApiPresetParameterPolicy.isGeminiCodeAssistPreset(this);

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'baseUrl': baseUrl,
      'apiKey': apiKey,
      'modelName': modelName,
      'customHeaders': customHeaders,
      'additionalParams': additionalParams,
      'oauthAccountId': oauthAccountId,
      'isDefault': isDefault,
      'createdAt': createdAt.toIso8601String(),
      'format': format.name,
      'tokenizer': tokenizer,
      'useStreaming': useStreaming,
      'hasFirstSystemPrompt': hasFirstSystemPrompt,
      'requiresAlternateRole': requiresAlternateRole,
      'mergeSystemPrompts': mergeSystemPrompts,
      'mustStartWithUserInput': mustStartWithUserInput,
      'useMaxOutputTokens': useMaxOutputTokens,
      'supportsVision': supportsVision,
      'reasoningEffort': reasoningEffort,
      'thinkingLevel': thinkingLevel,
      'useDeepSeekReasoning': useDeepSeekReasoning,
      'openRouterProvider': openRouterProvider,
      'inputPrice': inputPrice,
      'outputPrice': outputPrice,
      'cachedPrice': cachedPrice,
    };
  }

  factory ApiConfig.fromMap(Map<String, dynamic> map) {
    ApiFormat format = ApiFormat.openAICompatible;
    if (map['format'] != null) {
      try {
        format = ApiFormat.values.firstWhere(
          (e) => e.name == map['format'],
          orElse: () => ApiFormat.openAICompatible,
        );
      } catch (_) {
        format = ApiFormat.openAICompatible;
      }
    }

    return ApiConfig(
      id: map['id'],
      name: map['name'] ?? 'New API Config',
      baseUrl: map['baseUrl'] ?? '',
      apiKey: map['apiKey'] ?? '',
      modelName: map['modelName'] ?? '',
      customHeaders: Map<String, String>.from(map['customHeaders'] ?? {}),
      additionalParams: Map<String, dynamic>.from(
        map['additionalParams'] ?? _defaultParams(),
      ),
      oauthAccountId: map['oauthAccountId'] as String?,
      isDefault: map['isDefault'] ?? false,
      createdAt: map['createdAt'] != null
          ? DateTime.parse(map['createdAt'])
          : DateTime.now(),
      format: format,
      tokenizer: map['tokenizer'] ?? 'o200k_base',
      useStreaming: map['useStreaming'] ?? true,
      hasFirstSystemPrompt: map['hasFirstSystemPrompt'] ?? true,
      requiresAlternateRole: map['requiresAlternateRole'] ?? true,
      mergeSystemPrompts: map['mergeSystemPrompts'] ?? false,
      mustStartWithUserInput: map['mustStartWithUserInput'] ?? false,
      useMaxOutputTokens: map['useMaxOutputTokens'] ?? false,
      supportsVision: map['supportsVision'] ?? true,
      reasoningEffort: map['reasoningEffort'],
      thinkingLevel: map['thinkingLevel'],
      useDeepSeekReasoning: map['useDeepSeekReasoning'] ?? false,
      openRouterProvider: map['openRouterProvider'],
      inputPrice: (map['inputPrice'] ?? 0.0).toDouble(),
      outputPrice: (map['outputPrice'] ?? 0.0).toDouble(),
      cachedPrice: (map['cachedPrice'] ?? 0.0).toDouble(),
    );
  }

  ApiConfig copyWith({
    String? id,
    String? name,
    String? baseUrl,
    String? apiKey,
    String? modelName,
    Map<String, String>? customHeaders,
    Map<String, dynamic>? additionalParams,
    String? oauthAccountId,
    bool? isDefault,
    DateTime? createdAt,
    ApiFormat? format,
    String? tokenizer,
    bool? useStreaming,
    bool? hasFirstSystemPrompt,
    bool? requiresAlternateRole,
    bool? mergeSystemPrompts,
    bool? mustStartWithUserInput,
    bool? useMaxOutputTokens,
    bool? supportsVision,
    int? reasoningEffort,
    String? thinkingLevel,
    bool? useDeepSeekReasoning,
    String? openRouterProvider,
    double? inputPrice,
    double? outputPrice,
    double? cachedPrice,
    bool clearOAuthAccount = false,
  }) {
    return ApiConfig(
      id: id ?? this.id,
      name: name ?? this.name,
      baseUrl: baseUrl ?? this.baseUrl,
      apiKey: apiKey ?? this.apiKey,
      modelName: modelName ?? this.modelName,
      customHeaders: customHeaders ?? Map.from(this.customHeaders),
      additionalParams: additionalParams ?? Map.from(this.additionalParams),
      oauthAccountId: clearOAuthAccount ? null : (oauthAccountId ?? this.oauthAccountId),
      isDefault: isDefault ?? this.isDefault,
      createdAt: createdAt ?? this.createdAt,
      format: format ?? this.format,
      tokenizer: tokenizer ?? this.tokenizer,
      useStreaming: useStreaming ?? this.useStreaming,
      hasFirstSystemPrompt: hasFirstSystemPrompt ?? this.hasFirstSystemPrompt,
      requiresAlternateRole:
          requiresAlternateRole ?? this.requiresAlternateRole,
      mergeSystemPrompts: mergeSystemPrompts ?? this.mergeSystemPrompts,
      mustStartWithUserInput:
          mustStartWithUserInput ?? this.mustStartWithUserInput,
      useMaxOutputTokens: useMaxOutputTokens ?? this.useMaxOutputTokens,
      supportsVision: supportsVision ?? this.supportsVision,
      reasoningEffort: reasoningEffort ?? this.reasoningEffort,
      thinkingLevel: thinkingLevel ?? this.thinkingLevel,
      useDeepSeekReasoning: useDeepSeekReasoning ?? this.useDeepSeekReasoning,
      openRouterProvider: openRouterProvider ?? this.openRouterProvider,
      inputPrice: inputPrice ?? this.inputPrice,
      outputPrice: outputPrice ?? this.outputPrice,
      cachedPrice: cachedPrice ?? this.cachedPrice,
    );
  }

  // ============================================================================
  // ============================================================================

  factory ApiConfig.copilotDefault() {
    return ApiConfig(
      id: 'copilot_default',
      name: 'GitHub Copilot',
      baseUrl: 'https://api.githubcopilot.com/chat/completions',
      apiKey: '',
      modelName: 'gpt-4o',
      customHeaders: {
        'Editor-Version': 'vscode/1.85.0',
        'Editor-Plugin-Version': 'copilot/1.0.0',
        'Copilot-Integration-Id': 'vscode-chat',
      },
      additionalParams: {
        'temperature': 0.9,
        'top_p': 1.0,
        'stream': false,
      },
      isDefault: true,
      format: ApiFormat.openAICompatible,
      hasFirstSystemPrompt: true,
      requiresAlternateRole: true,
      supportsVision: false,
    );
  }

  factory ApiConfig.openaiDefault() {
    return ApiConfig(
      id: 'openai_default',
      name: 'OpenAI',
      baseUrl: 'https://api.openai.com/v1/chat/completions',
      apiKey: '',
      modelName: 'gpt-4o-mini',
      customHeaders: {},
      additionalParams: {
        'temperature': 0.9,
        'top_p': 1.0,
        'frequency_penalty': 0.0,
        'presence_penalty': 0.0,
      },
      isDefault: true,
      format: ApiFormat.openAICompatible,
      hasFirstSystemPrompt: true,
      requiresAlternateRole: false,
      supportsVision: true,
    );
  }

  factory ApiConfig.anthropicDefault() {
    return ApiConfig(
      id: 'anthropic_default',
      name: 'Anthropic Claude',
      baseUrl: 'https://api.anthropic.com/v1/messages',
      apiKey: '',
      modelName: 'claude-3-5-sonnet-20241022',
      customHeaders: {'anthropic-version': '2023-06-01'},
      additionalParams: {'temperature': 0.9},
      isDefault: true,
      format: ApiFormat.anthropic,
      hasFirstSystemPrompt: false,
      requiresAlternateRole: true,
      supportsVision: true,
    );
  }

  factory ApiConfig.openRouterDefault() {
    return ApiConfig(
      id: 'openrouter_default',
      name: 'OpenRouter',
      baseUrl: 'https://openrouter.ai/api/v1/chat/completions',
      apiKey: '',
      modelName: 'openai/gpt-4o-mini',
      customHeaders: {
        'HTTP-Referer': 'https://pocket-waifu.app',
        'X-Title': 'Pocket Waifu',
      },
      additionalParams: {'temperature': 0.9},
      isDefault: true,
      format: ApiFormat.openRouter,
      hasFirstSystemPrompt: true,
      requiresAlternateRole: false,
      supportsVision: true,
    );
  }

  factory ApiConfig.custom({
    String? id,
    String? name,
    String? baseUrl,
    String? apiKey,
    String? modelName,
    Map<String, String>? customHeaders,
    Map<String, dynamic>? additionalParams,
    }) {
    return ApiConfig(
      id: id,
      name: name ?? 'Custom API',
      baseUrl: baseUrl ?? 'https://api.openai.com/v1/chat/completions',
      apiKey: apiKey ?? '',
      modelName: modelName ?? 'gpt-4o',
      customHeaders: customHeaders ?? {},
      additionalParams: additionalParams ?? _defaultParams(),
      isDefault: false,
    );
  }

  factory ApiConfig.codexOAuth({
    required String oauthAccountId,
    required String modelName,
    String? name,
  }) {
    return ApiConfig(
      name: name ?? 'Codex OAuth',
      baseUrl: 'https://chatgpt.com/backend-api/codex/responses',
      apiKey: '',
      modelName: modelName,
      customHeaders: const {},
      additionalParams: const {},
      oauthAccountId: oauthAccountId,
      isDefault: false,
      format: ApiFormat.openAIResponses,
      hasFirstSystemPrompt: true,
      requiresAlternateRole: false,
      supportsVision: true,
    );
  }

  factory ApiConfig.geminiCodeAssistOAuth({
    required String oauthAccountId,
    required String modelName,
    String? name,
    String? cloudProjectId,
  }) {
    return ApiConfig(
      name: name ?? 'Gemini CLI OAuth',
      baseUrl: 'https://cloudcode-pa.googleapis.com/v1internal:generateContent',
      apiKey: '',
      modelName: modelName,
      customHeaders: const {},
      additionalParams: {
        if (cloudProjectId != null && cloudProjectId.isNotEmpty)
          'googleCloudProject': cloudProjectId,
      },
      oauthAccountId: oauthAccountId,
      isDefault: false,
      format: ApiFormat.googleCodeAssist,
      hasFirstSystemPrompt: true,
      requiresAlternateRole: false,
      supportsVision: true,
    );
  }

  @override
  String toString() {
    return 'ApiConfig(id: $id, name: $name, model: $modelName, configured: $isConfigured)';
  }
}

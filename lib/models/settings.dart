// ============================================================================
// ============================================================================
// ============================================================================

enum ApiProvider {
  openai,
  anthropic,
  copilot, // GitHub Copilot
}

class AppSettings {
  final ApiProvider apiProvider;
  final String openaiApiKey;
  final String anthropicApiKey;
  final String copilotApiKey;
  final String openaiModel;
  final String anthropicModel;
  final String copilotModel;

  final double temperature;
  final double topP;
  final int maxTokens;
  final double frequencyPenalty;
  final double presencePenalty;

  final String systemPrompt;

  AppSettings({
    this.apiProvider = ApiProvider.openai,
    this.openaiApiKey = '',
    this.anthropicApiKey = '',
    this.copilotApiKey = '',
    this.openaiModel = 'gpt-4o-mini',
    this.anthropicModel = 'claude-3-5-sonnet-20241022',
    this.copilotModel = 'gpt-4o',
    this.temperature = 0.9,
    this.topP = 1.0,
    this.maxTokens = 1024,
    this.frequencyPenalty = 0.0,
    this.presencePenalty = 0.0,
    this.systemPrompt = '',
  });

  String get currentApiKey {
    switch (apiProvider) {
      case ApiProvider.openai:
        return openaiApiKey;
      case ApiProvider.anthropic:
        return anthropicApiKey;
      case ApiProvider.copilot:
        return copilotApiKey;
    }
  }

  String get currentModel {
    switch (apiProvider) {
      case ApiProvider.openai:
        return openaiModel;
      case ApiProvider.anthropic:
        return anthropicModel;
      case ApiProvider.copilot:
        return copilotModel;
    }
  }

  String get apiProviderString {
    switch (apiProvider) {
      case ApiProvider.openai:
        return 'openai';
      case ApiProvider.anthropic:
        return 'anthropic';
      case ApiProvider.copilot:
        return 'copilot';
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'apiProvider': apiProviderString,
      'openaiApiKey': openaiApiKey,
      'anthropicApiKey': anthropicApiKey,
      'copilotApiKey': copilotApiKey,
      'openaiModel': openaiModel,
      'anthropicModel': anthropicModel,
      'copilotModel': copilotModel,
      'temperature': temperature,
      'topP': topP,
      'maxTokens': maxTokens,
      'frequencyPenalty': frequencyPenalty,
      'presencePenalty': presencePenalty,
      'systemPrompt': systemPrompt,
    };
  }

  factory AppSettings.fromMap(Map<String, dynamic> map) {
    ApiProvider provider;
    switch (map['apiProvider']) {
      case 'anthropic':
        provider = ApiProvider.anthropic;
        break;
      case 'copilot':
        provider = ApiProvider.copilot;
        break;
      default:
        provider = ApiProvider.openai;
    }

    return AppSettings(
      apiProvider: provider,
      openaiApiKey: map['openaiApiKey'] ?? '',
      anthropicApiKey: map['anthropicApiKey'] ?? '',
      copilotApiKey: map['copilotApiKey'] ?? '',
      openaiModel: map['openaiModel'] ?? 'gpt-4o-mini',
      anthropicModel: map['anthropicModel'] ?? 'claude-3-5-sonnet-20241022',
      copilotModel: map['copilotModel'] ?? 'gpt-4o',
      temperature: (map['temperature'] ?? 0.9).toDouble(),
      topP: (map['topP'] ?? 1.0).toDouble(),
      maxTokens: map['maxTokens'] ?? 1024,
      frequencyPenalty: (map['frequencyPenalty'] ?? 0.0).toDouble(),
      presencePenalty: (map['presencePenalty'] ?? 0.0).toDouble(),
      systemPrompt: map['systemPrompt'] ?? '',
    );
  }

  AppSettings copyWith({
    ApiProvider? apiProvider,
    String? openaiApiKey,
    String? anthropicApiKey,
    String? copilotApiKey,
    String? openaiModel,
    String? anthropicModel,
    String? copilotModel,
    double? temperature,
    double? topP,
    int? maxTokens,
    double? frequencyPenalty,
    double? presencePenalty,
    String? systemPrompt,
  }) {
    return AppSettings(
      apiProvider: apiProvider ?? this.apiProvider,
      openaiApiKey: openaiApiKey ?? this.openaiApiKey,
      anthropicApiKey: anthropicApiKey ?? this.anthropicApiKey,
      copilotApiKey: copilotApiKey ?? this.copilotApiKey,
      openaiModel: openaiModel ?? this.openaiModel,
      anthropicModel: anthropicModel ?? this.anthropicModel,
      copilotModel: copilotModel ?? this.copilotModel,
      temperature: temperature ?? this.temperature,
      topP: topP ?? this.topP,
      maxTokens: maxTokens ?? this.maxTokens,
      frequencyPenalty: frequencyPenalty ?? this.frequencyPenalty,
      presencePenalty: presencePenalty ?? this.presencePenalty,
      systemPrompt: systemPrompt ?? this.systemPrompt,
    );
  }
}

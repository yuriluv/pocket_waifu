// ============================================================================
// ============================================================================
// ============================================================================

import 'package:flutter_application_1/features/lua/lua_help_contract.dart';

enum ApiProvider {
  openai,
  anthropic,
  copilot, // GitHub Copilot
}

enum LlmDirectiveTarget {
  live2d,
  imageOverlay,
}

const String _fallbackPromptTruthNotes =
    'Fallback note: The current fallback engine does not implement general Lua. '
    'Fallback patterns use Dart RegExp semantics, not Lua pattern semantics. '
    'Prefer helper-first scripts such as pwf.dispatch(text, pattern, functionName, payloadTemplate), '
    'pwf.dispatchKeep(text, pattern, functionName, payloadTemplate), '
    'and pwf.emit(text, functionName, payload) over general Lua forms.';

const String _defaultLive2dSystemPromptTemplate =
    '[Lua Runtime Template · Live2D Examples]\n'
    'The app does not assign control-text meaning by itself. The editable Lua template parses text and emits runtime functions.\n'
    'The shipped default Lua template recognizes examples such as <param .../>, <motion .../>, <expression .../>, <emotion .../>, <wait .../>, <preset .../>, <reset .../>, and inline forms like [param:...], [motion:...], [expression:...], [emotion:...], [wait:...], [preset:...], [reset].\n'
    'If you customize Lua, you may change these examples to any syntax you want.\n'
    '$_fallbackPromptTruthNotes';

const String _defaultImageOverlaySystemPromptTemplate =
    '[Lua Runtime Template · Overlay Examples]\n'
    'The editable Lua template can also map image-overlay text to runtime functions.\n'
    'The shipped default Lua template recognizes examples such as <move .../>, <emotion .../>, <wait .../>, [img_move:...], and [img_emotion:...].\n'
    'You may replace this with any custom text format that your Lua script parses.\n'
    '$_fallbackPromptTruthNotes';

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
  final bool live2dDirectiveParsingEnabled;
  final bool live2dPromptInjectionEnabled;
  final bool live2dLlmIntegrationEnabled;
  final bool live2dLuaExecutionEnabled;
  final bool live2dShowRawDirectivesInChat;
  final bool runRegexBeforeLua;
  final String live2dSystemPromptTemplate;
  final String imageOverlaySystemPromptTemplate;
  final int live2dSystemPromptTokenBudget;
  final LlmDirectiveTarget llmDirectiveTarget;

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
    this.live2dDirectiveParsingEnabled = true,
    this.live2dPromptInjectionEnabled = true,
    this.live2dLlmIntegrationEnabled = true,
    this.live2dLuaExecutionEnabled = true,
    this.live2dShowRawDirectivesInChat = false,
    this.runRegexBeforeLua = true,
    this.live2dSystemPromptTemplate = _defaultLive2dSystemPromptTemplate,
    this.imageOverlaySystemPromptTemplate = _defaultImageOverlaySystemPromptTemplate,
    this.live2dSystemPromptTokenBudget = 500,
    this.llmDirectiveTarget = LlmDirectiveTarget.live2d,
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
      'live2dDirectiveParsingEnabled': live2dDirectiveParsingEnabled,
      'live2dPromptInjectionEnabled': live2dPromptInjectionEnabled,
      'live2dLlmIntegrationEnabled': live2dLlmIntegrationEnabled,
      'live2dLuaExecutionEnabled': live2dLuaExecutionEnabled,
      'live2dShowRawDirectivesInChat': live2dShowRawDirectivesInChat,
      'runRegexBeforeLua': runRegexBeforeLua,
      'live2dSystemPromptTemplate': live2dSystemPromptTemplate,
      'imageOverlaySystemPromptTemplate': imageOverlaySystemPromptTemplate,
      'live2dSystemPromptTokenBudget': live2dSystemPromptTokenBudget,
      'llmDirectiveTarget': llmDirectiveTarget.name,
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
      live2dDirectiveParsingEnabled:
          map['live2dDirectiveParsingEnabled'] ?? true,
      live2dPromptInjectionEnabled: map['live2dPromptInjectionEnabled'] ?? true,
      live2dLlmIntegrationEnabled: map['live2dLlmIntegrationEnabled'] ?? true,
      live2dLuaExecutionEnabled: map['live2dLuaExecutionEnabled'] ?? true,
      live2dShowRawDirectivesInChat:
          map['live2dShowRawDirectivesInChat'] ?? false,
      runRegexBeforeLua: map['runRegexBeforeLua'] ?? true,
      live2dSystemPromptTemplate:
          map['live2dSystemPromptTemplate'] ?? _defaultLive2dSystemPromptTemplate,
      imageOverlaySystemPromptTemplate:
          map['imageOverlaySystemPromptTemplate'] ??
              _defaultImageOverlaySystemPromptTemplate,
      live2dSystemPromptTokenBudget:
          (map['live2dSystemPromptTokenBudget'] ?? 500) as int,
      llmDirectiveTarget: switch (map['llmDirectiveTarget']) {
        'imageOverlay' => LlmDirectiveTarget.imageOverlay,
        _ => LlmDirectiveTarget.live2d,
      },
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
    bool? live2dDirectiveParsingEnabled,
    bool? live2dPromptInjectionEnabled,
    bool? live2dLlmIntegrationEnabled,
    bool? live2dLuaExecutionEnabled,
    bool? live2dShowRawDirectivesInChat,
    bool? runRegexBeforeLua,
    String? live2dSystemPromptTemplate,
    String? imageOverlaySystemPromptTemplate,
    int? live2dSystemPromptTokenBudget,
    LlmDirectiveTarget? llmDirectiveTarget,
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
      live2dDirectiveParsingEnabled:
          live2dDirectiveParsingEnabled ?? this.live2dDirectiveParsingEnabled,
      live2dPromptInjectionEnabled:
          live2dPromptInjectionEnabled ?? this.live2dPromptInjectionEnabled,
      live2dLlmIntegrationEnabled:
          live2dLlmIntegrationEnabled ?? this.live2dLlmIntegrationEnabled,
      live2dLuaExecutionEnabled:
          live2dLuaExecutionEnabled ?? this.live2dLuaExecutionEnabled,
      live2dShowRawDirectivesInChat:
          live2dShowRawDirectivesInChat ?? this.live2dShowRawDirectivesInChat,
      runRegexBeforeLua: runRegexBeforeLua ?? this.runRegexBeforeLua,
      live2dSystemPromptTemplate:
          live2dSystemPromptTemplate ?? this.live2dSystemPromptTemplate,
      imageOverlaySystemPromptTemplate:
          imageOverlaySystemPromptTemplate ?? this.imageOverlaySystemPromptTemplate,
      live2dSystemPromptTokenBudget:
          live2dSystemPromptTokenBudget ?? this.live2dSystemPromptTokenBudget,
      llmDirectiveTarget: llmDirectiveTarget ?? this.llmDirectiveTarget,
    );
  }
}

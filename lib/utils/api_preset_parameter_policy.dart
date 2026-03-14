import '../models/api_config.dart';

class ApiPresetParameterPolicy {
  static const List<ApiFormat> supportedStandardFormats = [
    ApiFormat.openAICompatible,
    ApiFormat.anthropic,
    ApiFormat.openRouter,
    ApiFormat.custom,
  ];

  static const String temperatureKey = 'temperature';
  static const String topPKey = 'top_p';
  static const String maxTokensKey = 'max_output_tokens';
  static const String frequencyPenaltyKey = 'frequency_penalty';
  static const String presencePenaltyKey = 'presence_penalty';

  static const Set<String> commonGenerationKeys = {
    temperatureKey,
    topPKey,
    maxTokensKey,
    frequencyPenaltyKey,
    presencePenaltyKey,
  };

  static const Set<String> tokenLimitAliases = {
    'max_tokens',
    'max_completion_tokens',
    maxTokensKey,
  };

  static const Set<String> codexBlockedParamKeys = {
    temperatureKey,
    topPKey,
    maxTokensKey,
    'max_tokens',
    'max_completion_tokens',
    'metadata',
    'user',
    'context_management',
    'prompt_cache_retention',
    'parallel_tool_calls',
    'generate',
  };

  static bool isCodexPreset(ApiConfig config) {
    if (config.format != ApiFormat.openAIResponses) {
      return false;
    }
    final uri = Uri.tryParse(config.baseUrl);
    if (uri == null) {
      return false;
    }
    return uri.host == 'chatgpt.com' &&
        uri.path.contains('/backend-api/codex/responses');
  }

  static bool isGeminiCodeAssistPreset(ApiConfig config) {
    return config.format == ApiFormat.googleCodeAssist;
  }

  static bool supportsCommonGenerationControls(ApiConfig config) {
    return !isCodexPreset(config);
  }

  static Map<String, dynamic> sanitizeAdditionalParams(ApiConfig config) {
    final sanitized = Map<String, dynamic>.from(config.additionalParams);
    if (isCodexPreset(config)) {
      for (final key in codexBlockedParamKeys) {
        sanitized.remove(key);
      }
    }
    return sanitized;
  }

  static double? readDouble(Map<String, dynamic> source, String key) {
    final value = source[key];
    if (value is num) {
      return value.toDouble();
    }
    if (value is String) {
      return double.tryParse(value);
    }
    return null;
  }

  static int? readInt(Map<String, dynamic> source, String key) {
    final value = source[key];
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.round();
    }
    if (value is String) {
      return int.tryParse(value);
    }
    return null;
  }

  static int? readMaxTokens(Map<String, dynamic> source) {
    for (final key in tokenLimitAliases) {
      final value = readInt(source, key);
      if (value != null) {
        return value;
      }
    }
    return null;
  }

  static List<String> codexFixedValueGuidance() {
    return const [
      '`instructions` is derived from system messages automatically.',
      '`store` is fixed to `false`.',
      '`stream` is fixed to `true`.',
      '`originator`, `OpenAI-Beta`, and `ChatGPT-Account-Id` are managed automatically.',
    ];
  }

  static List<String> codexUnsupportedGuidance() {
    return const [
      '`temperature` and `top_p` are omitted by default because Codex rejects them in normal reasoning flows.',
      '`max_output_tokens` / `max_tokens` are omitted because the Codex backend rejects them.',
      'Avoid arbitrary raw params unless they are known-safe Codex fields such as `reasoning`, `tools`, `tool_choice`, or `truncation`.',
    ];
  }
}

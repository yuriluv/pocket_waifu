// ============================================================================
// 설정 모델 (Settings Model) - v2
// ============================================================================
// 이 파일은 앱의 설정값들을 정의합니다.
// API 키, 모델 선택, 생성 파라미터 등을 관리합니다.
// GitHub Copilot API 지원이 추가되었습니다.
// ============================================================================

/// 사용할 AI API 제공자를 정의하는 열거형
enum ApiProvider {
  openai,    // OpenAI (GPT 모델)
  anthropic, // Anthropic (Claude 모델)
  copilot,   // GitHub Copilot
}

/// 앱 설정을 담는 클래스
class AppSettings {
  // === API 설정 ===
  final ApiProvider apiProvider;  // 현재 선택된 API 제공자
  final String openaiApiKey;      // OpenAI API 키
  final String anthropicApiKey;   // Anthropic API 키
  final String copilotApiKey;     // GitHub Copilot API 키 (gho_xxxxx)
  final String openaiModel;       // OpenAI 모델명 (예: gpt-4, gpt-3.5-turbo)
  final String anthropicModel;    // Anthropic 모델명 (예: claude-3-opus)
  final String copilotModel;      // Copilot 모델명 (예: gpt-4o)
  
  // === 생성 파라미터 ===
  // 이 값들은 AI가 텍스트를 생성할 때 영향을 줍니다
  final double temperature;       // 온도: 높을수록 창의적, 낮을수록 일관적 (0.0~2.0)
  final double topP;              // Top-P: 확률 분포 자르기 (0.0~1.0)
  final int maxTokens;            // 최대 토큰 수: AI 응답의 최대 길이
  final double frequencyPenalty;  // 빈도 패널티: 반복 단어 억제 (-2.0~2.0)
  final double presencePenalty;   // 존재 패널티: 새로운 주제 유도 (-2.0~2.0)

  // === 프롬프트 설정 ===
  final String systemPrompt;      // 시스템 프롬프트 (AI에게 주는 기본 지시사항)
  final String jailbreakPrompt;   // 탈옥 프롬프트 (제한 해제용, 선택사항)
  final bool useJailbreak;        // 탈옥 프롬프트 사용 여부

  /// AppSettings 생성자
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
    this.jailbreakPrompt = '',
    this.useJailbreak = false,
  });

  /// 현재 선택된 API 제공자의 API 키를 반환합니다
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

  /// 현재 선택된 모델명을 반환합니다
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

  /// API 제공자 이름을 문자열로 반환합니다
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

  /// AppSettings 객체를 Map으로 변환합니다 (저장용)
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
      'jailbreakPrompt': jailbreakPrompt,
      'useJailbreak': useJailbreak,
    };
  }

  /// Map에서 AppSettings 객체를 생성합니다 (불러오기용)
  factory AppSettings.fromMap(Map<String, dynamic> map) {
    // 문자열을 ApiProvider로 변환
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
      jailbreakPrompt: map['jailbreakPrompt'] ?? '',
      useJailbreak: map['useJailbreak'] ?? false,
    );
  }

  /// 설정 복사본을 만듭니다 (일부 속성만 변경할 때 사용)
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
    String? jailbreakPrompt,
    bool? useJailbreak,
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
      jailbreakPrompt: jailbreakPrompt ?? this.jailbreakPrompt,
      useJailbreak: useJailbreak ?? this.useJailbreak,
    );
  }
}

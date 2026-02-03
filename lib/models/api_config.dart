// ============================================================================
// API 설정 모델 (API Config Model)
// ============================================================================
// SillyTavern 스타일의 범용 API 설정 모델입니다.
// 특정 서비스(OpenAI, Claude)에 종속되지 않고, 사용자가 직접 모든 값을 설정합니다.
// ============================================================================

import 'package:uuid/uuid.dart';

/// 범용 API 설정 클래스
/// 사용자가 직접 API 엔드포인트, 헤더, 파라미터를 정의합니다
class ApiConfig {
  final String id;                              // 고유 ID
  String name;                                  // 프리셋 이름 (예: "My Copilot", "OpenAI GPT-4")
  String baseUrl;                               // API 베이스 URL
  String apiKey;                                // API 키
  String modelName;                             // 모델명 (예: "gpt-4o", "claude-3-opus")
  Map<String, String> customHeaders;            // 커스텀 HTTP 헤더
  Map<String, dynamic> additionalParams;        // 추가 요청 파라미터 (temperature 등)
  bool isDefault;                               // 기본 프리셋 여부 (삭제 불가)
  DateTime createdAt;                           // 생성 시간

  /// ApiConfig 생성자
  ApiConfig({
    String? id,
    required this.name,
    this.baseUrl = '',
    this.apiKey = '',
    this.modelName = '',
    Map<String, String>? customHeaders,
    Map<String, dynamic>? additionalParams,
    this.isDefault = false,
    DateTime? createdAt,
  })  : id = id ?? const Uuid().v4(),
        customHeaders = customHeaders ?? {},
        additionalParams = additionalParams ?? _defaultParams(),
        createdAt = createdAt ?? DateTime.now();

  /// 기본 파라미터
  static Map<String, dynamic> _defaultParams() {
    return {
      'temperature': 0.9,
      'max_tokens': 1024,
      'top_p': 1.0,
    };
  }

  /// API 키가 설정되어 있는지 확인
  bool get hasApiKey => apiKey.isNotEmpty;

  /// URL이 유효한지 확인
  bool get hasValidUrl => baseUrl.isNotEmpty && baseUrl.startsWith('http');

  /// 설정이 사용 가능한지 확인
  bool get isConfigured => hasApiKey && hasValidUrl && modelName.isNotEmpty;

  /// ApiConfig를 Map으로 변환 (저장용)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'baseUrl': baseUrl,
      'apiKey': apiKey,
      'modelName': modelName,
      'customHeaders': customHeaders,
      'additionalParams': additionalParams,
      'isDefault': isDefault,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  /// Map에서 ApiConfig 생성 (불러오기용)
  factory ApiConfig.fromMap(Map<String, dynamic> map) {
    return ApiConfig(
      id: map['id'],
      name: map['name'] ?? '새 API 설정',
      baseUrl: map['baseUrl'] ?? '',
      apiKey: map['apiKey'] ?? '',
      modelName: map['modelName'] ?? '',
      customHeaders: Map<String, String>.from(map['customHeaders'] ?? {}),
      additionalParams: Map<String, dynamic>.from(map['additionalParams'] ?? _defaultParams()),
      isDefault: map['isDefault'] ?? false,
      createdAt: map['createdAt'] != null 
          ? DateTime.parse(map['createdAt']) 
          : DateTime.now(),
    );
  }

  /// 복사본 생성
  ApiConfig copyWith({
    String? id,
    String? name,
    String? baseUrl,
    String? apiKey,
    String? modelName,
    Map<String, String>? customHeaders,
    Map<String, dynamic>? additionalParams,
    bool? isDefault,
    DateTime? createdAt,
  }) {
    return ApiConfig(
      id: id ?? this.id,
      name: name ?? this.name,
      baseUrl: baseUrl ?? this.baseUrl,
      apiKey: apiKey ?? this.apiKey,
      modelName: modelName ?? this.modelName,
      customHeaders: customHeaders ?? Map.from(this.customHeaders),
      additionalParams: additionalParams ?? Map.from(this.additionalParams),
      isDefault: isDefault ?? this.isDefault,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  // ============================================================================
  // 기본 프리셋 팩토리 메서드
  // ============================================================================

  /// GitHub Copilot 프리셋 (기본)
  factory ApiConfig.copilotDefault() {
    return ApiConfig(
      id: 'copilot_default',
      name: 'GitHub Copilot',
      baseUrl: 'https://api.githubcopilot.com/chat/completions',
      apiKey: '',  // 사용자가 입력
      modelName: 'gpt-4o',
      customHeaders: {
        'Editor-Version': 'vscode/1.85.0',
        'Editor-Plugin-Version': 'copilot/1.0.0',
        'Copilot-Integration-Id': 'vscode-chat',
      },
      additionalParams: {
        'temperature': 0.9,
        'max_tokens': 2048,
        'top_p': 1.0,
        'stream': false,
      },
      isDefault: true,
    );
  }

  /// OpenAI 프리셋
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
        'max_tokens': 1024,
        'top_p': 1.0,
        'frequency_penalty': 0.0,
        'presence_penalty': 0.0,
      },
      isDefault: true,
    );
  }

  /// Anthropic Claude 프리셋
  factory ApiConfig.anthropicDefault() {
    return ApiConfig(
      id: 'anthropic_default',
      name: 'Anthropic Claude',
      baseUrl: 'https://api.anthropic.com/v1/messages',
      apiKey: '',
      modelName: 'claude-3-5-sonnet-20241022',
      customHeaders: {
        'anthropic-version': '2023-06-01',
      },
      additionalParams: {
        'temperature': 0.9,
        'max_tokens': 1024,
      },
      isDefault: true,
    );
  }

  /// OpenRouter 프리셋
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
      additionalParams: {
        'temperature': 0.9,
        'max_tokens': 1024,
      },
      isDefault: true,
    );
  }

  /// 빈 커스텀 프리셋
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
      id: id,  // null이면 생성자에서 UUID 생성
      name: name ?? '커스텀 API',
      baseUrl: baseUrl ?? 'https://api.openai.com/v1/chat/completions',
      apiKey: apiKey ?? '',
      modelName: modelName ?? 'gpt-4o',
      customHeaders: customHeaders ?? {},
      additionalParams: additionalParams ?? _defaultParams(),
      isDefault: false,
    );
  }

  @override
  String toString() {
    return 'ApiConfig(id: $id, name: $name, model: $modelName, configured: $isConfigured)';
  }
}

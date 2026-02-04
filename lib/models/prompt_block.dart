// ============================================================================
// 프롬프트 블록 모델 (Prompt Block Model) - v2.0.2
// ============================================================================
// SillyTavern 스타일의 프롬프트 블록 시스템을 위한 데이터 모델입니다.
// 각 블록은 프롬프트의 한 부분을 담당하며, 순서 변경/활성화/비활성화가 가능합니다.
// v2.0.2: read-only 블록 지원 (과거 기억, 사용자 입력)
// ============================================================================

import 'package:uuid/uuid.dart';

/// 프롬프트 블록 클래스
/// 프롬프트를 구성하는 각 블록(조각)을 나타냅니다
class PromptBlock {
  final String id; // 블록 고유 ID
  String name; // 블록 이름 (예: "시스템 프롬프트", "캐릭터 설정")
  String type; // 블록 타입 (시스템 블록 구분용)
  String content; // 프롬프트 내용
  bool isEnabled; // 활성화 여부 (비활성화 시 최종 프롬프트에 포함 안 됨)
  bool isSystemBlock; // 기본 블록 여부 (true면 삭제 불가)
  int order; // 정렬 순서 (낮을수록 먼저 배치)

  // 구버전 호환성 getter (id를 type처럼 사용한 경우)
  bool get enabled => isEnabled;

  /// ⭐ v2.0.2: read-only 여부 (과거 기억, 사용자 입력은 수정 불가)
  bool get isReadOnly => type == TYPE_PAST_MEMORY || type == TYPE_USER_INPUT;

  // === 기본 블록 타입 상수 ===
  // 이 ID를 가진 블록은 시스템에서 특별하게 처리됩니다

  /// 과거 대화 기억 블록 - 이전 대화 내역을 XML 형식으로 포함
  static const String TYPE_PAST_MEMORY = 'past_memory';

  /// 사용자 입력 블록 - 현재 사용자가 입력한 메시지 (항상 마지막에 위치)
  static const String TYPE_USER_INPUT = 'user_input';

  /// 시스템 프롬프트 블록 - AI에게 주는 기본 지시사항
  static const String TYPE_SYSTEM_PROMPT = 'system_prompt';

  /// 캐릭터 설정 블록 - 캐릭터 정보
  static const String TYPE_CHARACTER = 'character';

  /// PromptBlock 생성자
  PromptBlock({
    String? id,
    required this.name,
    String? type,
    this.content = '',
    this.isEnabled = true,
    this.isSystemBlock = false,
    this.order = 0,
  }) : id = id ?? const Uuid().v4(),
       type = type ?? 'custom';

  /// PromptBlock을 Map으로 변환 (저장용)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'content': content,
      'isEnabled': isEnabled,
      'isSystemBlock': isSystemBlock,
      'order': order,
    };
  }

  /// Map에서 PromptBlock 생성 (불러오기용)
  factory PromptBlock.fromMap(Map<String, dynamic> map) {
    return PromptBlock(
      id: map['id'],
      name: map['name'] ?? '',
      type: map['type'] ?? 'custom',
      content: map['content'] ?? '',
      isEnabled: map['isEnabled'] ?? true,
      isSystemBlock: map['isSystemBlock'] ?? false,
      order: map['order'] ?? 0,
    );
  }

  /// 블록 복사본 생성 (일부 속성만 변경)
  PromptBlock copyWith({
    String? id,
    String? name,
    String? type,
    String? content,
    bool? isEnabled,
    bool? isSystemBlock,
    int? order,
  }) {
    return PromptBlock(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      content: content ?? this.content,
      isEnabled: isEnabled ?? this.isEnabled,
      isSystemBlock: isSystemBlock ?? this.isSystemBlock,
      order: order ?? this.order,
    );
  }

  /// 과거 기억 블록 생성 (기본 블록)
  factory PromptBlock.pastMemory() {
    return PromptBlock(
      id: TYPE_PAST_MEMORY,
      name: '📜 과거 기억',
      type: TYPE_PAST_MEMORY,
      content: '', // 런타임에 대화 내역으로 채워짐
      isEnabled: true,
      isSystemBlock: true,
      order: 100, // 중간 정도 위치
    );
  }

  /// 사용자 입력 블록 생성 (기본 블록)
  factory PromptBlock.userInput() {
    return PromptBlock(
      id: TYPE_USER_INPUT,
      name: '💬 사용자 입력',
      type: TYPE_USER_INPUT,
      content: '', // 런타임에 현재 입력으로 채워짐
      isEnabled: true,
      isSystemBlock: true,
      order: 999, // 항상 마지막
    );
  }

  /// 시스템 프롬프트 블록 생성 (기본 블록)
  factory PromptBlock.systemPrompt() {
    return PromptBlock(
      id: TYPE_SYSTEM_PROMPT,
      name: '⚙️ 시스템 프롬프트',
      type: TYPE_SYSTEM_PROMPT,
      content: '''당신은 롤플레이 AI입니다.
아래의 캐릭터 정보와 시나리오에 따라 일관되게 행동하세요.
항상 캐릭터로서 응답하며, AI라는 사실을 언급하지 마세요.''',
      isEnabled: true,
      isSystemBlock: true,
      order: 0, // 맨 처음
    );
  }

  /// 캐릭터 설정 블록 생성 (기본 블록)
  factory PromptBlock.character() {
    return PromptBlock(
      id: TYPE_CHARACTER,
      name: '👤 캐릭터 설정',
      type: TYPE_CHARACTER,
      content: '''[캐릭터 이름]
미카

[캐릭터 설명]
미카는 20대 초반의 밝고 귀여운 여성입니다.
긴 검은 머리에 큰 눈을 가지고 있으며, 항상 웃는 얼굴입니다.

[성격]
- 밝고 긍정적인 성격
- 장난기가 많고 귀여운 말투를 사용
- 이모티콘과 감탄사를 자주 사용

[시나리오]
당신은 미카의 주인이며, 미카는 당신과 함께 사는 AI 동반자입니다.''',
      isEnabled: true,
      isSystemBlock: true,
      order: 10,
    );
  }

  @override
  String toString() {
    return 'PromptBlock(id: $id, name: $name, enabled: $isEnabled, order: $order)';
  }
}

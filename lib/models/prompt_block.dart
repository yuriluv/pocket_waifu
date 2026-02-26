// ============================================================================
// ============================================================================
// ============================================================================

import 'package:uuid/uuid.dart';

class PromptBlock {
  final String id;
  String name;
  String type;
  String content;
  bool isEnabled;
  bool isSystemBlock;
  int order;

  bool get enabled => isEnabled;

  bool get isReadOnly => type == TYPE_PAST_MEMORY || type == TYPE_USER_INPUT;


  static const String TYPE_PAST_MEMORY = 'past_memory';

  static const String TYPE_USER_INPUT = 'user_input';

  static const String TYPE_SYSTEM_PROMPT = 'system_prompt';

  static const String TYPE_CHARACTER = 'character';

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

  factory PromptBlock.pastMemory() {
    return PromptBlock(
      id: TYPE_PAST_MEMORY,
      name: '📜 과거 기억',
      type: TYPE_PAST_MEMORY,
      content: '',
      isEnabled: true,
      isSystemBlock: true,
      order: 100,
    );
  }

  factory PromptBlock.userInput() {
    return PromptBlock(
      id: TYPE_USER_INPUT,
      name: '💬 사용자 입력',
      type: TYPE_USER_INPUT,
      content: '',
      isEnabled: true,
      isSystemBlock: true,
      order: 999,
    );
  }

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
      order: 0,
    );
  }

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

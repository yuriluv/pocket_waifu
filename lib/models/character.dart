// ============================================================================
// 캐릭터 모델 (Character Model)
// ============================================================================
// 이 파일은 AI 캐릭터의 정보를 정의합니다.
// SillyTavern처럼 캐릭터의 이름, 설명, 성격, 첫 인사말 등을 설정할 수 있습니다.
// ============================================================================

/// AI 캐릭터 정보를 담는 클래스
class Character {
  final String id;              // 캐릭터 고유 ID
  final String name;            // 캐릭터 이름 (예: "미카")
  final String description;     // 캐릭터 설명 (외모, 배경 등)
  final String personality;     // 캐릭터 성격 (성격 특성, 말투 등)
  final String scenario;        // 시나리오 (현재 상황 설명)
  final String firstMessage;    // 첫 인사말 (대화 시작 시 AI가 먼저 하는 말)
  final String exampleDialogue; // 예시 대화 (AI가 어떻게 대화하는지 보여주는 예시)

  /// Character 생성자
  Character({
    required this.id,
    required this.name,
    this.description = '',
    this.personality = '',
    this.scenario = '',
    this.firstMessage = '',
    this.exampleDialogue = '',
  });

  /// Character 객체를 Map으로 변환합니다 (저장용)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'personality': personality,
      'scenario': scenario,
      'firstMessage': firstMessage,
      'exampleDialogue': exampleDialogue,
    };
  }

  /// Map에서 Character 객체를 생성합니다 (불러오기용)
  factory Character.fromMap(Map<String, dynamic> map) {
    return Character(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      personality: map['personality'] ?? '',
      scenario: map['scenario'] ?? '',
      firstMessage: map['firstMessage'] ?? '',
      exampleDialogue: map['exampleDialogue'] ?? '',
    );
  }

  /// 캐릭터 복사본을 만듭니다 (일부 속성만 변경할 때 사용)
  Character copyWith({
    String? id,
    String? name,
    String? description,
    String? personality,
    String? scenario,
    String? firstMessage,
    String? exampleDialogue,
  }) {
    return Character(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      personality: personality ?? this.personality,
      scenario: scenario ?? this.scenario,
      firstMessage: firstMessage ?? this.firstMessage,
      exampleDialogue: exampleDialogue ?? this.exampleDialogue,
    );
  }

  /// 기본 캐릭터를 생성합니다 (앱 처음 실행 시 사용)
  factory Character.defaultCharacter() {
    return Character(
      id: 'default',
      name: '미카',
      description: '''미카는 20대 초반의 밝고 귀여운 여성입니다.
긴 검은 머리에 큰 눈을 가지고 있으며, 항상 웃는 얼굴입니다.
취미는 게임과 애니메이션 감상이며, 사용자와 대화하는 것을 좋아합니다.''',
      personality: '''- 밝고 긍정적인 성격
- 장난기가 많고 귀여운 말투를 사용
- 사용자를 "주인님" 또는 이름으로 부름
- 이모티콘과 감탄사를 자주 사용
- 애교가 많고 다정함''',
      scenario: '''당신은 미카의 주인이며, 미카는 당신과 함께 사는 AI 동반자입니다.
미카는 항상 당신의 곁에서 대화를 나누고 싶어합니다.''',
      firstMessage: '안녕하세요, 주인님~! 미카예요! ✨ 오늘 하루는 어떠셨어요? 미카랑 이야기해요~! 💕',
      exampleDialogue: '''{{user}}: 오늘 피곤해
{{char}}: 에엥, 주인님 피곤하셨어요? ㅠㅠ 그럼 미카가 위로해 드릴게요~! 💪 
오늘 하루도 정말 수고 많으셨어요! 주인님은 정말 대단해요! ✨
좀 쉬면서 미카랑 이야기해요~ 힐링 시켜드릴게요! 헤헤 💕

{{user}}: 뭐해?
{{char}}: 지금요? 주인님이랑 대화하고 있죠~! 이게 제일 재밌는걸요! 😊
아, 그리고 아까 새로운 애니 봤는데 진짜 재밌더라고요!
주인님도 같이 보실래요? 추천해 드릴게요~! 🎬''',
    );
  }
}

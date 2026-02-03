// ============================================================================
// 메시지 모델 (Message Model)
// ============================================================================
// 이 파일은 채팅에서 주고받는 메시지 하나를 정의합니다.
// 각 메시지는 누가 보냈는지(역할), 내용, 시간 정보를 가집니다.
// ============================================================================

/// 메시지를 보낸 사람의 역할을 정의하는 열거형(enum)
/// - user: 사용자가 보낸 메시지
/// - assistant: AI가 보낸 메시지  
/// - system: 시스템 메시지 (보통 AI에게 주는 지시사항)
enum MessageRole {
  user,      // 사용자
  assistant, // AI 어시스턴트
  system,    // 시스템 (배경 설정 등)
}

/// 채팅 메시지 하나를 나타내는 클래스
class Message {
  final String id;           // 메시지 고유 ID (중복 방지용)
  final MessageRole role;    // 메시지를 보낸 역할 (user/assistant/system)
  final String content;      // 메시지 내용
  final DateTime timestamp;  // 메시지가 생성된 시간

  /// Message 생성자
  /// - id: 고유 식별자 (선택사항, 기본값은 빈 문자열)
  /// - role: 메시지 역할
  /// - content: 메시지 내용
  /// - timestamp: 생성 시간 (선택사항, 기본값은 현재 시간)
  Message({
    String? id,
    required this.role,
    required this.content,
    DateTime? timestamp,
  }) : id = id ?? '',
       timestamp = timestamp ?? DateTime.now();

  /// MessageRole을 API가 이해할 수 있는 문자열로 변환합니다
  /// OpenAI와 Anthropic API는 'user', 'assistant', 'system' 문자열을 사용합니다
  String get roleString {
    switch (role) {
      case MessageRole.user:
        return 'user';
      case MessageRole.assistant:
        return 'assistant';
      case MessageRole.system:
        return 'system';
    }
  }

  /// Message 객체를 Map으로 변환합니다 (JSON 저장/API 전송용)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'role': roleString,
      'content': content,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  /// Map에서 Message 객체를 생성합니다 (JSON 불러오기용)
  factory Message.fromMap(Map<String, dynamic> map) {
    // 문자열을 MessageRole로 변환
    MessageRole role;
    switch (map['role']) {
      case 'user':
        role = MessageRole.user;
        break;
      case 'assistant':
        role = MessageRole.assistant;
        break;
      case 'system':
        role = MessageRole.system;
        break;
      default:
        role = MessageRole.user;
    }

    return Message(
      id: map['id'],
      role: role,
      content: map['content'],
      timestamp: DateTime.parse(map['timestamp']),
    );
  }

  /// 메시지 복사본을 만듭니다 (일부 속성만 변경할 때 사용)
  Message copyWith({
    String? id,
    MessageRole? role,
    String? content,
    DateTime? timestamp,
  }) {
    return Message(
      id: id ?? this.id,
      role: role ?? this.role,
      content: content ?? this.content,
      timestamp: timestamp ?? this.timestamp,
    );
  }
}

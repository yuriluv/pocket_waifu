// ============================================================================
// 채팅 세션 모델 (Chat Session Model)
// ============================================================================
// 멀티 채팅 기능을 위한 세션 모델입니다.
// 각 세션은 독립적인 대화 내역을 가지며, 여러 채팅을 동시에 관리할 수 있습니다.
// ============================================================================

import 'package:uuid/uuid.dart';
import 'message.dart';

/// 채팅 세션 클래스
/// 하나의 대화방을 나타내며, 여러 메시지와 메타 정보를 포함합니다
class ChatSession {
  final String id;              // 세션 고유 ID
  String name;                  // 채팅 이름 (사용자가 수정 가능)
  List<Message> messages;       // 대화 메시지 목록
  DateTime createdAt;           // 생성 시간
  DateTime lastModifiedAt;      // 마지막 수정 시간
  String? characterId;          // 연결된 캐릭터 ID (선택사항)

  /// ChatSession 생성자
  ChatSession({
    String? id,
    String? name,
    List<Message>? messages,
    DateTime? createdAt,
    DateTime? lastModifiedAt,
    this.characterId,
  })  : id = id ?? const Uuid().v4(),
        name = name ?? '새 채팅',
        messages = messages ?? [],
        createdAt = createdAt ?? DateTime.now(),
        lastModifiedAt = lastModifiedAt ?? DateTime.now();

  /// 세션에 메시지 추가
  void addMessage(Message message) {
    messages.add(message);
    lastModifiedAt = DateTime.now();
  }

  /// 특정 인덱스의 메시지 삭제
  void deleteMessageAt(int index) {
    if (index >= 0 && index < messages.length) {
      messages.removeAt(index);
      lastModifiedAt = DateTime.now();
    }
  }

  /// 특정 ID의 메시지 삭제
  void deleteMessageById(String messageId) {
    messages.removeWhere((msg) => msg.id == messageId);
    lastModifiedAt = DateTime.now();
  }

  /// 범위 내 메시지 삭제 (0-based index)
  void deleteMessagesInRange(int start, int end) {
    if (start >= 0 && end < messages.length && start <= end) {
      messages.removeRange(start, end + 1);
      lastModifiedAt = DateTime.now();
    }
  }

  /// 특정 인덱스의 메시지 수정 (0-based index)
  void editMessageAt(int index, String newContent) {
    if (index >= 0 && index < messages.length) {
      messages[index] = messages[index].copyWith(content: newContent);
      lastModifiedAt = DateTime.now();
    }
  }

  /// 모든 메시지 삭제
  void clearMessages() {
    messages.clear();
    lastModifiedAt = DateTime.now();
  }

  /// 메시지 개수 반환
  int get messageCount => messages.length;

  /// 마지막 수정 시간 (별명 - chat_list_screen 호환용)
  DateTime get updatedAt => lastModifiedAt;

  /// 마지막 메시지 미리보기 (채팅 목록 표시용)
  String get lastMessagePreview {
    if (messages.isEmpty) return '대화 없음';
    final lastMsg = messages.last;
    final preview = lastMsg.content.length > 50 
        ? '${lastMsg.content.substring(0, 50)}...' 
        : lastMsg.content;
    return preview.replaceAll('\n', ' ');
  }

  /// ChatSession을 Map으로 변환 (저장용)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'messages': messages.map((msg) => msg.toMap()).toList(),
      'createdAt': createdAt.toIso8601String(),
      'lastModifiedAt': lastModifiedAt.toIso8601String(),
      'characterId': characterId,
    };
  }

  /// Map에서 ChatSession 생성 (불러오기용)
  factory ChatSession.fromMap(Map<String, dynamic> map) {
    return ChatSession(
      id: map['id'],
      name: map['name'] ?? '새 채팅',
      messages: (map['messages'] as List<dynamic>?)
          ?.map((msgMap) => Message.fromMap(msgMap))
          .toList() ?? [],
      createdAt: map['createdAt'] != null 
          ? DateTime.parse(map['createdAt']) 
          : DateTime.now(),
      lastModifiedAt: map['lastModifiedAt'] != null 
          ? DateTime.parse(map['lastModifiedAt']) 
          : DateTime.now(),
      characterId: map['characterId'],
    );
  }

  /// 세션 복사본 생성
  ChatSession copyWith({
    String? id,
    String? name,
    List<Message>? messages,
    DateTime? createdAt,
    DateTime? lastModifiedAt,
    String? characterId,
  }) {
    return ChatSession(
      id: id ?? this.id,
      name: name ?? this.name,
      messages: messages ?? List.from(this.messages),
      createdAt: createdAt ?? this.createdAt,
      lastModifiedAt: lastModifiedAt ?? this.lastModifiedAt,
      characterId: characterId ?? this.characterId,
    );
  }

  @override
  String toString() {
    return 'ChatSession(id: $id, name: $name, messages: ${messages.length})';
  }
}

// ============================================================================
// ============================================================================
// ============================================================================

import 'package:uuid/uuid.dart';
import 'message.dart';

class ChatSession {
  final String id;
  String name;
  List<Message> messages;
  DateTime createdAt;
  DateTime lastModifiedAt;
  String? characterId;

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

  void addMessage(Message message) {
    messages.add(message);
    lastModifiedAt = DateTime.now();
  }

  void deleteMessageAt(int index) {
    if (index >= 0 && index < messages.length) {
      messages.removeAt(index);
      lastModifiedAt = DateTime.now();
    }
  }

  void deleteMessageById(String messageId) {
    messages.removeWhere((msg) => msg.id == messageId);
    lastModifiedAt = DateTime.now();
  }

  void deleteMessagesInRange(int start, int end) {
    if (start >= 0 && end < messages.length && start <= end) {
      messages.removeRange(start, end + 1);
      lastModifiedAt = DateTime.now();
    }
  }

  void editMessageAt(int index, String newContent) {
    if (index >= 0 && index < messages.length) {
      messages[index] = messages[index].copyWith(content: newContent);
      lastModifiedAt = DateTime.now();
    }
  }

  void clearMessages() {
    messages.clear();
    lastModifiedAt = DateTime.now();
  }

  int get messageCount => messages.length;

  DateTime get updatedAt => lastModifiedAt;

  String get lastMessagePreview {
    if (messages.isEmpty) return '대화 없음';
    final lastMsg = messages.last;
    final preview = lastMsg.content.length > 50 
        ? '${lastMsg.content.substring(0, 50)}...' 
        : lastMsg.content;
    return preview.replaceAll('\n', ' ');
  }

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

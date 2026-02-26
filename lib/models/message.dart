// ============================================================================
// ============================================================================
// ============================================================================

enum MessageRole {
  user,
  assistant,
  system,
}

class Message {
  final String id;
  final String? chatId;
  final MessageRole role;
  final String content;
  final DateTime timestamp;
  final Map<String, dynamic>? metadata;

  Message({
    String? id,
    this.chatId,
    required this.role,
    required this.content,
    DateTime? timestamp,
    this.metadata,
  }) : id = id ?? '',
       timestamp = timestamp ?? DateTime.now();

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

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'chatId': chatId, // v2.0.1
      'role': roleString,
      'content': content,
      'timestamp': timestamp.toIso8601String(),
      'metadata': metadata, // v2.0.1
    };
  }

  factory Message.fromMap(Map<String, dynamic> map) {
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
      chatId: map['chatId'], // v2.0.1
      role: role,
      content: map['content'],
      timestamp: map['timestamp'] != null
          ? DateTime.parse(map['timestamp'])
          : DateTime.now(),
      metadata: map['metadata'] != null
          ? Map<String, dynamic>.from(map['metadata'])
          : null, // v2.0.1
    );
  }

  Message copyWith({
    String? id,
    String? chatId,
    MessageRole? role,
    String? content,
    DateTime? timestamp,
    Map<String, dynamic>? metadata,
  }) {
    return Message(
      id: id ?? this.id,
      chatId: chatId ?? this.chatId,
      role: role ?? this.role,
      content: content ?? this.content,
      timestamp: timestamp ?? this.timestamp,
      metadata: metadata ?? this.metadata,
    );
  }
}

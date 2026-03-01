// ============================================================================
// ============================================================================
// ============================================================================

enum MessageRole { user, assistant, system }

class ImageAttachment {
  final String id;
  final String base64Data;
  final String mimeType;
  final int width;
  final int height;
  final String? thumbnailPath;

  const ImageAttachment({
    required this.id,
    required this.base64Data,
    required this.mimeType,
    this.width = 0,
    this.height = 0,
    this.thumbnailPath,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'base64Data': base64Data,
      'mimeType': mimeType,
      'width': width,
      'height': height,
      'thumbnailPath': thumbnailPath,
    };
  }

  ImageAttachment copyWith({
    String? id,
    String? base64Data,
    String? mimeType,
    int? width,
    int? height,
    String? thumbnailPath,
  }) {
    return ImageAttachment(
      id: id ?? this.id,
      base64Data: base64Data ?? this.base64Data,
      mimeType: mimeType ?? this.mimeType,
      width: width ?? this.width,
      height: height ?? this.height,
      thumbnailPath: thumbnailPath ?? this.thumbnailPath,
    );
  }

  factory ImageAttachment.fromMap(Map<String, dynamic> map) {
    return ImageAttachment(
      id: map['id']?.toString() ?? '',
      base64Data: map['base64Data']?.toString() ?? '',
      mimeType: map['mimeType']?.toString() ?? 'image/jpeg',
      width: map['width'] is int ? map['width'] as int : 0,
      height: map['height'] is int ? map['height'] as int : 0,
      thumbnailPath: map['thumbnailPath']?.toString(),
    );
  }
}

class Message {
  final String id;
  final String? chatId;
  final MessageRole role;
  final String content;
  final DateTime timestamp;
  final Map<String, dynamic>? metadata;
  final List<ImageAttachment> images;

  Message({
    String? id,
    this.chatId,
    required this.role,
    required this.content,
    DateTime? timestamp,
    this.metadata,
    this.images = const [],
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
      'images': images.map((image) => image.toMap()).toList(),
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
      images: map['images'] is List
          ? (map['images'] as List)
                .whereType<Map>()
                .map(
                  (item) =>
                      ImageAttachment.fromMap(Map<String, dynamic>.from(item)),
                )
                .toList()
          : const [],
    );
  }

  Message copyWith({
    String? id,
    String? chatId,
    MessageRole? role,
    String? content,
    DateTime? timestamp,
    Map<String, dynamic>? metadata,
    List<ImageAttachment>? images,
  }) {
    return Message(
      id: id ?? this.id,
      chatId: chatId ?? this.chatId,
      role: role ?? this.role,
      content: content ?? this.content,
      timestamp: timestamp ?? this.timestamp,
      metadata: metadata ?? this.metadata,
      images: images ?? this.images,
    );
  }
}

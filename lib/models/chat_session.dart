// ============================================================================
// ============================================================================
// ============================================================================

import 'package:uuid/uuid.dart';
import 'chat_variable_scope.dart';
import 'message.dart';
import 'session_interaction_state.dart';
import 'session_variable_store.dart';

class ChatSession {
  final String id;
  String name;
  List<Message> messages;
  DateTime createdAt;
  DateTime lastModifiedAt;
  String? characterId;
  SessionVariableStore variableStore;
  SessionInteractionState interactionState;

  ChatSession({
    String? id,
    String? name,
    List<Message>? messages,
    DateTime? createdAt,
    DateTime? lastModifiedAt,
    this.characterId,
    SessionVariableStore? variableStore,
    SessionInteractionState? interactionState,
  })  : id = id ?? const Uuid().v4(),
        name = name ?? '새 채팅',
        messages = messages ?? [],
        createdAt = createdAt ?? DateTime.now(),
        lastModifiedAt = lastModifiedAt ?? DateTime.now(),
        variableStore = variableStore ?? SessionVariableStore.empty(),
        interactionState = interactionState ?? const SessionInteractionState();

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

  Map<String, String> variablesForScope(ChatVariableScope scope) {
    return variableStore.values[scope] ?? const <String, String>{};
  }

  Map<String, String> aliasesForScope(ChatVariableScope scope) {
    return variableStore.aliases[scope] ?? const <String, String>{};
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
      'variableStore': variableStore.toMap(),
      'interactionState': interactionState.toMap(),
    };
  }

  Map<String, dynamic> toMetadataMap() {
    return {
      'id': id,
      'name': name,
      'messages': const <Map<String, dynamic>>[],
      'createdAt': createdAt.toIso8601String(),
      'lastModifiedAt': lastModifiedAt.toIso8601String(),
      'characterId': characterId,
      'variableStore': variableStore.toMap(),
      'interactionState': interactionState.toMap(),
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
      variableStore: SessionVariableStore.fromMap(
        map['variableStore'] is Map<String, dynamic>
            ? map['variableStore'] as Map<String, dynamic>
            : map['variableStore'] is Map
            ? Map<String, dynamic>.from(map['variableStore'] as Map)
            : null,
      ),
      interactionState: SessionInteractionState.fromMap(
        map['interactionState'] is Map<String, dynamic>
            ? map['interactionState'] as Map<String, dynamic>
            : map['interactionState'] is Map
            ? Map<String, dynamic>.from(map['interactionState'] as Map)
            : null,
      ),
    );
  }

  ChatSession copyWith({
    String? id,
    String? name,
    List<Message>? messages,
    DateTime? createdAt,
    DateTime? lastModifiedAt,
    String? characterId,
    SessionVariableStore? variableStore,
    SessionInteractionState? interactionState,
  }) {
    return ChatSession(
      id: id ?? this.id,
      name: name ?? this.name,
      messages: messages ?? List.from(this.messages),
      createdAt: createdAt ?? this.createdAt,
      lastModifiedAt: lastModifiedAt ?? this.lastModifiedAt,
      characterId: characterId ?? this.characterId,
      variableStore: variableStore ?? this.variableStore.copyWith(),
      interactionState: interactionState ?? this.interactionState,
    );
  }

  @override
  String toString() {
    return 'ChatSession(id: $id, name: $name, messages: ${messages.length})';
  }
}

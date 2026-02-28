import 'package:uuid/uuid.dart';

enum LuaScriptScope { global, perCharacter }

class LuaScript {
  LuaScript({
    String? id,
    required this.name,
    required this.content,
    this.isEnabled = true,
    this.order = 0,
    this.scope = LuaScriptScope.global,
    this.characterId,
  }) : id = id ?? const Uuid().v4();

  final String id;
  final String name;
  final String content;
  final bool isEnabled;
  final int order;
  final LuaScriptScope scope;
  final String? characterId;

  LuaScript copyWith({
    String? id,
    String? name,
    String? content,
    bool? isEnabled,
    int? order,
    LuaScriptScope? scope,
    String? characterId,
  }) {
    return LuaScript(
      id: id ?? this.id,
      name: name ?? this.name,
      content: content ?? this.content,
      isEnabled: isEnabled ?? this.isEnabled,
      order: order ?? this.order,
      scope: scope ?? this.scope,
      characterId: characterId ?? this.characterId,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'content': content,
      'isEnabled': isEnabled,
      'order': order,
      'scope': scope.name,
      'characterId': characterId,
    };
  }

  factory LuaScript.fromMap(Map<String, dynamic> map) {
    return LuaScript(
      id: map['id'] as String?,
      name: map['name'] as String? ?? 'script.lua',
      content: map['content'] as String? ?? '',
      isEnabled: map['isEnabled'] != false,
      order: map['order'] as int? ?? 0,
      scope: (map['scope'] as String?) == 'perCharacter'
          ? LuaScriptScope.perCharacter
          : LuaScriptScope.global,
      characterId: map['characterId'] as String?,
    );
  }
}

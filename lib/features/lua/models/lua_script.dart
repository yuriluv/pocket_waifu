import 'package:uuid/uuid.dart';

enum LuaScriptScope { global, perCharacter }

enum LuaScriptRuntimeMode { legacyCompatible, realRuntimeNative }

class LuaScript {
  static const int currentSchemaVersion = 2;

  LuaScript({
    String? id,
    required this.name,
    required this.content,
    this.isEnabled = true,
    this.order = 0,
    this.scope = LuaScriptScope.global,
    this.characterId,
    this.schemaVersion = currentSchemaVersion,
    this.runtimeMode = LuaScriptRuntimeMode.legacyCompatible,
  }) : id = id ?? const Uuid().v4();

  final String id;
  final String name;
  final String content;
  final bool isEnabled;
  final int order;
  final LuaScriptScope scope;
  final String? characterId;
  final int schemaVersion;
  final LuaScriptRuntimeMode runtimeMode;

  LuaScript copyWith({
    String? id,
    String? name,
    String? content,
    bool? isEnabled,
    int? order,
    LuaScriptScope? scope,
    String? characterId,
    int? schemaVersion,
    LuaScriptRuntimeMode? runtimeMode,
  }) {
    return LuaScript(
      id: id ?? this.id,
      name: name ?? this.name,
      content: content ?? this.content,
      isEnabled: isEnabled ?? this.isEnabled,
      order: order ?? this.order,
      scope: scope ?? this.scope,
      characterId: characterId ?? this.characterId,
      schemaVersion: schemaVersion ?? this.schemaVersion,
      runtimeMode: runtimeMode ?? this.runtimeMode,
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
      'schemaVersion': schemaVersion,
      'runtimeMode': runtimeMode.name,
    };
  }

  factory LuaScript.fromMap(Map<String, dynamic> map) {
    final parsedSchemaVersion = _parseInt(map['schemaVersion']) ?? 1;
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
      schemaVersion: parsedSchemaVersion,
      runtimeMode:
          _parseRuntimeMode(map['runtimeMode'] as String?) ??
          LuaScriptRuntimeMode.legacyCompatible,
    );
  }

  static int? _parseInt(Object? value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      return int.tryParse(value.trim());
    }
    return null;
  }

  static LuaScriptRuntimeMode? _parseRuntimeMode(String? value) {
    return switch (value) {
      'realRuntimeNative' => LuaScriptRuntimeMode.realRuntimeNative,
      'legacyCompatible' => LuaScriptRuntimeMode.legacyCompatible,
      _ => null,
    };
  }
}

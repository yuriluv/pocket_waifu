import 'chat_variable_scope.dart';

class SessionVariableStore {
  SessionVariableStore({
    Map<ChatVariableScope, Map<String, String>>? values,
    Map<ChatVariableScope, Map<String, String>>? aliases,
  }) : values = values ?? _emptyScopeMaps(),
       aliases = aliases ?? _emptyScopeMaps();

  final Map<ChatVariableScope, Map<String, String>> values;
  final Map<ChatVariableScope, Map<String, String>> aliases;

  static Map<ChatVariableScope, Map<String, String>> _emptyScopeMaps() {
    return {
      for (final scope in ChatVariableScope.values) scope: <String, String>{},
    };
  }

  factory SessionVariableStore.empty() => SessionVariableStore();

  factory SessionVariableStore.fromMap(Map<String, dynamic>? map) {
    if (map == null) {
      return SessionVariableStore.empty();
    }

    Map<ChatVariableScope, Map<String, String>> decodeScopeMap(String key) {
      final raw = map[key];
      final out = _emptyScopeMaps();
      if (raw is! Map) {
        return out;
      }
      for (final entry in raw.entries) {
        final scope = ChatVariableScopeX.fromStorageKey(entry.key.toString());
        final scopeMap = <String, String>{};
        if (entry.value is Map) {
          final scopeRaw = Map<String, dynamic>.from(entry.value as Map);
          for (final variableEntry in scopeRaw.entries) {
            final variableName = variableEntry.key.trim();
            if (variableName.isEmpty) continue;
            scopeMap[variableName] = variableEntry.value?.toString() ?? 'null';
          }
        }
        out[scope] = scopeMap;
      }
      return out;
    }

    return SessionVariableStore(
      values: decodeScopeMap('values'),
      aliases: decodeScopeMap('aliases'),
    );
  }

  Map<String, dynamic> toMap() {
    Map<String, dynamic> encodeScopeMap(
      Map<ChatVariableScope, Map<String, String>> source,
    ) {
      return {
        for (final entry in source.entries)
          entry.key.storageKey: Map<String, String>.from(entry.value),
      };
    }

    return {
      'values': encodeScopeMap(values),
      'aliases': encodeScopeMap(aliases),
    };
  }

  SessionVariableStore copyWith({
    Map<ChatVariableScope, Map<String, String>>? values,
    Map<ChatVariableScope, Map<String, String>>? aliases,
  }) {
    return SessionVariableStore(
      values: values ?? cloneScopeMap(this.values),
      aliases: aliases ?? cloneScopeMap(this.aliases),
    );
  }

  static Map<ChatVariableScope, Map<String, String>> cloneScopeMap(
    Map<ChatVariableScope, Map<String, String>> source,
  ) {
    return {
      for (final scope in ChatVariableScope.values)
        scope: Map<String, String>.from(source[scope] ?? const <String, String>{}),
    };
  }
}

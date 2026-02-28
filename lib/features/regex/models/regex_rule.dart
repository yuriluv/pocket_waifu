import 'package:uuid/uuid.dart';

enum RegexRuleType { userInput, aiOutput, promptInjection, displayOnly }

enum RegexRuleScope { global, perCharacter, perSession }

class RegexRule {
  RegexRule({
    String? id,
    required this.name,
    this.description = '',
    required this.type,
    required this.pattern,
    required this.replacement,
    this.caseInsensitive = false,
    this.multiLine = false,
    this.dotAll = false,
    this.isEnabled = true,
    this.priority = 0,
    this.scope = RegexRuleScope.global,
    this.associatedCharacterId,
    this.associatedSessionId,
  }) : id = id ?? const Uuid().v4();

  final String id;
  final String name;
  final String description;
  final RegexRuleType type;
  final String pattern;
  final String replacement;
  final bool caseInsensitive;
  final bool multiLine;
  final bool dotAll;
  final bool isEnabled;
  final int priority;
  final RegexRuleScope scope;
  final String? associatedCharacterId;
  final String? associatedSessionId;

  RegExp buildRegex() {
    return RegExp(
      pattern,
      caseSensitive: !caseInsensitive,
      multiLine: multiLine,
      dotAll: dotAll,
    );
  }

  RegexRule copyWith({
    String? id,
    String? name,
    String? description,
    RegexRuleType? type,
    String? pattern,
    String? replacement,
    bool? caseInsensitive,
    bool? multiLine,
    bool? dotAll,
    bool? isEnabled,
    int? priority,
    RegexRuleScope? scope,
    String? associatedCharacterId,
    String? associatedSessionId,
  }) {
    return RegexRule(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      type: type ?? this.type,
      pattern: pattern ?? this.pattern,
      replacement: replacement ?? this.replacement,
      caseInsensitive: caseInsensitive ?? this.caseInsensitive,
      multiLine: multiLine ?? this.multiLine,
      dotAll: dotAll ?? this.dotAll,
      isEnabled: isEnabled ?? this.isEnabled,
      priority: priority ?? this.priority,
      scope: scope ?? this.scope,
      associatedCharacterId:
          associatedCharacterId ?? this.associatedCharacterId,
      associatedSessionId: associatedSessionId ?? this.associatedSessionId,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'type': type.name,
      'pattern': pattern,
      'replacement': replacement,
      'caseInsensitive': caseInsensitive,
      'multiLine': multiLine,
      'dotAll': dotAll,
      'isEnabled': isEnabled,
      'priority': priority,
      'scope': scope.name,
      'associatedCharacterId': associatedCharacterId,
      'associatedSessionId': associatedSessionId,
    };
  }

  factory RegexRule.fromMap(Map<String, dynamic> map) {
    return RegexRule(
      id: map['id'] as String?,
      name: map['name'] as String? ?? 'Rule',
      description: map['description'] as String? ?? '',
      type: _parseType(map['type'] as String?),
      pattern: map['pattern'] as String? ?? '',
      replacement: map['replacement'] as String? ?? '',
      caseInsensitive: map['caseInsensitive'] == true,
      multiLine: map['multiLine'] == true,
      dotAll: map['dotAll'] == true,
      isEnabled: map['isEnabled'] != false,
      priority: map['priority'] as int? ?? 0,
      scope: _parseScope(map['scope'] as String?),
      associatedCharacterId: map['associatedCharacterId'] as String?,
      associatedSessionId: map['associatedSessionId'] as String?,
    );
  }

  static RegexRuleType _parseType(String? raw) {
    return switch (raw) {
      'userInput' => RegexRuleType.userInput,
      'aiOutput' => RegexRuleType.aiOutput,
      'promptInjection' => RegexRuleType.promptInjection,
      'displayOnly' => RegexRuleType.displayOnly,
      _ => RegexRuleType.aiOutput,
    };
  }

  static RegexRuleScope _parseScope(String? raw) {
    return switch (raw) {
      'global' => RegexRuleScope.global,
      'perCharacter' => RegexRuleScope.perCharacter,
      'perSession' => RegexRuleScope.perSession,
      _ => RegexRuleScope.global,
    };
  }
}

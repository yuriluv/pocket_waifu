import 'prompt_preset_reference.dart';

class AgentPromptRegexRule {
  final String id;
  final String name;
  final String pattern;
  final String replacement;
  final bool isEnabled;
  final bool multiLine;
  final bool dotAll;
  final bool caseSensitive;
  final int priority;

  const AgentPromptRegexRule({
    required this.id,
    required this.name,
    required this.pattern,
    required this.replacement,
    this.isEnabled = true,
    this.multiLine = true,
    this.dotAll = false,
    this.caseSensitive = false,
    this.priority = 0,
  });

  AgentPromptRegexRule copyWith({
    String? id,
    String? name,
    String? pattern,
    String? replacement,
    bool? isEnabled,
    bool? multiLine,
    bool? dotAll,
    bool? caseSensitive,
    int? priority,
  }) {
    return AgentPromptRegexRule(
      id: id ?? this.id,
      name: name ?? this.name,
      pattern: pattern ?? this.pattern,
      replacement: replacement ?? this.replacement,
      isEnabled: isEnabled ?? this.isEnabled,
      multiLine: multiLine ?? this.multiLine,
      dotAll: dotAll ?? this.dotAll,
      caseSensitive: caseSensitive ?? this.caseSensitive,
      priority: priority ?? this.priority,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'pattern': pattern,
      'replacement': replacement,
      'isEnabled': isEnabled,
      'multiLine': multiLine,
      'dotAll': dotAll,
      'caseSensitive': caseSensitive,
      'priority': priority,
    };
  }

  factory AgentPromptRegexRule.fromMap(Map<String, dynamic> map) {
    return AgentPromptRegexRule(
      id: map['id']?.toString() ?? 'rule',
      name: map['name']?.toString() ?? 'Rule',
      pattern: map['pattern']?.toString() ?? '',
      replacement: map['replacement']?.toString() ?? '',
      isEnabled: map['isEnabled'] ?? true,
      multiLine: map['multiLine'] ?? true,
      dotAll: map['dotAll'] ?? false,
      caseSensitive: map['caseSensitive'] ?? false,
      priority: map['priority'] ?? 0,
    );
  }
}

class AgentPromptPreset {
  final String id;
  final String name;
  final String systemPrompt;
  final String replyPrompt;
  final List<AgentPromptRegexRule> regexRules;
  final String luaScript;

  const AgentPromptPreset({
    required this.id,
    required this.name,
    required this.systemPrompt,
    required this.replyPrompt,
    required this.regexRules,
    required this.luaScript,
  });

  PromptPresetReference toReference() {
    return PromptPresetReference(id: id, name: name);
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'systemPrompt': systemPrompt,
      'replyPrompt': replyPrompt,
      'regexRules': regexRules.map((rule) => rule.toMap()).toList(),
      'luaScript': luaScript,
    };
  }

  factory AgentPromptPreset.fromMap(Map<String, dynamic> map) {
    final rawRules = map['regexRules'] as List<dynamic>? ?? const [];
    return AgentPromptPreset(
      id: map['id']?.toString() ?? 'agent_default',
      name: map['name']?.toString() ?? 'Agent Default',
      systemPrompt: map['systemPrompt']?.toString() ?? '',
      replyPrompt: map['replyPrompt']?.toString() ?? '',
      regexRules: rawRules
          .whereType<Map<String, dynamic>>()
          .map(AgentPromptRegexRule.fromMap)
          .toList(),
      luaScript: map['luaScript']?.toString() ?? '',
    );
  }
}

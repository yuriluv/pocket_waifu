import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/regex_rule.dart';

class RegexPipelineService {
  RegexPipelineService._();

  static const String _rulesKey = 'regex_pipeline_rules_v1';
  static final RegexPipelineService instance = RegexPipelineService._();

  List<RegexRule>? _rulesCache;
  final Map<String, RegExp> _compiledCache = {};

  Future<List<RegexRule>> getRules() async {
    if (_rulesCache != null) {
      return _rulesCache!;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_rulesKey);
      if (raw == null || raw.trim().isEmpty) {
        _rulesCache = _defaultRules();
        await prefs.setString(
          _rulesKey,
          jsonEncode(_rulesCache!.map((rule) => rule.toMap()).toList()),
        );
        return _rulesCache!;
      }

      final parsed = jsonDecode(raw);
      if (parsed is! List) {
        _rulesCache = [];
        return _rulesCache!;
      }

      _rulesCache =
          parsed
              .whereType<Map<String, dynamic>>()
              .map(RegexRule.fromMap)
              .toList()
            ..sort((a, b) => a.priority.compareTo(b.priority));
      if (_rulesCache!.isEmpty) {
        _rulesCache = _defaultRules();
        await prefs.setString(
          _rulesKey,
          jsonEncode(_rulesCache!.map((rule) => rule.toMap()).toList()),
        );
      }
      return _rulesCache!;
    } catch (e) {
      debugPrint('RegexPipelineService.getRules failed: $e');
      _rulesCache = [];
      return _rulesCache!;
    }
  }

  Future<void> saveRules(List<RegexRule> rules) async {
    _rulesCache = List<RegexRule>.from(rules)
      ..sort((a, b) => a.priority.compareTo(b.priority));
    _compiledCache.clear();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _rulesKey,
      jsonEncode(_rulesCache!.map((rule) => rule.toMap()).toList()),
    );
  }

  Future<String> applyUserInput(
    String text, {
    String? characterId,
    String? sessionId,
  }) {
    return _apply(
      RegexRuleType.userInput,
      text,
      characterId: characterId,
      sessionId: sessionId,
    );
  }

  Future<String> applyAiOutput(
    String text, {
    String? characterId,
    String? sessionId,
  }) {
    return _apply(
      RegexRuleType.aiOutput,
      text,
      characterId: characterId,
      sessionId: sessionId,
    );
  }

  Future<String> applyPromptInjection(
    String text, {
    String? characterId,
    String? sessionId,
  }) {
    return _apply(
      RegexRuleType.promptInjection,
      text,
      characterId: characterId,
      sessionId: sessionId,
    );
  }

  Future<String> applyDisplayOnly(
    String text, {
    String? characterId,
    String? sessionId,
  }) {
    return _apply(
      RegexRuleType.displayOnly,
      text,
      characterId: characterId,
      sessionId: sessionId,
    );
  }

  Future<String> _apply(
    RegexRuleType type,
    String input, {
    String? characterId,
    String? sessionId,
  }) async {
    var output = input;
    final rules = await getRules();

    final applicable = rules.where((rule) {
      if (!rule.isEnabled || rule.type != type || rule.pattern.isEmpty) {
        return false;
      }
      if (rule.scope == RegexRuleScope.perCharacter &&
          rule.associatedCharacterId != characterId) {
        return false;
      }
      if (rule.scope == RegexRuleScope.perSession &&
          rule.associatedSessionId != sessionId) {
        return false;
      }
      return true;
    }).toList()..sort((a, b) => a.priority.compareTo(b.priority));

    for (final rule in applicable) {
      final stopwatch = Stopwatch()..start();
      if (_isPotentiallyCatastrophic(rule.pattern)) {
        debugPrint('Regex rule skipped by perf guard (${rule.name})');
        continue;
      }
      try {
        final regex = _compiledCache.putIfAbsent(rule.id, rule.buildRegex);
        output = output.replaceAll(regex, rule.replacement);
      } catch (e) {
        debugPrint('Regex rule failed (${rule.name}): $e');
      } finally {
        stopwatch.stop();
      }

      if (stopwatch.elapsedMilliseconds > 200) {
        debugPrint(
          'Regex rule exceeded soft timeout (${rule.name}): '
          '${stopwatch.elapsedMilliseconds}ms',
        );
      }
    }

    return output;
  }

  bool _isPotentiallyCatastrophic(String pattern) {
    final nestedQuantifier = RegExp(r'\([^)]*[+*][^)]*\)[+*]');
    final ambiguousAlternation = RegExp(r'\((?:[^)]*\|){3,}[^)]*\)[+*]');
    return nestedQuantifier.hasMatch(pattern) ||
        ambiguousAlternation.hasMatch(pattern);
  }

  List<RegexRule> _defaultRules() {
    return <RegexRule>[
      RegexRule(
        name: 'Route <live2d> blocks to runtime directives',
        description:
            'AI output ownership: converts public <live2d> blocks into internal runtime directive blocks managed by Regex/Lua.',
        type: RegexRuleType.aiOutput,
        pattern: r'<live2d\b[^>]*>([\s\S]*?)<\/live2d>',
        replacement: r'<pwf-live2d>$1</pwf-live2d>',
        caseInsensitive: true,
        multiLine: true,
        dotAll: true,
        priority: -320,
        scope: RegexRuleScope.global,
      ),
      RegexRule(
        name: 'Route <overlay> blocks to runtime directives',
        description:
            'AI output ownership: converts public <overlay> blocks into internal runtime directive blocks managed by Regex/Lua.',
        type: RegexRuleType.aiOutput,
        pattern: r'<overlay\b[^>]*>([\s\S]*?)<\/overlay>',
        replacement: r'<pwf-overlay>$1</pwf-overlay>',
        caseInsensitive: true,
        multiLine: true,
        dotAll: true,
        priority: -310,
        scope: RegexRuleScope.global,
      ),
      RegexRule(
        name: 'Route Live2D inline directives to runtime',
        description:
            'AI output ownership: converts [param:], [motion:], [expression:], [emotion:], [wait:], [preset:], [reset] into internal runtime directives.',
        type: RegexRuleType.aiOutput,
        pattern:
            r'\[(param|motion|expression|emotion|wait|preset):([^\]]+)\]',
        replacement: r'[pwf-live2d:$1:$2]',
        caseInsensitive: true,
        priority: -300,
        scope: RegexRuleScope.global,
      ),
      RegexRule(
        name: 'Route Live2D reset directives to runtime',
        description:
            'AI output ownership: converts [reset] into the internal runtime directive form.',
        type: RegexRuleType.aiOutput,
        pattern: r'\[reset\]',
        replacement: r'[pwf-live2d:reset:]',
        caseInsensitive: true,
        priority: -295,
        scope: RegexRuleScope.global,
      ),
      RegexRule(
        name: 'Route image overlay inline directives to runtime',
        description:
            'AI output ownership: converts [img_move:] and [img_emotion:] into internal runtime directives.',
        type: RegexRuleType.aiOutput,
        pattern: r'\[(img_move|img_emotion):([^\]]+)\]',
        replacement: r'[pwf-overlay:$1:$2]',
        caseInsensitive: true,
        priority: -290,
        scope: RegexRuleScope.global,
      ),
      RegexRule(
        name: 'Hide <live2d> display blocks',
        description:
            'Display-only cleanup: removes <live2d>...</live2d> so chat and notifications stay clean.',
        type: RegexRuleType.displayOnly,
        pattern: r'<live2d\b[^>]*>[\s\S]*?<\/live2d>',
        replacement: '',
        multiLine: true,
        dotAll: true,
        priority: -200,
        scope: RegexRuleScope.global,
      ),
      RegexRule(
        name: 'Hide internal <pwf-live2d> runtime blocks',
        description:
            'Display-only cleanup: removes internal Live2D runtime blocks after Regex/Lua ownership.',
        type: RegexRuleType.displayOnly,
        pattern: r'<pwf-live2d\b[^>]*>[\s\S]*?<\/pwf-live2d>',
        replacement: '',
        multiLine: true,
        dotAll: true,
        priority: -195,
        scope: RegexRuleScope.global,
      ),
      RegexRule(
        name: 'Hide <overlay> display blocks',
        description:
            'Display-only cleanup: removes <overlay>...</overlay> directive blocks.',
        type: RegexRuleType.displayOnly,
        pattern: r'<overlay\b[^>]*>[\s\S]*?<\/overlay>',
        replacement: '',
        multiLine: true,
        dotAll: true,
        priority: -190,
        scope: RegexRuleScope.global,
      ),
      RegexRule(
        name: 'Hide internal <pwf-overlay> runtime blocks',
        description:
            'Display-only cleanup: removes internal image overlay runtime blocks after Regex/Lua ownership.',
        type: RegexRuleType.displayOnly,
        pattern: r'<pwf-overlay\b[^>]*>[\s\S]*?<\/pwf-overlay>',
        replacement: '',
        multiLine: true,
        dotAll: true,
        priority: -185,
        scope: RegexRuleScope.global,
      ),
      RegexRule(
        name: 'Hide Live2D inline directives',
        description:
            'Display-only cleanup: removes [param:], [motion:], [expression:], [emotion:], [wait:], [preset:], [reset].',
        type: RegexRuleType.displayOnly,
        pattern:
            r'\[(param|motion|expression|emotion|wait|preset):[^\]]+\]|\[reset\]',
        replacement: '',
        caseInsensitive: true,
        priority: -180,
        scope: RegexRuleScope.global,
      ),
      RegexRule(
        name: 'Hide internal Live2D runtime inline directives',
        description:
            'Display-only cleanup: removes [pwf-live2d:...] runtime directives after Regex/Lua ownership.',
        type: RegexRuleType.displayOnly,
        pattern:
            r'\[pwf-live2d:(param|motion|expression|emotion|wait|preset|reset):[^\]]*\]',
        replacement: '',
        caseInsensitive: true,
        priority: -175,
        scope: RegexRuleScope.global,
      ),
      RegexRule(
        name: 'Hide image overlay inline directives',
        description:
            'Display-only cleanup: removes [img_move:] and [img_emotion:] directives.',
        type: RegexRuleType.displayOnly,
        pattern: r'\[(img_move|img_emotion):[^\]]+\]',
        replacement: '',
        caseInsensitive: true,
        priority: -170,
        scope: RegexRuleScope.global,
      ),
      RegexRule(
        name: 'Hide internal image overlay runtime inline directives',
        description:
            'Display-only cleanup: removes [pwf-overlay:...] runtime directives after Regex/Lua ownership.',
        type: RegexRuleType.displayOnly,
        pattern: r'\[pwf-overlay:(img_move|img_emotion):[^\]]+\]',
        replacement: '',
        caseInsensitive: true,
        priority: -165,
        scope: RegexRuleScope.global,
      ),
      RegexRule(
        name: 'Trim directive-only blank lines',
        description:
            'Display-only cleanup: collapses excessive newlines left after directive removal.',
        type: RegexRuleType.displayOnly,
        pattern: r'\n{3,}',
        replacement: '\n\n',
        priority: -160,
        scope: RegexRuleScope.global,
      ),
    ];
  }
}

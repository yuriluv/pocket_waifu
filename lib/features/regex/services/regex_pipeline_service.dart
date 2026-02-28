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
        _rulesCache = [];
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
}

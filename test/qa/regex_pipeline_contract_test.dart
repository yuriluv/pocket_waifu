import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_application_1/features/regex/models/regex_rule.dart';
import 'package:flutter_application_1/features/regex/services/regex_pipeline_service.dart';

void main() {
  group('RegexPipelineService', () {
    test('applies user-input rules by priority', () async {
      SharedPreferences.setMockInitialValues({});
      final service = RegexPipelineService.instance;

      await service.saveRules([
        RegexRule(
          name: 'step1',
          type: RegexRuleType.userInput,
          pattern: 'hello',
          replacement: 'hi',
          priority: 1,
        ),
        RegexRule(
          name: 'step2',
          type: RegexRuleType.userInput,
          pattern: 'hi',
          replacement: 'hey',
          priority: 2,
        ),
      ]);

      final result = await service.applyUserInput('hello');
      expect(result, 'hey');
    });

    test('respects per-session scope', () async {
      SharedPreferences.setMockInitialValues({});
      final service = RegexPipelineService.instance;

      await service.saveRules([
        RegexRule(
          name: 'session-only',
          type: RegexRuleType.aiOutput,
          pattern: 'cat',
          replacement: 'dog',
          scope: RegexRuleScope.perSession,
          associatedSessionId: 's-1',
        ),
      ]);

      final hit = await service.applyAiOutput('cat', sessionId: 's-1');
      final miss = await service.applyAiOutput('cat', sessionId: 's-2');
      expect(hit, 'dog');
      expect(miss, 'cat');
    });
  });
}

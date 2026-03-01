import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_application_1/features/live2d_llm/services/live2d_directive_service.dart';
import 'package:flutter_application_1/features/lua/models/lua_script.dart';
import 'package:flutter_application_1/features/lua/services/lua_scripting_service.dart';
import 'package:flutter_application_1/features/regex/models/regex_rule.dart';
import 'package:flutter_application_1/features/regex/services/regex_pipeline_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final part1Complete = Platform.environment['PART1_COMPLETE'] == 'true';
  final skipUntilPart1Complete = !part1Complete;

  group('Lua sandbox lifecycle hooks', () {
    test(
      'onLoad/onUnload and message hooks execute in order with sandbox guard',
      () async {
        SharedPreferences.setMockInitialValues({});
        final service = LuaScriptingService.instance;
        await service.saveScripts([
          LuaScript(
            name: 'pipeline',
            content: [
              '-- hook:onLoad append:[L]',
              '-- hook:onUserMessage replace:hello=>hi',
              '-- hook:onAssistantMessage append::assistant',
              '-- hook:onDisplayRender prepend:[render]',
              '-- hook:onUnload append:[U]',
              'os.execute("rm -rf /")',
            ].join('\n'),
          ),
        ]);

        final user = await service.onUserMessage(
          'hello',
          const LuaHookContext(),
        );
        final assistant = await service.onAssistantMessage(
          'ok',
          const LuaHookContext(),
        );
        final rendered = await service.onDisplayRender(
          assistant,
          const LuaHookContext(),
        );

        expect(user, 'hi');
        expect(assistant, 'ok:assistant');
        expect(rendered, '[render]ok:assistant');
        await service.onUnload(const LuaHookContext());
      },
      skip: skipUntilPart1Complete,
    );
  });

  group('Regex pipeline ordering/scope/perf guard', () {
    test('regex rules execute before Lua hooks per lifecycle stage', () async {
      SharedPreferences.setMockInitialValues({});
      final regex = RegexPipelineService.instance;
      final lua = LuaScriptingService.instance;
      await regex.saveRules([
        RegexRule(
          name: 'r1',
          type: RegexRuleType.userInput,
          pattern: 'hi',
          replacement: 'hello',
        ),
      ]);
      await lua.saveScripts([
        LuaScript(
          name: 's1',
          content: '-- hook:onUserMessage replace:hello=>hey',
        ),
      ]);

      final afterRegex = await regex.applyUserInput('hi');
      final afterLua = await lua.onUserMessage(
        afterRegex,
        const LuaHookContext(),
      );

      expect(afterLua, 'hey');
    }, skip: skipUntilPart1Complete);

    test(
      'scope filters enforce GLOBAL/PER_CHARACTER/PER_SESSION isolation',
      () async {
        SharedPreferences.setMockInitialValues({});
        final regex = RegexPipelineService.instance;
        await regex.saveRules([
          RegexRule(
            name: 'global',
            type: RegexRuleType.aiOutput,
            pattern: 'a',
            replacement: 'A',
            scope: RegexRuleScope.global,
          ),
          RegexRule(
            name: 'char',
            type: RegexRuleType.aiOutput,
            pattern: 'b',
            replacement: 'B',
            scope: RegexRuleScope.perCharacter,
            associatedCharacterId: 'c1',
          ),
          RegexRule(
            name: 'session',
            type: RegexRuleType.aiOutput,
            pattern: 'c',
            replacement: 'C',
            scope: RegexRuleScope.perSession,
            associatedSessionId: 's1',
          ),
        ]);

        final hit = await regex.applyAiOutput(
          'abc',
          characterId: 'c1',
          sessionId: 's1',
        );
        final miss = await regex.applyAiOutput(
          'abc',
          characterId: 'c2',
          sessionId: 's2',
        );
        expect(hit, 'ABC');
        expect(miss, 'Abc');
      },
      skip: skipUntilPart1Complete,
    );

    test('performance guard aborts runaway regex patterns', () async {
      SharedPreferences.setMockInitialValues({});
      final regex = RegexPipelineService.instance;
      await regex.saveRules([
        RegexRule(
          name: 'danger',
          type: RegexRuleType.aiOutput,
          pattern: r'(a+)+$',
          replacement: 'X',
        ),
      ]);

      final result = await regex.applyAiOutput('aaaaab');
      expect(result, 'aaaaab');
    }, skip: skipUntilPart1Complete);
  });

  group('Live2D directives parser tolerance/streaming buffer', () {
    test(
      'malformed <live2d> blocks are ignored without breaking output',
      () async {
        final service = Live2DDirectiveService.instance;
        final result = await service.processAssistantOutput(
          'hello <live2d><motion group="Idle" index="0"> world',
        );
        expect(
          result.cleanedText,
          'hello <live2d><motion group="Idle" index="0"> world',
        );
      },
      skip: skipUntilPart1Complete,
    );

    test(
      'streaming buffer preserves directives across chunk boundaries',
      () async {
        final service = Live2DDirectiveService.instance;
        service.resetStreamBuffer();

        final a = await service.pushStreamChunk(
          'A<live2d><expression id="happy"',
        );
        expect(a.cleanedText, contains('<live2d>'));
        final b = await service.pushStreamChunk('/></live2d>B');
        expect(b.cleanedText, 'AB');
      },
      skip: skipUntilPart1Complete,
    );
  });
}

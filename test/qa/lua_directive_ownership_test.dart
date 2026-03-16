import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_application_1/features/lua/models/lua_script.dart';
import 'package:flutter_application_1/features/lua/services/lua_scripting_service.dart';
import 'package:flutter_application_1/features/regex/models/regex_rule.dart';
import 'package:flutter_application_1/features/regex/services/regex_pipeline_service.dart';
import 'package:flutter_application_1/models/settings.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('com.example.flutter_application_1/live2d');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  final methodCalls = <MethodCall>[];

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    methodCalls.clear();

    messenger.setMockMethodCallHandler(channel, (call) async {
      methodCalls.add(call);
      switch (call.method) {
        case 'playMotion':
          return true;
        case 'getDisplayState':
          return {'x': 10.0, 'y': 20.0};
        case 'setPosition':
          return true;
        default:
          return null;
      }
    });
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
  });

  Future<void> expectOwnershipRunsForTarget(
    LuaScriptingService lua,
    String transformed,
    LlmDirectiveTarget target,
  ) async {
    methodCalls.clear();

    final output = await lua.applyAssistantDirectiveOwnership(
      transformed,
      LuaHookContext(
        directiveSyntaxOwnershipEnabled: true,
        live2dLlmIntegrationEnabled: true,
        live2dDirectiveParsingEnabled: true,
        llmDirectiveTarget: target,
      ),
    );

    expect(
      output.replaceAll(RegExp(r'\s+'), ' ').trim(),
      'Hello world',
    );
    expect(
      methodCalls.where((call) => call.method == 'playMotion'),
      hasLength(1),
    );
    expect(
      methodCalls.where((call) => call.method == 'setPosition'),
      hasLength(1),
    );
  }

  test(
    'assistant directive ownership runs live2d and overlay tokens for both targets',
    () async {
      final regex = RegexPipelineService.instance;
      final lua = LuaScriptingService.instance;

      await regex.saveRules([
        RegexRule(
          name: 'Route Live2D inline directives to runtime',
          type: RegexRuleType.aiOutput,
          pattern: r'\[(motion):([^\]]+)\]',
          replacement: r'[pwf-live2d:$1:$2]',
          caseInsensitive: true,
          priority: -20,
        ),
        RegexRule(
          name: 'Route image overlay inline directives to runtime',
          type: RegexRuleType.aiOutput,
          pattern: r'\[(img_move):([^\]]+)\]',
          replacement: r'[pwf-overlay:$1:$2]',
          caseInsensitive: true,
          priority: -10,
        ),
      ]);

      await lua.saveScripts([
        LuaScript(
          name: 'assistant_directive_ownership.lua',
          content: '''-- hook:onAssistantMessage directives:owned
function onAssistantMessage(text)
  return text
end
''',
        ),
      ]);

      final transformed = await regex.applyAiOutput(
        'Hello [motion:name=Idle/0] [img_move:x=15,y=25] world',
      );

      for (final target in LlmDirectiveTarget.values) {
        await expectOwnershipRunsForTarget(lua, transformed, target);
      }
    },
  );

  test(
    'assistant directive ownership still works after lua-first assistant stage',
    () async {
      final regex = RegexPipelineService.instance;
      final lua = LuaScriptingService.instance;

      await regex.saveRules([
        RegexRule(
          name: 'Route Live2D inline directives to runtime',
          type: RegexRuleType.aiOutput,
          pattern: r'\[(motion):([^\]]+)\]',
          replacement: r'[pwf-live2d:$1:$2]',
          caseInsensitive: true,
          priority: -20,
        ),
        RegexRule(
          name: 'Route image overlay inline directives to runtime',
          type: RegexRuleType.aiOutput,
          pattern: r'\[(img_move):([^\]]+)\]',
          replacement: r'[pwf-overlay:$1:$2]',
          caseInsensitive: true,
          priority: -10,
        ),
      ]);

      await lua.saveScripts([
        LuaScript(
          name: 'assistant_directive_ownership.lua',
          content: '''-- hook:onAssistantMessage directives:owned
-- hook:onAssistantMessage append:
function onAssistantMessage(text)
  return text
end
''',
        ),
      ]);

      final luaFirst = await lua.onAssistantMessage(
        'Hello [motion:name=Idle/0] [img_move:x=15,y=25] world',
        const LuaHookContext(),
      );
      final transformed = await regex.applyAiOutput(luaFirst);

      for (final target in LlmDirectiveTarget.values) {
        await expectOwnershipRunsForTarget(lua, transformed, target);
      }
    },
  );
}

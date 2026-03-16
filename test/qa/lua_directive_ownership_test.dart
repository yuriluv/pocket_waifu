import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_application_1/features/lua/models/lua_script.dart';
import 'package:flutter_application_1/features/lua/services/lua_scripting_service.dart';

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

  Future<void> expectAssistantDispatchRuns(
    LuaScriptingService lua,
    String transformed,
  ) async {
    methodCalls.clear();

    final output = await lua.onAssistantMessage(
      transformed,
      const LuaHookContext(
        live2dLlmIntegrationEnabled: true,
        live2dDirectiveParsingEnabled: true,
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
    'assistant lua hook directly executes live2d and overlay commands',
    () async {
      final lua = LuaScriptingService.instance;

      await lua.saveScripts([
        LuaScript(
          name: 'default_runtime_template.lua',
          content: '''
function onAssistantMessage(text)
  text = pwf.dispatch(text, [[<motion\s+([^>]*?)/>]], "live2d.motion", "\$1")
  text = pwf.dispatch(text, [[\[img_move:([^\]]+)\]]], "overlay.move", "\$1")
  return text
end
''',
        ),
      ]);

      await expectAssistantDispatchRuns(
        lua,
        'Hello <motion name="Idle/0"/> [img_move:x=15,y=25] world',
      );
    },
  );

  test(
    'user lua hook can dispatch direct interactions and keep prompt text',
    () async {
      final lua = LuaScriptingService.instance;

      await lua.saveScripts([
        LuaScript(
          name: 'default_runtime_template.lua',
          content: '''
function onUserMessage(text)
  text = pwf.dispatchKeep(text, [[function\(move,\s*([^)]+)\)]], "overlay.move", "\$1")
  return text
end
''',
        ),
      ]);

      final output = await lua.onUserMessage(
        'Hello function(move, x=15,y=25) world',
        const LuaHookContext(
          live2dLlmIntegrationEnabled: true,
          live2dDirectiveParsingEnabled: true,
        ),
      );

      expect(
        output.replaceAll(RegExp(r'\s+'), ' ').trim(),
        'Hello function(move, x=15,y=25) world',
      );
      expect(
        methodCalls.where((call) => call.method == 'setPosition'),
        hasLength(1),
      );
    },
  );
}

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_application_1/features/lua/models/lua_script.dart';
import 'package:flutter_application_1/features/lua/services/lua_native_bridge.dart';
import 'package:flutter_application_1/features/lua/services/lua_scripting_service.dart';

class _NoResultLuaBridge extends LuaNativeBridge {
  @override
  Future<LuaNativeBridgeResult<bool>> executeHook({
    required String script,
    required String hook,
    required String input,
    required int timeoutMs,
  }) async {
    return const LuaNativeBridgeResult<bool>(
      status: LuaNativeBridgeStatus.noResult,
    );
  }

  @override
  Future<LuaNativeBridgeResult<String>> executeHookAndReturn({
    required String script,
    required String hook,
    required String input,
    required int timeoutMs,
  }) async {
    return const LuaNativeBridgeResult<String>(
      status: LuaNativeBridgeStatus.noResult,
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('com.example.flutter_application_1/live2d');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final methodCalls = <MethodCall>[];

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    methodCalls.clear();
    LuaScriptingService.instance.clearLogs();
    LuaScriptingService.instance.resetNativeBridgeForTesting();
    LuaScriptingService.instance.setNativeBridgeForTesting(_NoResultLuaBridge());

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

  test('pwf.gsub skips catastrophic pattern and logs guard reason', () async {
    final lua = LuaScriptingService.instance;
    await lua.saveScripts([
      LuaScript(
        name: 'guard_gsub.lua',
        content: '''
function onAssistantMessage(text)
  return pwf.gsub(text, "(a+)+", "x")
end
''',
      ),
    ]);

    final output = await lua.onAssistantMessage(
      'aaaa',
      const LuaHookContext(characterId: 'pseudo-guard'),
    );

    expect(output, 'aaaa');
    expect(
      lua.logs.any(
        (line) =>
            line.contains('lua.diag reason=pseudo_regex_guard_catastrophic_pattern') &&
            line.contains('"helper":"pwf.gsub"') &&
            line.contains('"hook":"onAssistantMessage"'),
      ),
      isTrue,
    );
  });

  test('pwf.dispatch caps matches/actions and logs reason codes', () async {
    final lua = LuaScriptingService.instance;
    await lua.saveScripts([
      LuaScript(
        name: 'guard_dispatch.lua',
        content: '''
function onAssistantMessage(text)
  return pwf.dispatch(text, [[\[img_move:x=1,y=2\]]], "overlay.move", "x=1,y=2")
end
''',
      ),
    ]);

    final token = '[img_move:x=1,y=2]';
    final input = List<String>.filled(80, token).join(' ');
    final output = await lua.onAssistantMessage(
      input,
      const LuaHookContext(characterId: 'pseudo-guard'),
    );

    expect(methodCalls.where((call) => call.method == 'setPosition'), hasLength(48));
    expect(RegExp(r'\[img_move:x=1,y=2\]').allMatches(output).length, 32);
    expect(
      lua.logs.any(
        (line) =>
            line.contains('lua.diag reason=pseudo_regex_guard_match_cap') &&
            line.contains('"helper":"pwf.dispatch"'),
      ),
      isTrue,
    );
    expect(
      lua.logs.any(
        (line) =>
            line.contains('lua.diag reason=pseudo_runtime_guard_action_cap') &&
            line.contains('"helper":"pwf.dispatch"'),
      ),
      isTrue,
    );
  });

  test('pwf.dispatchKeep skips oversized input and logs reason', () async {
    final lua = LuaScriptingService.instance;
    await lua.saveScripts([
      LuaScript(
        name: 'guard_dispatch_keep_big_input.lua',
        content: '''
function onUserMessage(text)
  return pwf.dispatchKeep(text, [[\[img_move:([^\]]+)\]]], "overlay.move", "\$1")
end
''',
      ),
    ]);

    final oversized = List<String>.filled(25050, 'x').join();
    final input = '[img_move:x=1,y=2] $oversized';
    final output = await lua.onUserMessage(
      input,
      const LuaHookContext(characterId: 'pseudo-guard'),
    );

    expect(output, input);
    expect(methodCalls.where((call) => call.method == 'setPosition'), isEmpty);
    expect(
      lua.logs.any(
        (line) =>
            line.contains('lua.diag reason=pseudo_regex_guard_input_too_large') &&
            line.contains('"helper":"pwf.dispatchKeep"'),
      ),
      isTrue,
    );
  });

  test('pwf.dispatchKeep still works for normal input', () async {
    final lua = LuaScriptingService.instance;
    await lua.saveScripts([
      LuaScript(
        name: 'guard_dispatch_keep_normal.lua',
        content: '''
function onUserMessage(text)
  return pwf.dispatchKeep(text, [[\[img_move:([^\]]+)\]]], "overlay.move", "\$1")
end
''',
      ),
    ]);

    final input = 'hello [img_move:x=15,y=25] world';
    final output = await lua.onUserMessage(
      input,
      const LuaHookContext(characterId: 'pseudo-guard'),
    );

    expect(output, input);
    expect(methodCalls.where((call) => call.method == 'setPosition'), hasLength(1));
  });
}

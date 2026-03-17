import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_application_1/features/lua/models/lua_script.dart';
import 'package:flutter_application_1/features/lua/services/lua_native_bridge.dart';
import 'package:flutter_application_1/features/lua/services/lua_scripting_service.dart';

class _SuccessLuaBridge extends LuaNativeBridge {
  @override
  Future<LuaNativeBridgeResult<String>> executeHookAndReturn({
    required String script,
    required String hook,
    required String input,
    required int timeoutMs,
  }) async {
    return LuaNativeBridgeResult<String>(
      status: LuaNativeBridgeStatus.success,
      value: 'native:$input',
    );
  }
}

class _NoResultLuaBridge extends LuaNativeBridge {
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

class _ExceptionLuaBridge extends LuaNativeBridge {
  @override
  Future<LuaNativeBridgeResult<String>> executeHookAndReturn({
    required String script,
    required String hook,
    required String input,
    required int timeoutMs,
  }) async {
    return LuaNativeBridgeResult<String>(
      status: LuaNativeBridgeStatus.exception,
      error: StateError('native executeHookAndReturn boom'),
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    LuaScriptingService.instance.clearLogs();
    LuaScriptingService.instance.resetNativeBridgeForTesting();
  });

  test('native success keeps execution on native engine', () async {
    final lua = LuaScriptingService.instance;
    lua.setNativeBridgeForTesting(_SuccessLuaBridge());
    await lua.saveScripts([
      LuaScript(
        name: 'native_success.lua',
        content: '''
function onAssistantMessage(text)
  return pwf.replace(text, "foo", "fallback")
end
''',
      ),
    ]);

    final output = await lua.onAssistantMessage(
      'foo',
      const LuaHookContext(characterId: 'native-contract'),
    );

    expect(output, 'native:foo');
    final logs = lua.logs.where((line) => line.contains('hook=onAssistantMessage'));
    expect(
      logs.any(
        (line) =>
            line.contains('stage=native') &&
            line.contains('reason=native_success') &&
            line.contains('script=native_success.lua'),
      ),
      isTrue,
    );
    expect(logs.any((line) => line.contains('stage=fallback')), isFalse);
  });

  test('native null result falls back with explicit no-result cause', () async {
    final lua = LuaScriptingService.instance;
    lua.setNativeBridgeForTesting(_NoResultLuaBridge());
    await lua.saveScripts([
      LuaScript(
        name: 'native_null.lua',
        content: '''
function onAssistantMessage(text)
  return pwf.replace(text, "foo", "fallback-null")
end
''',
      ),
    ]);

    final output = await lua.onAssistantMessage(
      'foo',
      const LuaHookContext(characterId: 'native-contract'),
    );

    expect(output, 'fallback-null');
    final logs = lua.logs.where((line) => line.contains('hook=onAssistantMessage'));
    expect(
      logs.any(
        (line) =>
            line.contains('stage=native') &&
            line.contains('reason=native_no_result') &&
            line.contains('script=native_null.lua'),
      ),
      isTrue,
    );
    expect(
      logs.any(
        (line) =>
            line.contains('stage=fallback') &&
            line.contains('reason=fallback_success') &&
            line.contains('"fallbackCause":"native_no_result"') &&
            line.contains('script=native_null.lua'),
      ),
      isTrue,
    );
  });

  test('native exception falls back with explicit exception cause', () async {
    final lua = LuaScriptingService.instance;
    lua.setNativeBridgeForTesting(_ExceptionLuaBridge());
    await lua.saveScripts([
      LuaScript(
        name: 'native_exception.lua',
        content: '''
function onAssistantMessage(text)
  return pwf.replace(text, "foo", "fallback-exception")
end
''',
      ),
    ]);

    final output = await lua.onAssistantMessage(
      'foo',
      const LuaHookContext(characterId: 'native-contract'),
    );

    expect(output, 'fallback-exception');
    final logs = lua.logs.where((line) => line.contains('hook=onAssistantMessage'));
    expect(
      logs.any(
        (line) =>
            line.contains('stage=native') &&
            line.contains('reason=native_exception') &&
            line.contains('script=native_exception.lua'),
      ),
      isTrue,
    );
    expect(
      logs.any(
        (line) =>
            line.contains('stage=fallback') &&
            line.contains('reason=fallback_success') &&
            line.contains('"fallbackCause":"native_exception"') &&
            line.contains('script=native_exception.lua'),
      ),
      isTrue,
    );
  });
}

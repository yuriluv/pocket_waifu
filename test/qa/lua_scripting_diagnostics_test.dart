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

class _ExceptionLuaBridge extends LuaNativeBridge {
  @override
  Future<LuaNativeBridgeResult<bool>> executeHook({
    required String script,
    required String hook,
    required String input,
    required int timeoutMs,
  }) async {
    return LuaNativeBridgeResult<bool>(
      status: LuaNativeBridgeStatus.exception,
      error: StateError('native bool boom'),
    );
  }

  @override
  Future<LuaNativeBridgeResult<String>> executeHookAndReturn({
    required String script,
    required String hook,
    required String input,
    required int timeoutMs,
  }) async {
    return LuaNativeBridgeResult<String>(
      status: LuaNativeBridgeStatus.exception,
      error: StateError('native string boom'),
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

  test('records normalized diagnostics for native fallback success', () async {
    final lua = LuaScriptingService.instance;
    lua.setNativeBridgeForTesting(_NoResultLuaBridge());
    await lua.saveScripts([
      LuaScript(
        name: 'diag_success.lua',
        content: '''
function onAssistantMessage(text)
  return pwf.replace(text, "foo", "bar")
end
''',
      ),
    ]);

    final output = await lua.onAssistantMessage(
      'foo',
      const LuaHookContext(characterId: 'diagnostics-character'),
    );

    expect(output, 'bar');
    final logs = lua.logs.where((line) => line.contains('hook=onAssistantMessage'));
    expect(
      logs.any(
        (line) =>
            line.contains('stage=native') &&
            line.contains('reason=native_no_result') &&
            line.contains('script=diag_success.lua') &&
            line.contains('context='),
      ),
      isTrue,
    );
    expect(
      logs.any(
        (line) =>
            line.contains('stage=fallback') &&
            line.contains('reason=fallback_success') &&
            line.contains('"fallbackCause":"native_no_result"') &&
            line.contains('context='),
      ),
      isTrue,
    );
  });

  test('records fallback failure diagnostics with stable reason code', () async {
    final lua = LuaScriptingService.instance;
    lua.setNativeBridgeForTesting(_ExceptionLuaBridge());
    await lua.saveScripts([
      LuaScript(
        name: 'diag_failure.lua',
        content: '''
function onAssistantMessage(text)
  return pwf.dispatch(text, "[", "overlay.move", "x=1")
end
''',
      ),
    ]);

    final output = await lua.onAssistantMessage(
      'hello',
      const LuaHookContext(characterId: 'diagnostics-character'),
    );

    expect(output, 'hello');
    final logs = lua.logs.where((line) => line.contains('hook=onAssistantMessage'));
    expect(
      logs.any(
        (line) =>
            line.contains('stage=native') &&
            line.contains('reason=native_exception') &&
            line.contains('script=diag_failure.lua') &&
            line.contains('context='),
      ),
      isTrue,
    );
    expect(
      logs.any(
        (line) =>
            line.contains('stage=fallback') &&
            line.contains('reason=fallback_exception') &&
            line.contains('"fallbackCause":"native_exception"') &&
            line.contains('script=diag_failure.lua') &&
            line.contains('context='),
      ),
      isTrue,
    );
  });

  test('records warning when hook declaration misses terminating body', () async {
    final lua = LuaScriptingService.instance;
    lua.setNativeBridgeForTesting(_NoResultLuaBridge());
    await lua.saveScripts([
      LuaScript(
        name: 'missing_body.lua',
        content: '''
function onAssistantMessage(text)
  return pwf.replace(text, "foo", "bar")
''',
      ),
    ]);

    final output = await lua.onAssistantMessage(
      'foo',
      const LuaHookContext(characterId: 'diagnostics-character'),
    );

    expect(output, 'foo');
    expect(
      lua.logs.any(
        (line) =>
            line.contains('lua.diag reason=pseudo_missing_hook_body') &&
            line.contains('"hook":"onAssistantMessage"') &&
            line.contains('"line":1') &&
            line.contains('"severity":"warning"'),
      ),
      isTrue,
    );
  });

  test('records warning for unsupported method-call expression', () async {
    final lua = LuaScriptingService.instance;
    lua.setNativeBridgeForTesting(_NoResultLuaBridge());
    await lua.saveScripts([
      LuaScript(
        name: 'unsupported_method_expr.lua',
        content: '''
function onAssistantMessage(text)
  return text:match("foo")
end
''',
      ),
    ]);

    final output = await lua.onAssistantMessage(
      'foo',
      const LuaHookContext(characterId: 'diagnostics-character'),
    );

    expect(output, 'foo');
    expect(
      lua.logs.any(
        (line) =>
            line.contains(
              'lua.diag reason=pseudo_unsupported_expression_method_call',
            ) &&
            line.contains('"line":2') &&
            line.contains('"hook":"onAssistantMessage"') &&
            line.contains('"severity":"warning"'),
      ),
      isTrue,
    );
  });

  test('records warnings for unsupported control flow and concat expression', () async {
    final lua = LuaScriptingService.instance;
    lua.setNativeBridgeForTesting(_NoResultLuaBridge());
    await lua.saveScripts([
      LuaScript(
        name: 'unsupported_flow_concat.lua',
        content: '''
function onAssistantMessage(text)
  if text == "foo" then
    return text .. "!"
  end
  return text
end
''',
      ),
    ]);

    final output = await lua.onAssistantMessage(
      'foo',
      const LuaHookContext(characterId: 'diagnostics-character'),
    );

    expect(output, 'foo');
    expect(
      lua.logs.any(
        (line) =>
            line.contains('lua.diag reason=pseudo_unsupported_statement_if_then') &&
            line.contains('"line":2'),
      ),
      isTrue,
    );
    expect(
      lua.logs.any(
        (line) =>
            line.contains('lua.diag reason=pseudo_unsupported_expression_concat') &&
            line.contains('"line":3'),
      ),
      isTrue,
    );
  });

  test('records warning for risky multiline helper shapes', () async {
    final lua = LuaScriptingService.instance;
    lua.setNativeBridgeForTesting(_NoResultLuaBridge());
    await lua.saveScripts([
      LuaScript(
        name: 'multiline_helper.lua',
        content: '''
function onAssistantMessage(text)
  text = pwf.dispatch(
    text,
    [[x]],
    "overlay.move",
    "x=1"
  )
  return text
end
''',
      ),
    ]);

    final output = await lua.onAssistantMessage(
      'hello',
      const LuaHookContext(characterId: 'diagnostics-character'),
    );

    expect(output, 'hello');
    expect(
      lua.logs.any(
        (line) =>
            line.contains('lua.diag reason=pseudo_risky_multiline_helper') &&
            line.contains('"line":2') &&
            line.contains('"hook":"onAssistantMessage"'),
      ),
      isTrue,
    );
  });
}

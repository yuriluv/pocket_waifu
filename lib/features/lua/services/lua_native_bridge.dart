import 'package:flutter/services.dart';

class LuaNativeBridge {
  static const MethodChannel _channel = MethodChannel('pocketwaifu/lua');

  Future<bool> executeHook({
    required String script,
    required String hook,
    required String input,
    required int timeoutMs,
  }) async {
    try {
      final result = await _channel.invokeMethod<bool>('executeHook', {
        'script': script,
        'hook': hook,
        'input': input,
        'timeoutMs': timeoutMs,
      });
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<String?> executeHookAndReturn({
    required String script,
    required String hook,
    required String input,
    required int timeoutMs,
  }) async {
    try {
      final result = await _channel.invokeMethod<String>(
        'executeHookAndReturn',
        {
          'script': script,
          'hook': hook,
          'input': input,
          'timeoutMs': timeoutMs,
        },
      );
      return result;
    } catch (_) {
      return null;
    }
  }
}

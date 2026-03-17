import 'package:flutter/services.dart';

enum LuaNativeBridgeStatus { success, noResult, unavailable, exception }

class LuaNativeBridgeResult<T> {
  const LuaNativeBridgeResult({
    required this.status,
    this.value,
    this.error,
  });

  final LuaNativeBridgeStatus status;
  final T? value;
  final Object? error;

  bool get isSuccess => status == LuaNativeBridgeStatus.success;

  bool get isAvailable => status != LuaNativeBridgeStatus.unavailable;

  String get causeLabel => switch (status) {
    LuaNativeBridgeStatus.success => 'native_success',
    LuaNativeBridgeStatus.noResult => 'native_no_result',
    LuaNativeBridgeStatus.unavailable => 'native_unavailable',
    LuaNativeBridgeStatus.exception => 'native_exception',
  };
}

class LuaNativeBridge {
  static const MethodChannel _channel = MethodChannel('pocketwaifu/lua');

  Future<LuaNativeBridgeResult<bool>> executeHook({
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
      if (result == true) {
        return const LuaNativeBridgeResult<bool>(
          status: LuaNativeBridgeStatus.success,
          value: true,
        );
      }
      return const LuaNativeBridgeResult<bool>(
        status: LuaNativeBridgeStatus.noResult,
      );
    } on MissingPluginException catch (error) {
      return LuaNativeBridgeResult<bool>(
        status: LuaNativeBridgeStatus.unavailable,
        error: error,
      );
    } catch (error) {
      return LuaNativeBridgeResult<bool>(
        status: LuaNativeBridgeStatus.exception,
        error: error,
      );
    }
  }

  Future<LuaNativeBridgeResult<String>> executeHookAndReturn({
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
      if (result != null) {
        return LuaNativeBridgeResult<String>(
          status: LuaNativeBridgeStatus.success,
          value: result,
        );
      }
      return const LuaNativeBridgeResult<String>(
        status: LuaNativeBridgeStatus.noResult,
      );
    } on MissingPluginException catch (error) {
      return LuaNativeBridgeResult<String>(
        status: LuaNativeBridgeStatus.unavailable,
        error: error,
      );
    } catch (error) {
      return LuaNativeBridgeResult<String>(
        status: LuaNativeBridgeStatus.exception,
        error: error,
      );
    }
  }
}

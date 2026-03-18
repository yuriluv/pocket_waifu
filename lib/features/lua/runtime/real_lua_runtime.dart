enum RealLuaResultStatus {
  success,
  noResult,
  unavailable,
  notInitialized,
  error,
}

enum RealLuaHook {
  onLoad,
  onUnload,
  onUserMessage,
  onAssistantMessage,
  onPromptBuild,
  onDisplayRender,
}

extension RealLuaHookWireName on RealLuaHook {
  String get wireName {
    return switch (this) {
      RealLuaHook.onLoad => 'onLoad',
      RealLuaHook.onUnload => 'onUnload',
      RealLuaHook.onUserMessage => 'onUserMessage',
      RealLuaHook.onAssistantMessage => 'onAssistantMessage',
      RealLuaHook.onPromptBuild => 'onPromptBuild',
      RealLuaHook.onDisplayRender => 'onDisplayRender',
    };
  }
}

class RealLuaHookInvocation {
  const RealLuaHookInvocation({
    required this.script,
    required this.hook,
    required this.input,
    required this.timeout,
  });

  final String script;
  final RealLuaHook hook;
  final String input;
  final Duration timeout;
}

class RealLuaResult<T> {
  const RealLuaResult({
    required this.status,
    this.value,
    this.error,
    this.stackTrace,
    this.metadata = const <String, Object?>{},
  });

  final RealLuaResultStatus status;
  final T? value;
  final Object? error;
  final StackTrace? stackTrace;
  final Map<String, Object?> metadata;

  bool get isSuccess => status == RealLuaResultStatus.success;
}

abstract class RealLuaRuntime {
  String get engineId;
  bool get isInitialized;

  Future<RealLuaResult<void>> initialize();

  Future<RealLuaResult<void>> dispose();

  Future<RealLuaResult<void>> executeHook(RealLuaHookInvocation invocation);

  Future<RealLuaResult<String>> executeHookAndReturn(
    RealLuaHookInvocation invocation,
  );
}

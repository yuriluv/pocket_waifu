import 'dart:ffi';
import 'dart:convert';

import 'package:ffi/ffi.dart';
import 'package:flutter_embed_lua/lua_bindings.dart';
import 'package:flutter_embed_lua/lua_runtime.dart';

import 'directive_lua_host_api.dart';
import 'lua_host_api.dart';
import 'real_lua_runtime.dart';

typedef _LuaHostCallback = Int32 Function(Pointer<lua_State> state);

class _HostFlushOutcome {
  const _HostFlushOutcome({
    required this.isSuccess,
    this.metadata = const <String, Object?>{},
    this.error,
  });

  final bool isSuccess;
  final Map<String, Object?> metadata;
  final Object? error;
}

class FlutterEmbedLuaRuntime implements RealLuaRuntime {
  FlutterEmbedLuaRuntime({LuaHostApi? hostApi})
    : _hostApi = hostApi ?? DirectiveLuaHostApi();

  static final Map<int, FlutterEmbedLuaRuntime> _runtimeByStateAddress =
      <int, FlutterEmbedLuaRuntime>{};
  static final Pointer<NativeFunction<_LuaHostCallback>>
  _overlayMoveCallbackPtr = Pointer.fromFunction<_LuaHostCallback>(
    _luaOverlayMoveCallback,
    0,
  );
  static final Pointer<NativeFunction<_LuaHostCallback>>
  _overlayEmotionCallbackPtr = Pointer.fromFunction<_LuaHostCallback>(
    _luaOverlayEmotionCallback,
    0,
  );
  static final Pointer<NativeFunction<_LuaHostCallback>>
  _overlayWaitCallbackPtr = Pointer.fromFunction<_LuaHostCallback>(
    _luaOverlayWaitCallback,
    0,
  );
  static final Pointer<NativeFunction<_LuaHostCallback>>
  _live2dParamCallbackPtr = Pointer.fromFunction<_LuaHostCallback>(
    _luaLive2DParamCallback,
    0,
  );
  static final Pointer<NativeFunction<_LuaHostCallback>>
  _live2dMotionCallbackPtr = Pointer.fromFunction<_LuaHostCallback>(
    _luaLive2DMotionCallback,
    0,
  );
  static final Pointer<NativeFunction<_LuaHostCallback>>
  _live2dExpressionCallbackPtr = Pointer.fromFunction<_LuaHostCallback>(
    _luaLive2DExpressionCallback,
    0,
  );
  static final Pointer<NativeFunction<_LuaHostCallback>>
  _live2dEmotionCallbackPtr = Pointer.fromFunction<_LuaHostCallback>(
    _luaLive2DEmotionCallback,
    0,
  );
  static final Pointer<NativeFunction<_LuaHostCallback>>
  _live2dWaitCallbackPtr = Pointer.fromFunction<_LuaHostCallback>(
    _luaLive2DWaitCallback,
    0,
  );
  static final Pointer<NativeFunction<_LuaHostCallback>>
  _live2dPresetCallbackPtr = Pointer.fromFunction<_LuaHostCallback>(
    _luaLive2DPresetCallback,
    0,
  );
  static final Pointer<NativeFunction<_LuaHostCallback>>
  _live2dResetCallbackPtr = Pointer.fromFunction<_LuaHostCallback>(
    _luaLive2DResetCallback,
    0,
  );

  static const String _luaHostPrelude = '''
overlay = overlay or {}
live2d = live2d or {}

function overlay.move(x, y, op, durationMs)
  if type(x) == "table" then
    local args = x
    return __pwf_overlay_move(args.x, args.y, args.op, args.durationMs or args.duration or args.dur)
  end
  return __pwf_overlay_move(x, y, op, durationMs)
end

function overlay.emotion(emotion)
  if type(emotion) == "table" then
    local args = emotion
    return __pwf_overlay_emotion(args.emotion or args.name)
  end
  return __pwf_overlay_emotion(emotion)
end

function overlay.wait(durationMs)
  if type(durationMs) == "table" then
    local args = durationMs
    return __pwf_overlay_wait(args.durationMs or args.duration or args.ms)
  end
  return __pwf_overlay_wait(durationMs)
end

function live2d.param(parameterId, value, op, durationMs)
  if type(parameterId) == "table" then
    local args = parameterId
    return __pwf_live2d_param(args.id or args.parameterId, args.value, args.op, args.durationMs or args.duration or args.dur)
  end
  return __pwf_live2d_param(parameterId, value, op, durationMs)
end

function live2d.motion(group, index, name, priority)
  if type(group) == "table" then
    local args = group
    return __pwf_live2d_motion(args.group, args.index, args.name, args.priority)
  end
  return __pwf_live2d_motion(group, index, name, priority)
end

function live2d.expression(expression)
  if type(expression) == "table" then
    local args = expression
    return __pwf_live2d_expression(args.expression or args.id or args.name)
  end
  return __pwf_live2d_expression(expression)
end

function live2d.emotion(emotion)
  if type(emotion) == "table" then
    local args = emotion
    return __pwf_live2d_emotion(args.emotion or args.name)
  end
  return __pwf_live2d_emotion(emotion)
end

function live2d.wait(durationMs)
  if type(durationMs) == "table" then
    local args = durationMs
    return __pwf_live2d_wait(args.durationMs or args.duration or args.ms)
  end
  return __pwf_live2d_wait(durationMs)
end

function live2d.preset(presetName, durationMs)
  if type(presetName) == "table" then
    local args = presetName
    return __pwf_live2d_preset(args.presetName or args.name, args.durationMs or args.duration or args.dur)
  end
  return __pwf_live2d_preset(presetName, durationMs)
end

function live2d.reset(durationMs)
  if type(durationMs) == "table" then
    local args = durationMs
    return __pwf_live2d_reset(args.durationMs or args.duration or args.dur)
  end
  return __pwf_live2d_reset(durationMs)
end
''';

  LuaRuntime? _runtime;
  bool _isInitialized = false;
  bool _hostFunctionsRegistered = false;
  RealLuaHookInvocation? _activeInvocation;
  final List<LuaHostAction> _pendingHostActions = <LuaHostAction>[];
  final List<String> _pendingBindingErrors = <String>[];
  final LuaHostApi _hostApi;

  @override
  String get engineId => 'flutter_embed_lua';

  @override
  bool get isInitialized => _isInitialized;

  @override
  Future<RealLuaResult<void>> initialize() async {
    if (_isInitialized && _runtime != null) {
      return const RealLuaResult<void>(status: RealLuaResultStatus.success);
    }
    try {
      _runtime ??= LuaRuntime();
      _runtimeByStateAddress[_runtime!.L.address] = this;
      _registerHostFunctions(_runtime!);
      _isInitialized = true;
      return const RealLuaResult<void>(status: RealLuaResultStatus.success);
    } catch (error, stackTrace) {
      final runtime = _runtime;
      if (runtime != null) {
        _runtimeByStateAddress.remove(runtime.L.address);
      }
      _runtime = null;
      _isInitialized = false;
      _hostFunctionsRegistered = false;
      return RealLuaResult<void>(
        status: RealLuaResultStatus.error,
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  @override
  Future<RealLuaResult<void>> dispose() async {
    final runtime = _runtime;
    if (runtime == null) {
      _isInitialized = false;
      _hostFunctionsRegistered = false;
      return const RealLuaResult<void>(status: RealLuaResultStatus.success);
    }
    try {
      _runtimeByStateAddress.remove(runtime.L.address);
      runtime.dispose();
      _runtime = null;
      _isInitialized = false;
      _hostFunctionsRegistered = false;
      _activeInvocation = null;
      _pendingHostActions.clear();
      _pendingBindingErrors.clear();
      return const RealLuaResult<void>(status: RealLuaResultStatus.success);
    } catch (error, stackTrace) {
      return RealLuaResult<void>(
        status: RealLuaResultStatus.error,
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  @override
  Future<RealLuaResult<void>> executeHook(RealLuaHookInvocation invocation) async {
    final runtime = _runtime;
    if (!_isInitialized || runtime == null) {
      return const RealLuaResult<void>(
        status: RealLuaResultStatus.notInitialized,
      );
    }

    try {
      _beginInvocation(invocation);
      runtime.run(_luaHostPrelude);
      runtime.run(invocation.script);
      runtime.run(_buildHookInvocationExpression(invocation));
      final hostFlush = await _flushPendingHostActions();
      if (!hostFlush.isSuccess) {
        return RealLuaResult<void>(
          status: RealLuaResultStatus.error,
          error: hostFlush.error,
          metadata: <String, Object?>{
            ...hostFlush.metadata,
            'timeoutMs': invocation.timeout.inMilliseconds,
            'timeoutEnforced': false,
          },
        );
      }
      return RealLuaResult<void>(
        status: RealLuaResultStatus.success,
        metadata: <String, Object?>{
          ...hostFlush.metadata,
          'timeoutMs': invocation.timeout.inMilliseconds,
          'timeoutEnforced': false,
        },
      );
    } catch (error, stackTrace) {
      return RealLuaResult<void>(
        status: RealLuaResultStatus.error,
        error: error,
        stackTrace: stackTrace,
      );
    } finally {
      _endInvocation();
    }
  }

  @override
  Future<RealLuaResult<String>> executeHookAndReturn(
    RealLuaHookInvocation invocation,
  ) async {
    final runtime = _runtime;
    if (!_isInitialized || runtime == null) {
      return const RealLuaResult<String>(
        status: RealLuaResultStatus.notInitialized,
      );
    }

    try {
      _beginInvocation(invocation);
      runtime.run(_luaHostPrelude);
      runtime.run(invocation.script);
      final rawResult = runtime.run(_buildHookInvocationExpression(invocation));
      final hostFlush = await _flushPendingHostActions();
      if (!hostFlush.isSuccess) {
        return RealLuaResult<String>(
          status: RealLuaResultStatus.error,
          error: hostFlush.error,
          metadata: <String, Object?>{
            ...hostFlush.metadata,
            'timeoutMs': invocation.timeout.inMilliseconds,
            'timeoutEnforced': false,
          },
        );
      }
      final result = rawResult?.toString();
      if (result == null || result.isEmpty) {
        return RealLuaResult<String>(
          status: RealLuaResultStatus.noResult,
          metadata: <String, Object?>{
            ...hostFlush.metadata,
            'timeoutMs': invocation.timeout.inMilliseconds,
            'timeoutEnforced': false,
          },
        );
      }
      return RealLuaResult<String>(
        status: RealLuaResultStatus.success,
        value: result,
        metadata: <String, Object?>{
          ...hostFlush.metadata,
          'timeoutMs': invocation.timeout.inMilliseconds,
          'timeoutEnforced': false,
        },
      );
    } catch (error, stackTrace) {
      return RealLuaResult<String>(
        status: RealLuaResultStatus.error,
        error: error,
        stackTrace: stackTrace,
      );
    } finally {
      _endInvocation();
    }
  }

  void _registerHostFunctions(LuaRuntime runtime) {
    if (_hostFunctionsRegistered) {
      return;
    }
    runtime.registerFunction('__pwf_overlay_move', _overlayMoveCallbackPtr);
    runtime.registerFunction(
      '__pwf_overlay_emotion',
      _overlayEmotionCallbackPtr,
    );
    runtime.registerFunction('__pwf_overlay_wait', _overlayWaitCallbackPtr);
    runtime.registerFunction('__pwf_live2d_param', _live2dParamCallbackPtr);
    runtime.registerFunction('__pwf_live2d_motion', _live2dMotionCallbackPtr);
    runtime.registerFunction(
      '__pwf_live2d_expression',
      _live2dExpressionCallbackPtr,
    );
    runtime.registerFunction('__pwf_live2d_emotion', _live2dEmotionCallbackPtr);
    runtime.registerFunction('__pwf_live2d_wait', _live2dWaitCallbackPtr);
    runtime.registerFunction('__pwf_live2d_preset', _live2dPresetCallbackPtr);
    runtime.registerFunction('__pwf_live2d_reset', _live2dResetCallbackPtr);
    _hostFunctionsRegistered = true;
  }

  void _beginInvocation(RealLuaHookInvocation invocation) {
    _activeInvocation = invocation;
    _pendingHostActions.clear();
    _pendingBindingErrors.clear();
  }

  void _endInvocation() {
    _activeInvocation = null;
    _pendingHostActions.clear();
    _pendingBindingErrors.clear();
  }

  Future<_HostFlushOutcome> _flushPendingHostActions() async {
    if (_pendingBindingErrors.isNotEmpty) {
      final firstError = _pendingBindingErrors.first;
      return _HostFlushOutcome(
        isSuccess: false,
        error: StateError(firstError),
        metadata: <String, Object?>{
          'hostActionCount': _pendingHostActions.length,
          'hostBindingErrorCount': _pendingBindingErrors.length,
          'hostBindingError': firstError,
        },
      );
    }

    if (_pendingHostActions.isEmpty) {
      return const _HostFlushOutcome(
        isSuccess: true,
        metadata: <String, Object?>{
          'hostActionCount': 0,
          'hostFailureCount': 0,
        },
      );
    }

    final batchResult = await _hostApi.invokeAll(
      _pendingHostActions,
      stopOnFailure: false,
    );
    var failureCount = 0;
    LuaHostActionResult? firstFailure;
    for (final entry in batchResult.results) {
      if (!entry.result.isSuccess) {
        failureCount++;
        firstFailure ??= entry;
      }
    }
    final metadata = <String, Object?>{
      'hostActionCount': batchResult.results.length,
      'hostFailureCount': failureCount,
      ...batchResult.metadata,
    };
    if (firstFailure == null) {
      return _HostFlushOutcome(isSuccess: true, metadata: metadata);
    }

    final result = firstFailure.result;
    return _HostFlushOutcome(
      isSuccess: false,
      error: StateError(
        result.message ??
            'Host action failed: ${firstFailure.action.actionName} (${result.status.name})',
      ),
      metadata: <String, Object?>{
        ...metadata,
        'hostFailureAction': firstFailure.action.actionName,
        'hostFailureStatus': result.status.name,
        if (result.errorCode != null) 'hostFailureCode': result.errorCode,
      },
    );
  }

  LuaHostActionContext _buildActionContext(String actionName) {
    final active = _activeInvocation;
    return LuaHostActionContext(
      hookName: active?.hook.wireName,
      metadata: <String, Object?>{
        'engineId': engineId,
        'actionName': actionName,
      },
    );
  }

  void _recordBindingError(String message) {
    _pendingBindingErrors.add(message);
  }

  void _queueAction(LuaHostAction action) {
    _pendingHostActions.add(action);
  }

  void _enqueueOverlayMove(Pointer<lua_State> state) {
    final x = _readNumberArg(state, 1) ?? 0;
    final y = _readNumberArg(state, 2) ?? 0;
    final action = LuaOverlayMoveAction(
      context: _buildActionContext('overlay.move'),
      x: x,
      y: y,
      operation: _parseNumericOperation(_readStringArg(state, 3)),
      duration: _durationFromMillis(_readNumberArg(state, 4)),
    );
    _queueAction(action);
  }

  void _enqueueOverlayEmotion(Pointer<lua_State> state) {
    final emotion = _readStringArg(state, 1)?.trim();
    if (emotion == null || emotion.isEmpty) {
      _recordBindingError('overlay.emotion requires a non-empty emotion name');
      return;
    }
    _queueAction(
      LuaOverlayEmotionAction(
        context: _buildActionContext('overlay.emotion'),
        emotion: emotion,
      ),
    );
  }

  void _enqueueOverlayWait(Pointer<lua_State> state) {
    final duration = _durationFromMillis(_readNumberArg(state, 1));
    if (duration == null) {
      _recordBindingError('overlay.wait requires duration milliseconds');
      return;
    }
    _queueAction(
      LuaOverlayWaitAction(
        context: _buildActionContext('overlay.wait'),
        duration: duration,
      ),
    );
  }

  void _enqueueLive2DParam(Pointer<lua_State> state) {
    final parameterId = _readStringArg(state, 1)?.trim();
    final value = _readNumberArg(state, 2);
    if (parameterId == null || parameterId.isEmpty || value == null) {
      _recordBindingError('live2d.param requires parameter id and numeric value');
      return;
    }
    _queueAction(
      LuaLive2DParamAction(
        context: _buildActionContext('live2d.param'),
        parameterId: parameterId,
        value: value,
        operation: _parseNumericOperation(_readStringArg(state, 3)),
        duration: _durationFromMillis(_readNumberArg(state, 4)),
      ),
    );
  }

  void _enqueueLive2DMotion(Pointer<lua_State> state) {
    final group = _readStringArg(state, 1)?.trim();
    final index = _readIntArg(state, 2);
    final name = _readStringArg(state, 3)?.trim();
    final priority = _readIntArg(state, 4);
    _queueAction(
      LuaLive2DMotionAction(
        context: _buildActionContext('live2d.motion'),
        group: (group == null || group.isEmpty) ? null : group,
        index: index,
        name: (name == null || name.isEmpty) ? null : name,
        priority: priority,
      ),
    );
  }

  void _enqueueLive2DExpression(Pointer<lua_State> state) {
    final expression = _readStringArg(state, 1)?.trim();
    if (expression == null || expression.isEmpty) {
      _recordBindingError(
        'live2d.expression requires a non-empty expression identifier',
      );
      return;
    }
    _queueAction(
      LuaLive2DExpressionAction(
        context: _buildActionContext('live2d.expression'),
        expression: expression,
      ),
    );
  }

  void _enqueueLive2DEmotion(Pointer<lua_State> state) {
    final emotion = _readStringArg(state, 1)?.trim();
    if (emotion == null || emotion.isEmpty) {
      _recordBindingError('live2d.emotion requires a non-empty emotion name');
      return;
    }
    _queueAction(
      LuaLive2DEmotionAction(
        context: _buildActionContext('live2d.emotion'),
        emotion: emotion,
      ),
    );
  }

  void _enqueueLive2DWait(Pointer<lua_State> state) {
    final duration = _durationFromMillis(_readNumberArg(state, 1));
    if (duration == null) {
      _recordBindingError('live2d.wait requires duration milliseconds');
      return;
    }
    _queueAction(
      LuaLive2DWaitAction(
        context: _buildActionContext('live2d.wait'),
        duration: duration,
      ),
    );
  }

  void _enqueueLive2DPreset(Pointer<lua_State> state) {
    final presetName = _readStringArg(state, 1)?.trim();
    if (presetName == null || presetName.isEmpty) {
      _recordBindingError('live2d.preset requires a non-empty preset name');
      return;
    }
    _queueAction(
      LuaLive2DPresetAction(
        context: _buildActionContext('live2d.preset'),
        presetName: presetName,
        duration: _durationFromMillis(_readNumberArg(state, 2)),
      ),
    );
  }

  void _enqueueLive2DReset(Pointer<lua_State> state) {
    _queueAction(
      LuaLive2DResetAction(
        context: _buildActionContext('live2d.reset'),
        duration: _durationFromMillis(_readNumberArg(state, 1)),
      ),
    );
  }

  int _argCount(Pointer<lua_State> state) {
    return LuaRuntime.lua.lua_gettop(state);
  }

  String? _readStringArg(Pointer<lua_State> state, int index) {
    if (index > _argCount(state)) {
      return null;
    }
    final lua = LuaRuntime.lua;
    if (lua.lua_isstring(state, index) == 0) {
      return null;
    }
    final raw = lua.lua_tolstring(state, index, nullptr);
    if (raw == nullptr) {
      return null;
    }
    return raw.cast<Utf8>().toDartString();
  }

  double? _readNumberArg(Pointer<lua_State> state, int index) {
    if (index > _argCount(state)) {
      return null;
    }
    final lua = LuaRuntime.lua;
    if (lua.lua_isnumber(state, index) == 0) {
      return null;
    }
    return lua.lua_tonumberx(state, index, nullptr);
  }

  int? _readIntArg(Pointer<lua_State> state, int index) {
    if (index > _argCount(state)) {
      return null;
    }
    final lua = LuaRuntime.lua;
    if (lua.lua_isinteger(state, index) != 0) {
      return lua.lua_tointegerx(state, index, nullptr);
    }
    final numeric = _readNumberArg(state, index);
    return numeric?.round();
  }

  Duration? _durationFromMillis(double? milliseconds) {
    if (milliseconds == null || !milliseconds.isFinite) {
      return null;
    }
    final value = milliseconds.round();
    return Duration(milliseconds: value < 0 ? 0 : value);
  }

  LuaHostNumericOperation _parseNumericOperation(String? raw) {
    final normalized = raw?.trim().toLowerCase();
    return switch (normalized) {
      'del' || 'delta' || 'add' => LuaHostNumericOperation.del,
      'mul' || 'multiply' => LuaHostNumericOperation.multiply,
      _ => LuaHostNumericOperation.set,
    };
  }

  static FlutterEmbedLuaRuntime? _forState(Pointer<lua_State> state) {
    return _runtimeByStateAddress[state.address];
  }

  static int _luaOverlayMoveCallback(Pointer<lua_State> state) {
    _forState(state)?._enqueueOverlayMove(state);
    return 0;
  }

  static int _luaOverlayEmotionCallback(Pointer<lua_State> state) {
    _forState(state)?._enqueueOverlayEmotion(state);
    return 0;
  }

  static int _luaOverlayWaitCallback(Pointer<lua_State> state) {
    _forState(state)?._enqueueOverlayWait(state);
    return 0;
  }

  static int _luaLive2DParamCallback(Pointer<lua_State> state) {
    _forState(state)?._enqueueLive2DParam(state);
    return 0;
  }

  static int _luaLive2DMotionCallback(Pointer<lua_State> state) {
    _forState(state)?._enqueueLive2DMotion(state);
    return 0;
  }

  static int _luaLive2DExpressionCallback(Pointer<lua_State> state) {
    _forState(state)?._enqueueLive2DExpression(state);
    return 0;
  }

  static int _luaLive2DEmotionCallback(Pointer<lua_State> state) {
    _forState(state)?._enqueueLive2DEmotion(state);
    return 0;
  }

  static int _luaLive2DWaitCallback(Pointer<lua_State> state) {
    _forState(state)?._enqueueLive2DWait(state);
    return 0;
  }

  static int _luaLive2DPresetCallback(Pointer<lua_State> state) {
    _forState(state)?._enqueueLive2DPreset(state);
    return 0;
  }

  static int _luaLive2DResetCallback(Pointer<lua_State> state) {
    _forState(state)?._enqueueLive2DReset(state);
    return 0;
  }

  String _buildHookInvocationExpression(RealLuaHookInvocation invocation) {
    final encodedInput = jsonEncode(invocation.input);
    return '${invocation.hook.wireName}($encodedInput)';
  }
}

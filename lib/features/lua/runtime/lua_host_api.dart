enum LuaHostDomain {
  overlay,
  live2d,
  screenshot,
  api,
  session,
  interaction,
  assets,
  ui,
  events,
  subagent,
  custom,
}

enum LuaHostCallStatus {
  success,
  ignored,
  invalidAction,
  unsupportedAction,
  unavailable,
  timeout,
  failed,
}

enum LuaHostNumericOperation { set, del, multiply }

enum LuaHostScreenshotMode { includeOverlays, excludeOverlays }

enum LuaHostApiMethod { get, post, put, patch, delete, head, options }

class LuaHostActionContext {
  const LuaHostActionContext({
    this.scriptId,
    this.scriptName,
    this.hookName,
    this.sessionId,
    this.interactionId,
    this.correlationId,
    this.metadata = const <String, Object?>{},
  });

  final String? scriptId;
  final String? scriptName;
  final String? hookName;
  final String? sessionId;
  final String? interactionId;
  final String? correlationId;
  final Map<String, Object?> metadata;
}

abstract class LuaHostAction {
  const LuaHostAction({required this.context});

  final LuaHostActionContext context;

  LuaHostDomain get domain;
  String get actionName;
}

abstract class LuaOverlayAction extends LuaHostAction {
  const LuaOverlayAction({required super.context});

  @override
  LuaHostDomain get domain => LuaHostDomain.overlay;
}

class LuaOverlayMoveAction extends LuaOverlayAction {
  const LuaOverlayMoveAction({
    required super.context,
    required this.x,
    required this.y,
    this.operation = LuaHostNumericOperation.set,
    this.duration,
  });

  final double x;
  final double y;
  final LuaHostNumericOperation operation;
  final Duration? duration;

  @override
  String get actionName => 'overlay.move';
}

class LuaOverlayEmotionAction extends LuaOverlayAction {
  const LuaOverlayEmotionAction({
    required super.context,
    required this.emotion,
  });

  final String emotion;

  @override
  String get actionName => 'overlay.emotion';
}

class LuaOverlayWaitAction extends LuaOverlayAction {
  const LuaOverlayWaitAction({
    required super.context,
    required this.duration,
  });

  final Duration duration;

  @override
  String get actionName => 'overlay.wait';
}

abstract class LuaLive2DAction extends LuaHostAction {
  const LuaLive2DAction({required super.context});

  @override
  LuaHostDomain get domain => LuaHostDomain.live2d;
}

class LuaLive2DParamAction extends LuaLive2DAction {
  const LuaLive2DParamAction({
    required super.context,
    required this.parameterId,
    required this.value,
    this.operation = LuaHostNumericOperation.set,
    this.duration,
  });

  final String parameterId;
  final double value;
  final LuaHostNumericOperation operation;
  final Duration? duration;

  @override
  String get actionName => 'live2d.param';
}

class LuaLive2DMotionAction extends LuaLive2DAction {
  const LuaLive2DMotionAction({
    required super.context,
    this.group,
    this.index,
    this.name,
    this.priority,
  });

  final String? group;
  final int? index;
  final String? name;
  final int? priority;

  @override
  String get actionName => 'live2d.motion';
}

class LuaLive2DExpressionAction extends LuaLive2DAction {
  const LuaLive2DExpressionAction({
    required super.context,
    required this.expression,
  });

  final String expression;

  @override
  String get actionName => 'live2d.expression';
}

class LuaLive2DEmotionAction extends LuaLive2DAction {
  const LuaLive2DEmotionAction({
    required super.context,
    required this.emotion,
  });

  final String emotion;

  @override
  String get actionName => 'live2d.emotion';
}

class LuaLive2DWaitAction extends LuaLive2DAction {
  const LuaLive2DWaitAction({
    required super.context,
    required this.duration,
  });

  final Duration duration;

  @override
  String get actionName => 'live2d.wait';
}

class LuaLive2DPresetAction extends LuaLive2DAction {
  const LuaLive2DPresetAction({
    required super.context,
    required this.presetName,
    this.duration,
  });

  final String presetName;
  final Duration? duration;

  @override
  String get actionName => 'live2d.preset';
}

class LuaLive2DResetAction extends LuaLive2DAction {
  const LuaLive2DResetAction({required super.context, this.duration});

  final Duration? duration;

  @override
  String get actionName => 'live2d.reset';
}

abstract class LuaScreenshotAction extends LuaHostAction {
  const LuaScreenshotAction({required super.context});

  @override
  LuaHostDomain get domain => LuaHostDomain.screenshot;
}

class LuaScreenshotCaptureAction extends LuaScreenshotAction {
  const LuaScreenshotCaptureAction({
    required super.context,
    this.mode = LuaHostScreenshotMode.excludeOverlays,
    this.maxWidth,
    this.maxHeight,
    this.quality,
  });

  final LuaHostScreenshotMode mode;
  final int? maxWidth;
  final int? maxHeight;
  final int? quality;

  @override
  String get actionName => 'screenshot.capture';
}

class LuaCapturedImage {
  const LuaCapturedImage({
    required this.base64,
    required this.mimeType,
    required this.width,
    required this.height,
  });

  final String base64;
  final String mimeType;
  final int width;
  final int height;
}

abstract class LuaApiAction extends LuaHostAction {
  const LuaApiAction({required super.context});

  @override
  LuaHostDomain get domain => LuaHostDomain.api;
}

class LuaApiRequestAction extends LuaApiAction {
  const LuaApiRequestAction({
    required super.context,
    required this.method,
    required this.url,
    this.headers = const <String, String>{},
    this.body,
    this.timeout,
  });

  final LuaHostApiMethod method;
  final String url;
  final Map<String, String> headers;
  final String? body;
  final Duration? timeout;

  @override
  String get actionName => 'api.request';
}

class LuaApiResponse {
  const LuaApiResponse({
    required this.statusCode,
    required this.headers,
    this.body,
  });

  final int statusCode;
  final Map<String, String> headers;
  final String? body;
}

abstract class LuaSessionAction extends LuaHostAction {
  const LuaSessionAction({required super.context});

  @override
  LuaHostDomain get domain => LuaHostDomain.session;
}

class LuaSessionEmitAction extends LuaSessionAction {
  const LuaSessionEmitAction({
    required super.context,
    required this.eventName,
    this.payload = const <String, Object?>{},
  });

  final String eventName;
  final Map<String, Object?> payload;

  @override
  String get actionName => 'session.emit';
}

abstract class LuaInteractionAction extends LuaHostAction {
  const LuaInteractionAction({required super.context});

  @override
  LuaHostDomain get domain => LuaHostDomain.interaction;
}

class LuaInteractionTriggerAction extends LuaInteractionAction {
  const LuaInteractionTriggerAction({
    required super.context,
    required this.trigger,
    this.payload = const <String, Object?>{},
  });

  final String trigger;
  final Map<String, Object?> payload;

  @override
  String get actionName => 'interaction.trigger';
}

class LuaCustomHostAction extends LuaHostAction {
  const LuaCustomHostAction({
    required super.context,
    required this.customDomain,
    required this.customAction,
    this.arguments = const <String, Object?>{},
  });

  final String customDomain;
  final String customAction;
  final Map<String, Object?> arguments;

  @override
  LuaHostDomain get domain => LuaHostDomain.custom;

  @override
  String get actionName => customAction;
}

class LuaHostCallResult<T> {
  const LuaHostCallResult({
    required this.status,
    this.value,
    this.errorCode,
    this.message,
    this.error,
    this.stackTrace,
    this.metadata = const <String, Object?>{},
  });

  final LuaHostCallStatus status;
  final T? value;
  final String? errorCode;
  final String? message;
  final Object? error;
  final StackTrace? stackTrace;
  final Map<String, Object?> metadata;

  bool get isSuccess => status == LuaHostCallStatus.success;
}

class LuaHostActionResult {
  const LuaHostActionResult({
    required this.action,
    required this.result,
  });

  final LuaHostAction action;
  final LuaHostCallResult<Object?> result;
}

class LuaHostBatchResult {
  const LuaHostBatchResult({
    required this.results,
    this.metadata = const <String, Object?>{},
  });

  final List<LuaHostActionResult> results;
  final Map<String, Object?> metadata;

  bool get hasFailure {
    for (final entry in results) {
      if (!entry.result.isSuccess) {
        return true;
      }
    }
    return false;
  }
}

abstract class LuaHostApi {
  Future<LuaHostCallResult<Object?>> invoke(LuaHostAction action);

  Future<LuaHostBatchResult> invokeAll(
    Iterable<LuaHostAction> actions, {
    bool stopOnFailure = false,
  });
}

import '../../image_overlay/services/image_overlay_directive_service.dart';
import '../../live2d_llm/services/live2d_directive_service.dart';
import 'lua_host_api.dart';

class DirectiveLuaHostApi implements LuaHostApi {
  DirectiveLuaHostApi({
    Live2DDirectiveService? live2dDirectiveService,
    ImageOverlayDirectiveService? imageOverlayDirectiveService,
  }) : _live2dDirectiveService =
           live2dDirectiveService ?? Live2DDirectiveService.instance,
       _imageOverlayDirectiveService =
           imageOverlayDirectiveService ?? ImageOverlayDirectiveService.instance;

  final Live2DDirectiveService _live2dDirectiveService;
  final ImageOverlayDirectiveService _imageOverlayDirectiveService;

  @override
  Future<LuaHostCallResult<Object?>> invoke(LuaHostAction action) async {
    try {
      if (action is LuaOverlayMoveAction) {
        await _imageOverlayDirectiveService.executeCommand('move', {
          'x': action.x.toString(),
          'y': action.y.toString(),
          'op': _operationName(action.operation),
          if (action.duration != null)
            'dur': action.duration!.inMilliseconds.toString(),
        });
        return _success(action);
      }

      if (action is LuaOverlayEmotionAction) {
        await _imageOverlayDirectiveService.executeCommand('emotion', {
          'name': action.emotion,
        });
        return _success(action);
      }

      if (action is LuaOverlayWaitAction) {
        await _imageOverlayDirectiveService.executeCommand('wait', {
          'ms': action.duration.inMilliseconds.toString(),
        });
        return _success(action);
      }

      if (action is LuaLive2DParamAction) {
        await _live2dDirectiveService.executeCommand('param', {
          'id': action.parameterId,
          'value': action.value.toString(),
          'op': _operationName(action.operation),
          if (action.duration != null)
            'dur': action.duration!.inMilliseconds.toString(),
        });
        return _success(action);
      }

      if (action is LuaLive2DMotionAction) {
        final attrs = <String, String>{
          if (action.group != null && action.group!.trim().isNotEmpty)
            'group': action.group!,
          if (action.index != null) 'index': action.index!.toString(),
          if (action.name != null && action.name!.trim().isNotEmpty)
            'name': action.name!,
          if (action.priority != null)
            'priority': action.priority!.toString(),
        };
        await _live2dDirectiveService.executeCommand('motion', attrs);
        return _success(action);
      }

      if (action is LuaLive2DExpressionAction) {
        await _live2dDirectiveService.executeCommand('expression', {
          'id': action.expression,
        });
        return _success(action);
      }

      if (action is LuaLive2DEmotionAction) {
        await _live2dDirectiveService.executeCommand('emotion', {
          'name': action.emotion,
        });
        return _success(action);
      }

      if (action is LuaLive2DWaitAction) {
        await _live2dDirectiveService.executeCommand('wait', {
          'ms': action.duration.inMilliseconds.toString(),
        });
        return _success(action);
      }

      if (action is LuaLive2DPresetAction) {
        await _live2dDirectiveService.executeCommand('preset', {
          'name': action.presetName,
          if (action.duration != null)
            'dur': action.duration!.inMilliseconds.toString(),
        });
        return _success(action);
      }

      if (action is LuaLive2DResetAction) {
        await _live2dDirectiveService.executeCommand('reset', {
          if (action.duration != null)
            'dur': action.duration!.inMilliseconds.toString(),
        });
        return _success(action);
      }

      if (action.domain == LuaHostDomain.overlay ||
          action.domain == LuaHostDomain.live2d) {
        return LuaHostCallResult<Object?>(
          status: LuaHostCallStatus.invalidAction,
          errorCode: 'invalid_action',
          message:
              'Unsupported ${action.domain.name} action: ${action.actionName}',
          metadata: _baseMetadata(action),
        );
      }

      return LuaHostCallResult<Object?>(
        status: LuaHostCallStatus.unsupportedAction,
        errorCode: 'domain_not_implemented',
        message:
            'Domain ${action.domain.name} is not implemented by DirectiveLuaHostApi.',
        metadata: _baseMetadata(action),
      );
    } catch (error, stackTrace) {
      return LuaHostCallResult<Object?>(
        status: LuaHostCallStatus.failed,
        errorCode: 'host_action_exception',
        message: 'Host action failed: ${action.actionName}',
        error: error,
        stackTrace: stackTrace,
        metadata: _baseMetadata(action),
      );
    }
  }

  @override
  Future<LuaHostBatchResult> invokeAll(
    Iterable<LuaHostAction> actions, {
    bool stopOnFailure = false,
  }) async {
    final results = <LuaHostActionResult>[];
    var stoppedOnFailure = false;
    var requestedCount = 0;

    for (final action in actions) {
      requestedCount++;
      final result = await invoke(action);
      results.add(LuaHostActionResult(action: action, result: result));
      if (stopOnFailure && !result.isSuccess) {
        stoppedOnFailure = true;
        break;
      }
    }

    return LuaHostBatchResult(
      results: results,
      metadata: <String, Object?>{
        'requestedCount': requestedCount,
        'executedCount': results.length,
        'stopOnFailure': stopOnFailure,
        'stoppedOnFailure': stoppedOnFailure,
      },
    );
  }

  LuaHostCallResult<Object?> _success(LuaHostAction action) {
    return LuaHostCallResult<Object?>(
      status: LuaHostCallStatus.success,
      metadata: _baseMetadata(action),
    );
  }

  Map<String, Object?> _baseMetadata(LuaHostAction action) {
    return <String, Object?>{
      'domain': action.domain.name,
      'actionName': action.actionName,
      if (action.context.scriptId != null) 'scriptId': action.context.scriptId,
      if (action.context.scriptName != null)
        'scriptName': action.context.scriptName,
      if (action.context.hookName != null) 'hookName': action.context.hookName,
      if (action.context.sessionId != null)
        'sessionId': action.context.sessionId,
      if (action.context.interactionId != null)
        'interactionId': action.context.interactionId,
      if (action.context.correlationId != null)
        'correlationId': action.context.correlationId,
    };
  }

  String _operationName(LuaHostNumericOperation operation) {
    return switch (operation) {
      LuaHostNumericOperation.set => 'set',
      LuaHostNumericOperation.del => 'del',
      LuaHostNumericOperation.multiply => 'mul',
    };
  }
}

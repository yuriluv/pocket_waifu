// ============================================================================
// ============================================================================
//
// ============================================================================

import 'dart:async';
import 'package:flutter/services.dart';
import '../../domain/entities/interaction_event.dart';
import 'live2d_log_service.dart';

///
class Live2DNativeBridge {
  static final Live2DNativeBridge _instance = Live2DNativeBridge._internal();
  factory Live2DNativeBridge() => _instance;
  Live2DNativeBridge._internal();

  static const String _tag = 'NativeBridge';

  static const String _channelName = 'com.example.flutter_application_1/live2d';
  static const String _eventChannelName =
      'com.example.flutter_application_1/live2d/events';

  final MethodChannel _methodChannel = const MethodChannel(_channelName);
  final EventChannel _eventChannel = const EventChannel(_eventChannelName);

  StreamSubscription? _eventSubscription;

  final List<InteractionHandler> _eventHandlers = [];

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  Stream<InteractionEvent> get eventStream =>
      _eventChannel.receiveBroadcastStream().map((event) {
        if (event is! Map) {
          return InteractionEvent.now(type: InteractionType.unknown);
        }
        return InteractionEvent.fromMap(Map<String, dynamic>.from(event));
      });

  // ============================================================================
  // ============================================================================

  ///
  Future<void> initialize() async {
    if (_isInitialized) {
      live2dLog.warning(_tag, '이미 초기화됨');
      return;
    }

    try {
      live2dLog.info(_tag, '네이티브 브릿지 초기화 시작');

      _eventSubscription = _eventChannel.receiveBroadcastStream().listen(
        _handleRawNativeEvent,
        onError: (error) {
          live2dLog.error(_tag, '이벤트 스트림 오류', error: error);
        },
      );

      _isInitialized = true;
      live2dLog.info(_tag, '네이티브 브릿지 초기화 완료');
    } catch (e, stack) {
      live2dLog.error(_tag, '초기화 실패', error: e, stackTrace: stack);
    }
  }

  void _handleRawNativeEvent(dynamic event) {
    if (event is! Map) return;

    final map = Map<String, dynamic>.from(event);
    final type = map['type'] as String?;

    if (type == 'nativeLog') {
      live2dLog.addNativeLog(map);
      return;
    }

    if (type == 'stateSync') {
      _handleStateSync(map);
      return;
    }

    if (_isNotificationContractEvent(type)) {
      _notificationContractCallback?.call(map);
    }

    final interactionEvent = InteractionEvent.fromMap(map);
    _handleNativeEvent(interactionEvent);
  }

  bool _isNotificationContractEvent(String? type) {
    return type == 'notificationSessionSync' ||
        type == 'notificationTouchThroughToggled';
  }

  ///
  void _handleStateSync(Map<String, dynamic> data) {
    final isRunning = data['isRunning'] as bool? ?? false;
    final modelLoaded = data['modelLoaded'] as bool? ?? false;
    final uptimeMs = data['uptimeMs'] as int? ?? 0;

    live2dLog.debug(
      _tag,
      '상태 동기화 수신',
      details:
          'running=$isRunning, model=$modelLoaded, uptime=${uptimeMs ~/ 1000}s',
    );

    _stateSyncCallback?.call(data);
  }

  void Function(Map<String, dynamic>)? _stateSyncCallback;
  void Function(Map<String, dynamic>)? _notificationContractCallback;

  ///
  void setStateSyncCallback(void Function(Map<String, dynamic>)? callback) {
    _stateSyncCallback = callback;
  }

  /// Newcastle notification/session sync contract callback.
  void setNotificationContractCallback(
    void Function(Map<String, dynamic>)? callback,
  ) {
    _notificationContractCallback = callback;
  }

  void dispose() {
    _eventSubscription?.cancel();
    _eventSubscription = null;
    _eventHandlers.clear();
    _stateSyncCallback = null;
    _notificationContractCallback = null;
    _isInitialized = false;
    live2dLog.info(_tag, '네이티브 브릿지 정리됨');
  }

  // ============================================================================
  // ============================================================================

  void addEventHandler(InteractionHandler handler) {
    _eventHandlers.add(handler);
  }

  void removeEventHandler(InteractionHandler handler) {
    _eventHandlers.remove(handler);
  }

  void _handleNativeEvent(InteractionEvent event) {
    live2dLog.debug(_tag, '이벤트 수신', details: event.toString());

    for (final handler in _eventHandlers) {
      try {
        handler(event);
      } catch (e) {
        live2dLog.error(_tag, '이벤트 핸들러 오류', error: e);
      }
    }
  }

  // ============================================================================
  // ============================================================================

  Future<bool> showOverlay() async {
    try {
      live2dLog.info(_tag, '오버레이 표시 요청');
      final result = await _methodChannel.invokeMethod<bool>('showOverlay');
      return result ?? false;
    } on PlatformException catch (e) {
      live2dLog.error(_tag, 'showOverlay 실패', error: e);
      return false;
    } on MissingPluginException {
      live2dLog.error(_tag, 'Native 플러그인이 등록되지 않음');
      return false;
    }
  }

  Future<bool> hideOverlay() async {
    try {
      live2dLog.info(_tag, '오버레이 숨김 요청');
      final result = await _methodChannel.invokeMethod<bool>('hideOverlay');
      return result ?? false;
    } on PlatformException catch (e) {
      live2dLog.error(_tag, 'hideOverlay 실패', error: e);
      return false;
    } on MissingPluginException {
      live2dLog.error(_tag, 'Native 플러그인이 등록되지 않음');
      return false;
    }
  }

  Future<bool> isOverlayVisible() async {
    try {
      final result = await _methodChannel.invokeMethod<bool>(
        'isOverlayVisible',
      );
      return result ?? false;
    } on PlatformException catch (e) {
      live2dLog.error(_tag, 'isOverlayVisible 실패', error: e);
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  // ============================================================================
  // ============================================================================

  Future<bool> hasOverlayPermission() async {
    try {
      final result = await _methodChannel.invokeMethod<bool>(
        'hasOverlayPermission',
      );
      return result ?? false;
    } on PlatformException catch (e) {
      live2dLog.error(_tag, 'hasOverlayPermission 실패', error: e);
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  Future<bool> requestOverlayPermission() async {
    try {
      live2dLog.info(_tag, '오버레이 권한 요청');
      final result = await _methodChannel.invokeMethod<bool>(
        'requestOverlayPermission',
      );
      return result ?? false;
    } on PlatformException catch (e) {
      live2dLog.error(_tag, 'requestOverlayPermission 실패', error: e);
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  Future<bool> hasStoragePermission() async {
    try {
      final result = await _methodChannel.invokeMethod<bool>(
        'hasStoragePermission',
      );
      return result ?? false;
    } on PlatformException catch (e) {
      live2dLog.error(_tag, 'hasStoragePermission 실패', error: e);
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  Future<bool> requestStoragePermission() async {
    try {
      live2dLog.info(_tag, '저장소 권한 요청');
      final result = await _methodChannel.invokeMethod<bool>(
        'requestStoragePermission',
      );
      return result ?? false;
    } on PlatformException catch (e) {
      live2dLog.error(_tag, 'requestStoragePermission 실패', error: e);
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  // ============================================================================
  // ============================================================================

  ///
  Future<bool> loadModel(String modelPath) async {
    try {
      live2dLog.info(_tag, '모델 로드 요청', details: modelPath);
      final result = await _methodChannel.invokeMethod<bool>('loadModel', {
        'path': modelPath,
      });
      return result ?? false;
    } on PlatformException catch (e) {
      live2dLog.error(_tag, 'loadModel 실패', error: e);
      return false;
    } on MissingPluginException {
      live2dLog.error(_tag, 'Native 플러그인이 등록되지 않음');
      return false;
    }
  }

  Future<bool> unloadModel() async {
    try {
      live2dLog.info(_tag, '모델 언로드 요청');
      final result = await _methodChannel.invokeMethod<bool>('unloadModel');
      return result ?? false;
    } on PlatformException catch (e) {
      live2dLog.error(_tag, 'unloadModel 실패', error: e);
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  ///
  Future<bool> playMotion(String group, int index, {int priority = 2}) async {
    try {
      live2dLog.debug(_tag, '모션 재생', details: '$group[$index]');
      final result = await _methodChannel.invokeMethod<bool>('playMotion', {
        'group': group,
        'index': index,
        'priority': priority,
      });
      return result ?? false;
    } on PlatformException catch (e) {
      live2dLog.error(_tag, 'playMotion 실패', error: e);
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  Future<bool> setExpression(String expressionId) async {
    try {
      live2dLog.debug(_tag, '표정 설정', details: expressionId);
      final result = await _methodChannel.invokeMethod<bool>('setExpression', {
        'id': expressionId,
      });
      return result ?? false;
    } on PlatformException catch (e) {
      live2dLog.error(_tag, 'setExpression 실패', error: e);
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  Future<bool> setRandomExpression() async {
    try {
      final result = await _methodChannel.invokeMethod<bool>(
        'setRandomExpression',
      );
      return result ?? false;
    } on PlatformException catch (e) {
      live2dLog.error(_tag, 'setRandomExpression 실패', error: e);
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  // ============================================================================
  // ============================================================================

  Future<bool> setScale(double scale) async {
    try {
      final result = await _methodChannel.invokeMethod<bool>('setScale', {
        'scale': scale,
      });
      return result ?? false;
    } on PlatformException catch (e) {
      live2dLog.error(_tag, 'setScale 실패', error: e);
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  Future<bool> setOpacity(double opacity) async {
    try {
      final result = await _methodChannel.invokeMethod<bool>('setOpacity', {
        'opacity': opacity,
      });
      return result ?? false;
    } on PlatformException catch (e) {
      live2dLog.error(_tag, 'setOpacity 실패', error: e);
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  Future<bool> setTouchThroughEnabled(bool enabled) async {
    try {
      final result = await _methodChannel.invokeMethod<bool>(
        'setTouchThroughEnabled',
        {'enabled': enabled},
      );
      return result ?? false;
    } on PlatformException catch (e) {
      live2dLog.error(_tag, 'setTouchThroughEnabled 실패', error: e);
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  Future<bool> setTouchThroughAlpha(int alpha) async {
    try {
      final result = await _methodChannel.invokeMethod<bool>(
        'setTouchThroughAlpha',
        {'alpha': alpha},
      );
      return result ?? false;
    } on PlatformException catch (e) {
      live2dLog.error(_tag, 'setTouchThroughAlpha 실패', error: e);
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  Future<bool> setCharacterOpacity(double opacity) async {
    try {
      final result = await _methodChannel.invokeMethod<bool>(
        'setCharacterOpacity',
        {'opacity': opacity},
      );
      return result ?? false;
    } on PlatformException catch (e) {
      live2dLog.error(_tag, 'setCharacterOpacity 실패', error: e);
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  Future<bool> setNotificationResponse(
    String message, {
    String? sessionId,
  }) async {
    try {
      final result = await _methodChannel.invokeMethod<bool>(
        'setNotificationResponse',
        {'message': message, 'sessionId': ?sessionId},
      );
      return result ?? false;
    } on PlatformException catch (e) {
      live2dLog.error(_tag, 'setNotificationResponse 실패', error: e);
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  Future<bool> setNotificationError(
    String errorMessage, {
    String? sessionId,
  }) async {
    try {
      final result = await _methodChannel.invokeMethod<bool>(
        'setNotificationError',
        {'error': errorMessage, 'sessionId': ?sessionId},
      );
      return result ?? false;
    } on PlatformException catch (e) {
      live2dLog.error(_tag, 'setNotificationError 실패', error: e);
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  Future<bool> setEditMode(bool enabled) async {
    try {
      final result = await _methodChannel.invokeMethod<bool>('setEditMode', {
        'enabled': enabled,
      });
      return result ?? false;
    } on PlatformException catch (e) {
      live2dLog.error(_tag, 'setEditMode 실패', error: e);
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  Future<bool> setCharacterPinned(bool enabled) async {
    try {
      final result = await _methodChannel.invokeMethod<bool>(
        'setCharacterPinned',
        {'enabled': enabled},
      );
      return result ?? false;
    } on PlatformException catch (e) {
      live2dLog.error(_tag, 'setCharacterPinned 실패', error: e);
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  Future<bool> setRelativeScale(double scale) async {
    try {
      final result = await _methodChannel.invokeMethod<bool>(
        'setRelativeScale',
        {'scale': scale},
      );
      return result ?? false;
    } on PlatformException catch (e) {
      live2dLog.error(_tag, 'setRelativeScale 실패', error: e);
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  Future<bool> setCharacterOffset(double x, double y) async {
    try {
      final result = await _methodChannel.invokeMethod<bool>(
        'setCharacterOffset',
        {'x': x, 'y': y},
      );
      return result ?? false;
    } on PlatformException catch (e) {
      live2dLog.error(_tag, 'setCharacterOffset 실패', error: e);
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  Future<bool> setCharacterRotation(int degrees) async {
    try {
      final result = await _methodChannel.invokeMethod<bool>(
        'setCharacterRotation',
        {'degrees': degrees},
      );
      return result ?? false;
    } on PlatformException catch (e) {
      live2dLog.error(_tag, 'setCharacterRotation 실패', error: e);
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  Future<Map<String, dynamic>> getDisplayState() async {
    try {
      final result = await _methodChannel.invokeMethod<Map<dynamic, dynamic>>(
        'getDisplayState',
      );
      if (result == null) return {};
      return Map<String, dynamic>.from(result);
    } on PlatformException catch (e) {
      live2dLog.error(_tag, 'getDisplayState 실패', error: e);
      return {};
    } on MissingPluginException {
      return {};
    }
  }

  Future<bool> setParameter(
    String paramId,
    double value, {
    int durationMs = 200,
  }) async {
    try {
      final result = await _methodChannel.invokeMethod<bool>('setParameter', {
        'id': paramId,
        'value': value,
        'durationMs': durationMs,
      });
      return result ?? false;
    } on PlatformException catch (e) {
      live2dLog.error(_tag, 'setParameter 실패', error: e);
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  Future<double?> getParameter(String paramId) async {
    try {
      final result = await _methodChannel.invokeMethod<double>('getParameter', {
        'id': paramId,
      });
      return result;
    } on PlatformException catch (e) {
      live2dLog.error(_tag, 'getParameter 실패', error: e);
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  Future<List<String>> getParameterIds() async {
    try {
      final result = await _methodChannel.invokeMethod<List<dynamic>>(
        'getParameterIds',
      );
      return result?.cast<String>() ?? [];
    } on PlatformException catch (e) {
      live2dLog.error(_tag, 'getParameterIds 실패', error: e);
      return [];
    } on MissingPluginException {
      return [];
    }
  }

  Future<bool> setPosition(double x, double y) async {
    try {
      final result = await _methodChannel.invokeMethod<bool>('setPosition', {
        'x': x,
        'y': y,
      });
      return result ?? false;
    } on PlatformException catch (e) {
      live2dLog.error(_tag, 'setPosition 실패', error: e);
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  Future<bool> setSize(int width, int height) async {
    try {
      final result = await _methodChannel.invokeMethod<bool>('setSize', {
        'width': width,
        'height': height,
      });
      return result ?? false;
    } on PlatformException catch (e) {
      live2dLog.error(_tag, 'setSize 실패', error: e);
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  // ============================================================================
  // ============================================================================

  Future<bool> setEyeBlink(bool enabled) async {
    try {
      final result = await _methodChannel.invokeMethod<bool>('setEyeBlink', {
        'enabled': enabled,
      });
      return result ?? false;
    } on PlatformException catch (e) {
      live2dLog.error(_tag, 'setEyeBlink 실패', error: e);
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  Future<bool> setBreathing(bool enabled) async {
    try {
      final result = await _methodChannel.invokeMethod<bool>('setBreathing', {
        'enabled': enabled,
      });
      return result ?? false;
    } on PlatformException catch (e) {
      live2dLog.error(_tag, 'setBreathing 실패', error: e);
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  Future<bool> setLookAt(bool enabled) async {
    try {
      final result = await _methodChannel.invokeMethod<bool>('setLookAt', {
        'enabled': enabled,
      });
      return result ?? false;
    } on PlatformException catch (e) {
      live2dLog.error(_tag, 'setLookAt 실패', error: e);
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  // ============================================================================
  // ============================================================================

  Future<bool> setAutoMotion(bool enabled) async {
    try {
      final result = await _methodChannel.invokeMethod<bool>('setAutoMotion', {
        'enabled': enabled,
      });
      return result ?? false;
    } on PlatformException catch (e) {
      live2dLog.error(_tag, 'setAutoMotion 실패', error: e);
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  Future<bool> setAccessory(String accessoryId, bool enabled) async {
    try {
      final result = await _methodChannel.invokeMethod<bool>('setAccessory', {
        'id': accessoryId,
        'enabled': enabled,
      });
      return result ?? false;
    } on PlatformException catch (e) {
      live2dLog.error(_tag, 'setAccessory 실패', error: e);
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> getAccessories() async {
    try {
      final result = await _methodChannel.invokeMethod<List<dynamic>>(
        'getAccessories',
      );
      if (result == null) return [];
      return result.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } on PlatformException catch (e) {
      live2dLog.error(_tag, 'getAccessories 실패', error: e);
      return [];
    } on MissingPluginException {
      return [];
    }
  }

  // ============================================================================
  // ============================================================================

  ///
  Future<bool> sendSignal(
    String signalName, {
    Map<String, dynamic>? data,
  }) async {
    try {
      live2dLog.debug(_tag, '신호 전송', details: signalName);
      final result = await _methodChannel.invokeMethod<bool>('sendSignal', {
        'signal': signalName,
        'data': data ?? {},
      });
      return result ?? false;
    } on PlatformException catch (e) {
      live2dLog.error(_tag, 'sendSignal 실패', error: e);
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  // ============================================================================
  // ============================================================================

  Future<List<String>> getMotionGroups() async {
    try {
      final result = await _methodChannel.invokeMethod<List<dynamic>>(
        'getMotionGroups',
      );
      return result?.cast<String>() ?? [];
    } on PlatformException catch (e) {
      live2dLog.error(_tag, 'getMotionGroups 실패', error: e);
      return [];
    } on MissingPluginException {
      return [];
    }
  }

  Future<int> getMotionCount(String group) async {
    try {
      final result = await _methodChannel.invokeMethod<int>('getMotionCount', {
        'group': group,
      });
      return result ?? 0;
    } on PlatformException catch (e) {
      live2dLog.error(_tag, 'getMotionCount 실패', error: e);
      return 0;
    } on MissingPluginException {
      return 0;
    }
  }

  Future<List<String>> getMotionNames(String group) async {
    try {
      final result = await _methodChannel.invokeMethod<List<dynamic>>(
        'getMotionNames',
        {'group': group},
      );
      return result?.cast<String>() ?? [];
    } on PlatformException catch (e) {
      live2dLog.error(_tag, 'getMotionNames 실패', error: e);
      return [];
    } on MissingPluginException {
      return [];
    }
  }

  Future<List<String>> getExpressions() async {
    try {
      final result = await _methodChannel.invokeMethod<List<dynamic>>(
        'getExpressions',
      );
      return result?.cast<String>() ?? [];
    } on PlatformException catch (e) {
      live2dLog.error(_tag, 'getExpressions 실패', error: e);
      return [];
    } on MissingPluginException {
      return [];
    }
  }

  Future<Map<String, dynamic>> getModelInfo() async {
    try {
      final result = await _methodChannel.invokeMethod<Map<dynamic, dynamic>>(
        'getModelInfo',
      );
      if (result == null) return {};
      return Map<String, dynamic>.from(result);
    } on PlatformException catch (e) {
      live2dLog.error(_tag, 'getModelInfo 실패', error: e);
      return {};
    } on MissingPluginException {
      return {};
    }
  }

  ///
  Future<Map<String, dynamic>> analyzeModel(String modelPath) async {
    try {
      live2dLog.debug(_tag, '모델 분석', details: modelPath);
      final result = await _methodChannel.invokeMethod<Map<dynamic, dynamic>>(
        'analyzeModel',
        {'path': modelPath},
      );
      if (result == null) return {};
      return Map<String, dynamic>.from(result);
    } on PlatformException catch (e) {
      live2dLog.error(_tag, 'analyzeModel 실패', error: e);
      return {};
    } on MissingPluginException {
      return {};
    }
  }

  Future<Map<String, int>> getOverlaySize() async {
    try {
      final result = await _methodChannel.invokeMethod<Map<dynamic, dynamic>>(
        'getOverlaySize',
      );
      if (result == null) return {'width': 300, 'height': 400};
      return {
        'width': (result['width'] as int?) ?? 300,
        'height': (result['height'] as int?) ?? 400,
      };
    } on PlatformException catch (e) {
      live2dLog.error(_tag, 'getOverlaySize 실패', error: e);
      return {'width': 300, 'height': 400};
    } on MissingPluginException {
      return {'width': 300, 'height': 400};
    }
  }

  // ============================================================================
  // ============================================================================

  Future<bool> setTargetFps(int fps) async {
    try {
      final result = await _methodChannel.invokeMethod<bool>('setTargetFps', {
        'fps': fps,
      });
      return result ?? false;
    } on PlatformException catch (e) {
      live2dLog.error(_tag, 'setTargetFps 실패', error: e);
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  Future<bool> setLowPowerMode(bool enabled) async {
    try {
      final result = await _methodChannel.invokeMethod<bool>(
        'setLowPowerMode',
        {'enabled': enabled},
      );
      return result ?? false;
    } on PlatformException catch (e) {
      live2dLog.error(_tag, 'setLowPowerMode 실패', error: e);
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  // ============================================================================
  // ============================================================================

  ///
  Future<Map<String, dynamic>> getHealthStatus() async {
    try {
      live2dLog.debug(_tag, 'Health status 조회');
      final result = await _methodChannel.invokeMethod<Map<dynamic, dynamic>>(
        'getHealthStatus',
      );
      if (result == null) return {'error': 'null response'};
      return Map<String, dynamic>.from(result);
    } on PlatformException catch (e) {
      live2dLog.error(_tag, 'getHealthStatus 실패', error: e);
      return {'error': e.message};
    } on MissingPluginException {
      return {'error': 'Plugin not registered'};
    }
  }

  ///
  Future<bool> forceReset() async {
    try {
      live2dLog.warning(_tag, '강제 재설정 요청');
      final result = await _methodChannel.invokeMethod<bool>('forceReset');
      return result ?? false;
    } on PlatformException catch (e) {
      live2dLog.error(_tag, 'forceReset 실패', error: e);
      return false;
    } on MissingPluginException {
      return false;
    }
  }
}

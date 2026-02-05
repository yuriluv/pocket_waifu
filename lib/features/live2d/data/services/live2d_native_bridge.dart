// ============================================================================
// Live2D 네이티브 브릿지 (Live2D Native Bridge)
// ============================================================================
// Flutter와 Android Native 모듈 간의 통신을 담당합니다.
// Platform Channel (MethodChannel, EventChannel)을 사용합니다.
//
// 주요 기능:
// - 오버레이 제어 (표시/숨김)
// - 모델 로드/언로드
// - 모션/표정 재생
// - 디스플레이 설정 (크기, 위치, 투명도)
// - 상호작용 이벤트 수신 (추후 확장)
// ============================================================================

import 'dart:async';
import 'package:flutter/services.dart';
import '../../domain/entities/interaction_event.dart';
import 'live2d_log_service.dart';

/// Live2D 네이티브 브릿지
/// 
/// Flutter와 Android Native 모듈 간의 통신을 담당하는 싱글톤 클래스입니다.
class Live2DNativeBridge {
  // === 싱글톤 패턴 ===
  static final Live2DNativeBridge _instance = Live2DNativeBridge._internal();
  factory Live2DNativeBridge() => _instance;
  Live2DNativeBridge._internal();

  static const String _tag = 'NativeBridge';

  // === Platform Channel 정의 ===
  static const String _channelName = 'com.example.flutter_application_1/live2d';
  static const String _eventChannelName = 'com.example.flutter_application_1/live2d/events';
  
  final MethodChannel _methodChannel = const MethodChannel(_channelName);
  final EventChannel _eventChannel = const EventChannel(_eventChannelName);
  
  // === 이벤트 스트림 ===
  StreamSubscription? _eventSubscription;
  
  // === 이벤트 콜백 ===
  final List<InteractionHandler> _eventHandlers = [];
  
  // === 상태 ===
  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  // ============================================================================
  // 초기화 / 정리
  // ============================================================================

  /// 브릿지 초기화
  /// 
  /// 앱 시작 시 호출하여 이벤트 스트림을 설정합니다.
  Future<void> initialize() async {
    if (_isInitialized) {
      live2dLog.warning(_tag, '이미 초기화됨');
      return;
    }
    
    try {
      live2dLog.info(_tag, '네이티브 브릿지 초기화 시작');
      
      // 이벤트 스트림 설정 (Native 로그 포함)
      _eventSubscription = _eventChannel
          .receiveBroadcastStream()
          .listen(
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
  
  /// Raw Native 이벤트 처리 (로그 포함)
  void _handleRawNativeEvent(dynamic event) {
    if (event is! Map) return;
    
    final map = Map<String, dynamic>.from(event);
    final type = map['type'] as String?;
    
    // Native 로그 이벤트 처리
    if (type == 'nativeLog') {
      live2dLog.addNativeLog(map);
      return;
    }
    
    // 일반 상호작용 이벤트 처리
    final interactionEvent = InteractionEvent.fromMap(map);
    _handleNativeEvent(interactionEvent);
  }

  /// 브릿지 정리
  void dispose() {
    _eventSubscription?.cancel();
    _eventSubscription = null;
    _eventHandlers.clear();
    _isInitialized = false;
    live2dLog.info(_tag, '네이티브 브릿지 정리됨');
  }

  // ============================================================================
  // 이벤트 핸들링
  // ============================================================================

  /// 이벤트 핸들러 등록
  void addEventHandler(InteractionHandler handler) {
    _eventHandlers.add(handler);
  }

  /// 이벤트 핸들러 제거
  void removeEventHandler(InteractionHandler handler) {
    _eventHandlers.remove(handler);
  }

  /// 네이티브 이벤트 처리
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
  // 오버레이 제어
  // ============================================================================

  /// 오버레이 표시
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

  /// 오버레이 숨김
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

  /// 오버레이 표시 상태 확인
  Future<bool> isOverlayVisible() async {
    try {
      final result = await _methodChannel.invokeMethod<bool>('isOverlayVisible');
      return result ?? false;
    } on PlatformException catch (e) {
      live2dLog.error(_tag, 'isOverlayVisible 실패', error: e);
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  // ============================================================================
  // 권한 관리
  // ============================================================================

  /// 오버레이 권한 확인
  Future<bool> hasOverlayPermission() async {
    try {
      final result = await _methodChannel.invokeMethod<bool>('hasOverlayPermission');
      return result ?? false;
    } on PlatformException catch (e) {
      live2dLog.error(_tag, 'hasOverlayPermission 실패', error: e);
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  /// 오버레이 권한 요청
  Future<bool> requestOverlayPermission() async {
    try {
      live2dLog.info(_tag, '오버레이 권한 요청');
      final result = await _methodChannel.invokeMethod<bool>('requestOverlayPermission');
      return result ?? false;
    } on PlatformException catch (e) {
      live2dLog.error(_tag, 'requestOverlayPermission 실패', error: e);
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  /// 저장소 권한 확인
  Future<bool> hasStoragePermission() async {
    try {
      final result = await _methodChannel.invokeMethod<bool>('hasStoragePermission');
      return result ?? false;
    } on PlatformException catch (e) {
      live2dLog.error(_tag, 'hasStoragePermission 실패', error: e);
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  /// 저장소 권한 요청
  Future<bool> requestStoragePermission() async {
    try {
      live2dLog.info(_tag, '저장소 권한 요청');
      final result = await _methodChannel.invokeMethod<bool>('requestStoragePermission');
      return result ?? false;
    } on PlatformException catch (e) {
      live2dLog.error(_tag, 'requestStoragePermission 실패', error: e);
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  // ============================================================================
  // 모델 제어
  // ============================================================================

  /// 모델 로드
  /// 
  /// [modelPath]는 model3.json 파일의 절대 경로입니다.
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

  /// 모델 언로드
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

  /// 모션 재생
  /// 
  /// [group]: 모션 그룹 이름 (예: "idle", "tap", "flick")
  /// [index]: 그룹 내 모션 인덱스
  /// [priority]: 우선순위 (1: idle, 2: normal, 3: force)
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

  /// 표정 설정
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

  /// 랜덤 표정 설정
  Future<bool> setRandomExpression() async {
    try {
      final result = await _methodChannel.invokeMethod<bool>('setRandomExpression');
      return result ?? false;
    } on PlatformException catch (e) {
      live2dLog.error(_tag, 'setRandomExpression 실패', error: e);
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  // ============================================================================
  // 디스플레이 설정
  // ============================================================================

  /// 크기 설정 (스케일)
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

  /// 투명도 설정
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

  /// 위치 설정 (비율 0.0 ~ 1.0 또는 픽셀 값)
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

  /// 크기 설정 (픽셀)
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
  // 자동 동작 설정
  // ============================================================================

  /// 눈 깜빡임 설정
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

  /// 호흡 설정
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

  /// 시선 추적 설정
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
  // 상호작용 신호 (추후 확장)
  // ============================================================================

  /// 외부 신호 전송
  /// 
  /// 다른 앱 기능에서 Live2D에 명령을 보낼 때 사용합니다.
  /// 예: 채팅 응답 시 감정 표현, 알림 시 반응 등
  Future<bool> sendSignal(String signalName, {Map<String, dynamic>? data}) async {
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
  // 모델 정보 조회
  // ============================================================================

  /// 모션 그룹 목록 조회
  Future<List<String>> getMotionGroups() async {
    try {
      final result = await _methodChannel.invokeMethod<List<dynamic>>('getMotionGroups');
      return result?.cast<String>() ?? [];
    } on PlatformException catch (e) {
      live2dLog.error(_tag, 'getMotionGroups 실패', error: e);
      return [];
    } on MissingPluginException {
      return [];
    }
  }

  /// 특정 그룹의 모션 수 조회
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

  /// 표정 목록 조회
  Future<List<String>> getExpressions() async {
    try {
      final result = await _methodChannel.invokeMethod<List<dynamic>>('getExpressions');
      return result?.cast<String>() ?? [];
    } on PlatformException catch (e) {
      live2dLog.error(_tag, 'getExpressions 실패', error: e);
      return [];
    } on MissingPluginException {
      return [];
    }
  }

  /// 현재 로드된 모델의 상세 정보 조회
  Future<Map<String, dynamic>> getModelInfo() async {
    try {
      final result = await _methodChannel.invokeMethod<Map<dynamic, dynamic>>('getModelInfo');
      if (result == null) return {};
      return Map<String, dynamic>.from(result);
    } on PlatformException catch (e) {
      live2dLog.error(_tag, 'getModelInfo 실패', error: e);
      return {};
    } on MissingPluginException {
      return {};
    }
  }

  /// 모델 파일 분석 (로드하지 않고 정보만 추출)
  /// 
  /// model3.json 파일을 파싱하여 모션, 표정, 텍스처 정보를 반환합니다.
  Future<Map<String, dynamic>> analyzeModel(String modelPath) async {
    try {
      live2dLog.debug(_tag, '모델 분석', details: modelPath);
      final result = await _methodChannel.invokeMethod<Map<dynamic, dynamic>>('analyzeModel', {
        'path': modelPath,
      });
      if (result == null) return {};
      return Map<String, dynamic>.from(result);
    } on PlatformException catch (e) {
      live2dLog.error(_tag, 'analyzeModel 실패', error: e);
      return {};
    } on MissingPluginException {
      return {};
    }
  }

  // ============================================================================
  // 렌더링 설정
  // ============================================================================

  /// 목표 FPS 설정
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

  /// 저전력 모드 설정
  Future<bool> setLowPowerMode(bool enabled) async {
    try {
      final result = await _methodChannel.invokeMethod<bool>('setLowPowerMode', {
        'enabled': enabled,
      });
      return result ?? false;
    } on PlatformException catch (e) {
      live2dLog.error(_tag, 'setLowPowerMode 실패', error: e);
      return false;
    } on MissingPluginException {
      return false;
    }
  }
}

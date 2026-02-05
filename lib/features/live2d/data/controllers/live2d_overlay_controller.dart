// ============================================================================
// Live2D 오버레이 컨트롤러 (Live2D Overlay Controller)
// ============================================================================
// Flutter 앱에서 Live2D 오버레이를 쉽게 제어할 수 있는 고수준 API를 제공합니다.
//
// 사용법:
// ```dart
// final controller = Live2DOverlayController();
// await controller.initialize();
// 
// // 오버레이 표시
// await controller.show();
// 
// // 모델 로드
// await controller.loadModel('/path/to/model3.json');
// 
// // 모션 재생
// await controller.playMotion('idle');
// ```
// ============================================================================

import 'dart:async';
import 'package:flutter/foundation.dart';
import '../services/live2d_native_bridge.dart';
import '../services/live2d_log_service.dart';
import '../../domain/entities/interaction_event.dart';

/// Live2D 오버레이 상태
enum Live2DOverlayState {
  /// 초기화 전
  uninitialized,
  /// 초기화 중
  initializing,
  /// 준비됨 (오버레이 숨김)
  ready,
  /// 오버레이 표시 중
  visible,
  /// 모델 로딩 중
  loadingModel,
  /// 오류 발생
  error,
}

/// Live2D 오버레이 컨트롤러
/// 
/// Live2D 오버레이의 전체 생명주기를 관리하고 고수준 API를 제공합니다.
class Live2DOverlayController extends ChangeNotifier {
  static const String _tag = 'OverlayController';
  
  final Live2DNativeBridge _bridge = Live2DNativeBridge();
  
  // === 상태 ===
  Live2DOverlayState _state = Live2DOverlayState.uninitialized;
  Live2DOverlayState get state => _state;
  
  String? _currentModelPath;
  String? get currentModelPath => _currentModelPath;
  
  String? _lastError;
  String? get lastError => _lastError;
  
  // === 설정 ===
  double _scale = 1.0;
  double get scale => _scale;
  
  double _opacity = 1.0;
  double get opacity => _opacity;
  
  int _positionX = 0;
  int _positionY = 100;
  int get positionX => _positionX;
  int get positionY => _positionY;
  
  // === 이벤트 핸들러 ===
  final List<InteractionHandler> _interactionHandlers = [];
  
  // ============================================================================
  // 초기화 / 정리
  // ============================================================================
  
  /// 컨트롤러 초기화
  Future<bool> initialize() async {
    if (_state == Live2DOverlayState.initializing) {
      live2dLog.warning(_tag, '이미 초기화 중');
      return false;
    }
    
    if (_state != Live2DOverlayState.uninitialized) {
      live2dLog.info(_tag, '이미 초기화됨');
      return true;
    }
    
    _setState(Live2DOverlayState.initializing);
    
    try {
      live2dLog.info(_tag, '컨트롤러 초기화 시작');
      
      // 네이티브 브릿지 초기화
      await _bridge.initialize();
      
      // 이벤트 핸들러 등록
      _bridge.addEventHandler(_handleNativeEvent);
      
      _setState(Live2DOverlayState.ready);
      live2dLog.info(_tag, '컨트롤러 초기화 완료');
      
      return true;
    } catch (e, stack) {
      live2dLog.error(_tag, '초기화 실패', error: e, stackTrace: stack);
      _lastError = e.toString();
      _setState(Live2DOverlayState.error);
      return false;
    }
  }
  
  /// 컨트롤러 정리
  @override
  void dispose() {
    _bridge.removeEventHandler(_handleNativeEvent);
    _interactionHandlers.clear();
    _bridge.dispose();
    super.dispose();
  }
  
  // ============================================================================
  // 오버레이 제어
  // ============================================================================
  
  /// 오버레이 표시
  Future<bool> show() async {
    if (_state == Live2DOverlayState.uninitialized) {
      await initialize();
    }
    
    if (_state != Live2DOverlayState.ready && _state != Live2DOverlayState.visible) {
      live2dLog.warning(_tag, '오버레이 표시 불가 상태: $_state');
      return false;
    }
    
    try {
      final result = await _bridge.showOverlay();
      if (result) {
        _setState(Live2DOverlayState.visible);
      }
      return result;
    } catch (e) {
      live2dLog.error(_tag, '오버레이 표시 실패', error: e);
      return false;
    }
  }
  
  /// 오버레이 숨김
  Future<bool> hide() async {
    if (_state != Live2DOverlayState.visible) {
      return true; // 이미 숨김 상태
    }
    
    try {
      final result = await _bridge.hideOverlay();
      if (result) {
        _setState(Live2DOverlayState.ready);
      }
      return result;
    } catch (e) {
      live2dLog.error(_tag, '오버레이 숨김 실패', error: e);
      return false;
    }
  }
  
  /// 오버레이 토글
  Future<bool> toggle() async {
    if (_state == Live2DOverlayState.visible) {
      return hide();
    } else {
      return show();
    }
  }
  
  /// 오버레이 표시 여부
  bool get isVisible => _state == Live2DOverlayState.visible;
  
  // ============================================================================
  // 모델 제어
  // ============================================================================
  
  /// 모델 로드
  /// 
  /// [modelPath]는 model3.json 파일의 절대 경로입니다.
  Future<bool> loadModel(String modelPath) async {
    if (_state == Live2DOverlayState.uninitialized) {
      await initialize();
    }
    
    _setState(Live2DOverlayState.loadingModel);
    
    try {
      live2dLog.info(_tag, '모델 로드 중', details: modelPath);
      
      final result = await _bridge.loadModel(modelPath);
      
      if (result) {
        _currentModelPath = modelPath;
        _setState(_state == Live2DOverlayState.loadingModel 
            ? Live2DOverlayState.visible 
            : _state);
        live2dLog.info(_tag, '모델 로드 성공');
      } else {
        _lastError = '모델 로드 실패';
        _setState(Live2DOverlayState.error);
      }
      
      return result;
    } catch (e, stack) {
      live2dLog.error(_tag, '모델 로드 실패', error: e, stackTrace: stack);
      _lastError = e.toString();
      _setState(Live2DOverlayState.error);
      return false;
    }
  }
  
  /// 모델 언로드
  Future<bool> unloadModel() async {
    try {
      final result = await _bridge.unloadModel();
      if (result) {
        _currentModelPath = null;
      }
      return result;
    } catch (e) {
      live2dLog.error(_tag, '모델 언로드 실패', error: e);
      return false;
    }
  }
  
  // ============================================================================
  // 모션 / 표정
  // ============================================================================
  
  /// 모션 재생
  /// 
  /// [motionName]: 모션 이름 (예: "idle", "tap_body", "flick_head")
  /// [loop]: 반복 여부
  Future<bool> playMotion(String motionName, {bool loop = false}) async {
    final priority = loop ? 1 : 2;
    return _bridge.playMotion(motionName, 0, priority: priority);
  }
  
  /// 표정 설정
  Future<bool> setExpression(String expressionName) async {
    return _bridge.setExpression(expressionName);
  }
  
  /// 랜덤 표정
  Future<bool> setRandomExpression() async {
    return _bridge.setRandomExpression();
  }
  
  // ============================================================================
  // 디스플레이 설정
  // ============================================================================
  
  /// 스케일 설정
  Future<bool> setScale(double value) async {
    final result = await _bridge.setScale(value);
    if (result) {
      _scale = value;
      notifyListeners();
    }
    return result;
  }
  
  /// 투명도 설정
  Future<bool> setOpacity(double value) async {
    final result = await _bridge.setOpacity(value);
    if (result) {
      _opacity = value;
      notifyListeners();
    }
    return result;
  }
  
  /// 위치 설정
  Future<bool> setPosition(double x, double y) async {
    final result = await _bridge.setPosition(x, y);
    if (result) {
      _positionX = x.toInt();
      _positionY = y.toInt();
      notifyListeners();
    }
    return result;
  }
  
  /// 크기 설정 (픽셀)
  Future<bool> setSize(int width, int height) async {
    return _bridge.setSize(width, height);
  }
  
  // ============================================================================
  // 자동 동작 설정
  // ============================================================================
  
  /// 눈 깜빡임 설정
  Future<bool> setEyeBlink(bool enabled) async {
    return _bridge.setEyeBlink(enabled);
  }
  
  /// 호흡 설정
  Future<bool> setBreathing(bool enabled) async {
    return _bridge.setBreathing(enabled);
  }
  
  /// 시선 추적 설정
  Future<bool> setLookAt(bool enabled) async {
    return _bridge.setLookAt(enabled);
  }
  
  // ============================================================================
  // 외부 연동
  // ============================================================================
  
  /// 외부 신호 전송
  /// 
  /// 앱의 다른 기능에서 Live2D에 명령을 보낼 때 사용합니다.
  /// 예: 채팅 응답 시 감정 표현, 알림 시 반응 등
  Future<bool> sendSignal(String signal, {Map<String, dynamic>? data}) async {
    return _bridge.sendSignal(signal, data: data);
  }
  
  // ============================================================================
  // 이벤트 핸들링
  // ============================================================================
  
  /// 상호작용 이벤트 핸들러 등록
  void addInteractionHandler(InteractionHandler handler) {
    _interactionHandlers.add(handler);
  }
  
  /// 상호작용 이벤트 핸들러 제거
  void removeInteractionHandler(InteractionHandler handler) {
    _interactionHandlers.remove(handler);
  }
  
  /// 네이티브 이벤트 처리
  void _handleNativeEvent(InteractionEvent event) {
    // 시스템 이벤트 처리
    switch (event.type) {
      case InteractionType.overlayShown:
        _setState(Live2DOverlayState.visible);
        break;
      case InteractionType.overlayHidden:
        _setState(Live2DOverlayState.ready);
        break;
      case InteractionType.modelLoaded:
        _currentModelPath = event.extras?['path'] as String?;
        break;
      default:
        break;
    }
    
    // 등록된 핸들러에 전달
    for (final handler in _interactionHandlers) {
      try {
        handler(event);
      } catch (e) {
        live2dLog.error(_tag, '핸들러 오류', error: e);
      }
    }
  }
  
  // ============================================================================
  // 내부 유틸리티
  // ============================================================================
  
  void _setState(Live2DOverlayState newState) {
    if (_state != newState) {
      _state = newState;
      notifyListeners();
    }
  }
}

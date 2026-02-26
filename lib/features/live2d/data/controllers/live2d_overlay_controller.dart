// ============================================================================
// ============================================================================
//
// ```dart
// final controller = Live2DOverlayController();
// await controller.initialize();
// 
// await controller.show();
// 
// await controller.loadModel('/path/to/model3.json');
// 
// await controller.playMotion('idle');
// ```
// ============================================================================

import 'dart:async';
import 'package:flutter/foundation.dart';
import '../services/live2d_native_bridge.dart';
import '../services/live2d_log_service.dart';
import '../../domain/entities/interaction_event.dart';

enum Live2DOverlayState {
  uninitialized,
  initializing,
  ready,
  visible,
  loadingModel,
  error,
}

/// 
class Live2DOverlayController extends ChangeNotifier {
  static const String _tag = 'OverlayController';
  
  final Live2DNativeBridge _bridge = Live2DNativeBridge();
  
  Live2DOverlayState _state = Live2DOverlayState.uninitialized;
  Live2DOverlayState get state => _state;
  
  String? _currentModelPath;
  String? get currentModelPath => _currentModelPath;
  
  String? _lastError;
  String? get lastError => _lastError;
  
  double _scale = 1.0;
  double get scale => _scale;
  
  double _opacity = 1.0;
  double get opacity => _opacity;
  
  int _positionX = 0;
  int _positionY = 100;
  int get positionX => _positionX;
  int get positionY => _positionY;
  
  final List<InteractionHandler> _interactionHandlers = [];
  
  // ============================================================================
  // ============================================================================
  
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
      
      await _bridge.initialize();
      
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
  
  @override
  void dispose() {
    _bridge.removeEventHandler(_handleNativeEvent);
    _interactionHandlers.clear();
    _bridge.dispose();
    super.dispose();
  }
  
  // ============================================================================
  // ============================================================================
  
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
  
  Future<bool> hide() async {
    if (_state != Live2DOverlayState.visible) {
      return true;
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
  
  Future<bool> toggle() async {
    if (_state == Live2DOverlayState.visible) {
      return hide();
    } else {
      return show();
    }
  }
  
  bool get isVisible => _state == Live2DOverlayState.visible;
  
  // ============================================================================
  // ============================================================================
  
  /// 
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
  // ============================================================================
  
  /// 
  Future<bool> playMotion(String motionName, {bool loop = false}) async {
    final priority = loop ? 1 : 2;
    return _bridge.playMotion(motionName, 0, priority: priority);
  }
  
  Future<bool> setExpression(String expressionName) async {
    return _bridge.setExpression(expressionName);
  }
  
  Future<bool> setRandomExpression() async {
    return _bridge.setRandomExpression();
  }
  
  // ============================================================================
  // ============================================================================
  
  Future<bool> setScale(double value) async {
    final result = await _bridge.setScale(value);
    if (result) {
      _scale = value;
      notifyListeners();
    }
    return result;
  }
  
  Future<bool> setOpacity(double value) async {
    final result = await _bridge.setOpacity(value);
    if (result) {
      _opacity = value;
      notifyListeners();
    }
    return result;
  }
  
  Future<bool> setPosition(double x, double y) async {
    final result = await _bridge.setPosition(x, y);
    if (result) {
      _positionX = x.toInt();
      _positionY = y.toInt();
      notifyListeners();
    }
    return result;
  }
  
  Future<bool> setSize(int width, int height) async {
    return _bridge.setSize(width, height);
  }
  
  // ============================================================================
  // ============================================================================
  
  Future<bool> setEyeBlink(bool enabled) async {
    return _bridge.setEyeBlink(enabled);
  }
  
  Future<bool> setBreathing(bool enabled) async {
    return _bridge.setBreathing(enabled);
  }
  
  Future<bool> setLookAt(bool enabled) async {
    return _bridge.setLookAt(enabled);
  }
  
  // ============================================================================
  // ============================================================================
  
  /// 
  Future<bool> sendSignal(String signal, {Map<String, dynamic>? data}) async {
    return _bridge.sendSignal(signal, data: data);
  }
  
  // ============================================================================
  // ============================================================================
  
  void addInteractionHandler(InteractionHandler handler) {
    _interactionHandlers.add(handler);
  }
  
  void removeInteractionHandler(InteractionHandler handler) {
    _interactionHandlers.remove(handler);
  }
  
  void _handleNativeEvent(InteractionEvent event) {
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
    
    for (final handler in _interactionHandlers) {
      try {
        handler(event);
      } catch (e) {
        live2dLog.error(_tag, '핸들러 오류', error: e);
      }
    }
  }
  
  // ============================================================================
  // ============================================================================
  
  void _setState(Live2DOverlayState newState) {
    if (_state != newState) {
      _state = newState;
      notifyListeners();
    }
  }
}

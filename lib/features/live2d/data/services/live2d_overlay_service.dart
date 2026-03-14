// ============================================================================
// ============================================================================
// 
// ============================================================================

import 'dart:async';
import 'package:permission_handler/permission_handler.dart';
import '../../../../services/global_runtime_registry.dart';
import 'live2d_log_service.dart';
import 'live2d_native_bridge.dart';

/// 
class Live2DOverlayService {
  static final Live2DOverlayService _instance = Live2DOverlayService._internal();
  factory Live2DOverlayService() => _instance;
  Live2DOverlayService._internal();

  static const String _tag = 'Overlay';

  final Live2DNativeBridge _bridge = Live2DNativeBridge();

  static const int _baseWidth = 300;
  static const int _baseHeight = 400;

  bool _isOverlayVisible = false;
  double _scale = 1.0;
  double _opacity = 1.0;
  String? _currentModelPath;

  // === Getter ===
  // WHY: isOverlayVisible returns cached state for synchronous access.
  // For critical decisions, use syncOverlayState() to verify with native.
  bool get isOverlayVisible => _isOverlayVisible;
  double get scale => _scale;
  double get opacity => _opacity;
  String? get currentModelPath => _currentModelPath;

  int get overlayWidth => (_baseWidth * _scale).toInt();

  int get overlayHeight => (_baseHeight * _scale).toInt();

  // ============================================================================
  // ============================================================================

  /// 
  Future<bool> syncOverlayState() async {
    try {
      final nativeState = await _bridge.isOverlayVisible();
      if (_isOverlayVisible != nativeState) {
        live2dLog.warning(
          _tag,
          '상태 불일치 감지',
          details: 'local=$_isOverlayVisible, native=$nativeState',
        );
        _isOverlayVisible = nativeState;
      }
      return nativeState;
    } catch (e) {
      live2dLog.error(_tag, '상태 동기화 실패', error: e);
      return _isOverlayVisible;
    }
  }

  Future<void> initialize() async {
    if (!_bridge.isInitialized) {
      await _bridge.initialize();
    }
    
    _bridge.setStateSyncCallback(_onStateSyncFromNative);
    
    await syncOverlayState();
    
    live2dLog.info(_tag, 'Live2D Overlay Service 초기화됨');
  }
  
  /// 
  void _onStateSyncFromNative(Map<String, dynamic> data) {
    final isRunning = data['isRunning'] as bool? ?? false;
    final modelLoaded = data['modelLoaded'] as bool? ?? false;
    
    if (_isOverlayVisible != isRunning) {
      live2dLog.warning(
        _tag,
        '주기적 동기화에서 상태 불일치 감지',
        details: 'local=$_isOverlayVisible, native=$isRunning, model=$modelLoaded',
      );
      _isOverlayVisible = isRunning;
    }
    
  }

  // ============================================================================
  // ============================================================================

  Future<bool> hasOverlayPermission() async {
    try {
      final hasPermission = await _bridge.hasOverlayPermission();
      live2dLog.debug(_tag, '오버레이 권한 확인', details: hasPermission ? '허용됨' : '거부됨');
      return hasPermission;
    } catch (e) {
      live2dLog.error(_tag, '오버레이 권한 확인 실패', error: e);
      return false;
    }
  }

  Future<bool> requestOverlayPermission() async {
    try {
      live2dLog.info(_tag, '오버레이 권한 요청 중...');
      final granted = await _bridge.requestOverlayPermission();
      
      live2dLog.info(
        _tag,
        '오버레이 권한 요청 결과',
        details: granted ? '요청 전송됨' : '실패',
      );
      
      return granted;
    } catch (e) {
      live2dLog.error(_tag, '오버레이 권한 요청 실패', error: e);
      return false;
    }
  }

  Future<bool> hasStoragePermission() async {
    try {
      final hasPermission = await _bridge.hasStoragePermission();
      return hasPermission;
    } catch (e) {
      live2dLog.error(_tag, '저장소 권한 확인 실패', error: e);
      return false;
    }
  }

  Future<bool> requestStoragePermission() async {
    try {
      live2dLog.info(_tag, '저장소 권한 요청 중...');
      final granted = await _bridge.requestStoragePermission();
      
      live2dLog.info(
        _tag,
        '저장소 권한 요청 결과',
        details: granted ? '요청 전송됨' : '실패',
      );
      
      return granted;
    } catch (e) {
      live2dLog.error(_tag, '저장소 권한 요청 실패', error: e);
      return false;
    }
  }

  Future<Map<String, bool>> checkAllPermissions() async {
    return {
      'overlay': await hasOverlayPermission(),
      'storage': await hasStoragePermission(),
    };
  }

  // ============================================================================
  // ============================================================================

  Future<void> setScale(double newScale) async {
    _scale = newScale.clamp(0.5, 2.0);
    live2dLog.debug(_tag, '크기 배율 설정', details: _scale.toString());

    await _bridge.setScale(_scale);
    
    if (_isOverlayVisible) {
      await _bridge.setSize(overlayWidth, overlayHeight);
    }
  }

  Future<void> setOpacity(double newOpacity) async {
    _opacity = newOpacity.clamp(0.3, 1.0);
    live2dLog.debug(_tag, '투명도 설정', details: _opacity.toString());
    
    await _bridge.setOpacity(_opacity);
  }

  Future<void> setPosition(int x, int y) async {
    try {
      await _bridge.setPosition(x.toDouble(), y.toDouble());
      live2dLog.debug(_tag, '위치 변경', details: '($x, $y)');
    } catch (e) {
      live2dLog.error(_tag, '위치 변경 실패', error: e);
    }
  }

  Future<void> setSize(int width, int height) async {
    try {
      await _bridge.setSize(width, height);
      live2dLog.debug(_tag, '크기 변경', details: '${width}x$height');
    } catch (e) {
      live2dLog.error(_tag, '크기 변경 실패', error: e);
    }
  }

  // ============================================================================
  // ============================================================================

  Future<bool> showOverlay() async {
    if (!GlobalRuntimeRegistry.instance.isEnabled) {
      live2dLog.debug(_tag, 'Master OFF: showOverlay skipped');
      return false;
    }

    if (await Permission.notification.isDenied) {
      live2dLog.info(_tag, '알림 권한 요청 중...');
      final status = await Permission.notification.request();
      if (!status.isGranted) {
        live2dLog.warning(_tag, '알림 권한 거부됨 - 서비스가 강제 종료될 수 있음');
      }
    }
    
    if (!await hasOverlayPermission()) {
      live2dLog.warning(_tag, '오버레이 권한 없음');
      return false;
    }

    try {
      final isActive = await _bridge.isOverlayVisible();
      if (isActive) {
        live2dLog.info(_tag, '오버레이가 이미 표시 중');
        _isOverlayVisible = true;
        return true;
      }

      final result = await _bridge.showOverlay();
      
      if (result) {
        _isOverlayVisible = true;
        live2dLog.info(
          _tag,
          '오버레이 표시됨',
          details: '${overlayWidth}x$overlayHeight',
        );

        await _bridge.setScale(_scale);
        await _bridge.setOpacity(_opacity);
        await _bridge.setSize(overlayWidth, overlayHeight);

        if (_currentModelPath != null) {
          await Future.delayed(const Duration(milliseconds: 500));
          await loadModel(_currentModelPath!);
        }
      }

      return result;
    } catch (e, stack) {
      live2dLog.error(_tag, '오버레이 표시 실패', error: e, stackTrace: stack);
      return false;
    }
  }

  Future<bool> hideOverlay() async {
    try {
      final isActive = await _bridge.isOverlayVisible();
      if (!isActive) {
        live2dLog.info(_tag, '오버레이가 표시되어 있지 않음');
        _isOverlayVisible = false;
        return true;
      }

      final result = await _bridge.hideOverlay();
      if (result) {
        _isOverlayVisible = false;
        live2dLog.info(_tag, '오버레이 숨김');
      }
      return result;
    } catch (e) {
      live2dLog.error(_tag, '오버레이 숨기기 실패', error: e);
      return false;
    }
  }

  Future<bool> suspendOverlayForCapture() async {
    try {
      final isActive = await _bridge.isOverlayVisible();
      if (!isActive) {
        _isOverlayVisible = false;
        return true;
      }

      final result = await _bridge.suspendOverlayForCapture();
      if (result) {
        _isOverlayVisible = false;
        live2dLog.info(_tag, '오버레이 캡처 일시 숨김');
      }
      return result;
    } catch (e) {
      live2dLog.error(_tag, '오버레이 캡처 일시 숨김 실패', error: e);
      return false;
    }
  }

  Future<bool> toggleOverlay() async {
    if (_isOverlayVisible) {
      return await hideOverlay();
    } else {
      return await showOverlay();
    }
  }

  Future<bool> checkOverlayStatus() async {
    try {
      final isActive = await _bridge.isOverlayVisible();
      _isOverlayVisible = isActive;
      return isActive;
    } catch (e) {
      return false;
    }
  }

  // ============================================================================
  // ============================================================================

  Future<bool> loadModel(String modelPath) async {
    _currentModelPath = modelPath;
    
    try {
      live2dLog.info(_tag, '모델 로드', details: modelPath);
      final result = await _bridge.loadModel(modelPath);
      
      if (result) {
        live2dLog.info(_tag, '모델 로드 성공');
      } else {
        live2dLog.warning(_tag, '모델 로드 실패');
      }
      
      return result;
    } catch (e) {
      live2dLog.error(_tag, '모델 로드 오류', error: e);
      return false;
    }
  }

  Future<bool> unloadModel() async {
    _currentModelPath = null;
    
    try {
      live2dLog.info(_tag, '모델 언로드');
      return await _bridge.unloadModel();
    } catch (e) {
      live2dLog.error(_tag, '모델 언로드 오류', error: e);
      return false;
    }
  }

  Future<bool> playMotion(String group, int index, {int priority = 2}) async {
    try {
      return await _bridge.playMotion(group, index, priority: priority);
    } catch (e) {
      live2dLog.error(_tag, '모션 재생 오류', error: e);
      return false;
    }
  }

  Future<bool> setExpression(String expressionId) async {
    try {
      return await _bridge.setExpression(expressionId);
    } catch (e) {
      live2dLog.error(_tag, '표정 설정 오류', error: e);
      return false;
    }
  }

  Future<bool> setRandomExpression() async {
    try {
      return await _bridge.setRandomExpression();
    } catch (e) {
      live2dLog.error(_tag, '랜덤 표정 설정 오류', error: e);
      return false;
    }
  }

  // ============================================================================
  // ============================================================================

  Future<bool> setEyeBlink(bool enabled) async {
    return await _bridge.setEyeBlink(enabled);
  }

  Future<bool> setBreathing(bool enabled) async {
    return await _bridge.setBreathing(enabled);
  }

  Future<bool> setLookAt(bool enabled) async {
    return await _bridge.setLookAt(enabled);
  }

  // ============================================================================
  // ============================================================================

  Future<bool> setTargetFps(int fps) async {
    return await _bridge.setTargetFps(fps);
  }

  Future<bool> setLowPowerMode(bool enabled) async {
    return await _bridge.setLowPowerMode(enabled);
  }

  // ============================================================================
  // ============================================================================

  Future<List<String>> getMotionGroups() async {
    return await _bridge.getMotionGroups();
  }

  Future<List<String>> getExpressions() async {
    return await _bridge.getExpressions();
  }

  Future<Map<String, dynamic>> getModelInfo() async {
    return await _bridge.getModelInfo();
  }

  Future<Map<String, dynamic>> analyzeModel(String modelPath) async {
    return await _bridge.analyzeModel(modelPath);
  }

  // ============================================================================
  // ============================================================================

  Future<bool> sendSignal(String signalName, {Map<String, dynamic>? data}) async {
    return await _bridge.sendSignal(signalName, data: data);
  }

  Future<void> dispose() async {
    if (_isOverlayVisible) {
      await hideOverlay();
    }
    _currentModelPath = null;
    live2dLog.info(_tag, 'Live2D Overlay Service 정리됨');
  }
}

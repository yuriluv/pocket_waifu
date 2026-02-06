// ============================================================================
// Live2D 오버레이 서비스 (Live2D Overlay Service)
// ============================================================================
// Native OpenGL 기반 Live2D 오버레이를 관리합니다.
// Live2DNativeBridge를 통해 Android Native 모듈과 통신합니다.
// 
// 마이그레이션: flutter_overlay_window → Native OpenGL (Phase 1-6 완료)
// ============================================================================

import 'dart:async';
import 'package:permission_handler/permission_handler.dart';
import 'live2d_log_service.dart';
import 'live2d_native_bridge.dart';

/// 오버레이 윈도우를 관리하는 싱글톤 서비스
/// 
/// Native OpenGL 기반 Live2D 오버레이의 고수준 인터페이스를 제공합니다.
class Live2DOverlayService {
  // === 싱글톤 패턴 ===
  static final Live2DOverlayService _instance = Live2DOverlayService._internal();
  factory Live2DOverlayService() => _instance;
  Live2DOverlayService._internal();

  static const String _tag = 'Overlay';

  // Native Bridge 인스턴스
  final Live2DNativeBridge _bridge = Live2DNativeBridge();

  // === 기본 크기 설정 ===
  static const int _baseWidth = 300;
  static const int _baseHeight = 400;

  // === 상태 변수 ===
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

  /// 현재 오버레이 너비
  int get overlayWidth => (_baseWidth * _scale).toInt();

  /// 현재 오버레이 높이
  int get overlayHeight => (_baseHeight * _scale).toInt();

  // ============================================================================
  // 상태 동기화 (State Synchronization)
  // ============================================================================

  /// 네이티브와 상태 동기화 후 실제 상태 반환
  /// 
  /// WHY: Flutter의 _isOverlayVisible과 Native의 isRunning이 
  /// 프로세스 재시작이나 권한 취소로 인해 불일치할 수 있습니다.
  /// 이 메서드는 Native에서 실제 상태를 가져와 로컬 상태를 수정합니다.
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

  /// 서비스 초기화
  Future<void> initialize() async {
    if (!_bridge.isInitialized) {
      await _bridge.initialize();
    }
    
    // 상태 동기화 콜백 등록 - Native가 주기적으로 상태를 브로드캐스트할 때 호출됨
    _bridge.setStateSyncCallback(_onStateSyncFromNative);
    
    // 초기화 시 Native 상태와 동기화
    await syncOverlayState();
    
    live2dLog.info(_tag, 'Live2D Overlay Service 초기화됨');
  }
  
  /// Native 상태 동기화 이벤트 핸들러
  /// 
  /// WHY: Native에서 주기적으로 상태를 브로드캐스트합니다.
  /// 이를 통해 권한 취소나 예기치 않은 서비스 종료를 감지할 수 있습니다.
  void _onStateSyncFromNative(Map<String, dynamic> data) {
    final isRunning = data['isRunning'] as bool? ?? false;
    final modelLoaded = data['modelLoaded'] as bool? ?? false;
    
    // 상태 불일치 감지 및 수정
    if (_isOverlayVisible != isRunning) {
      live2dLog.warning(
        _tag,
        '주기적 동기화에서 상태 불일치 감지',
        details: 'local=$_isOverlayVisible, native=$isRunning, model=$modelLoaded',
      );
      _isOverlayVisible = isRunning;
    }
    
    // 모델 상태도 동기화 (필요시)
    if (!isRunning && _currentModelPath != null) {
      // Native가 종료되었는데 우리는 모델이 있다고 생각하면 초기화
      _currentModelPath = null;
    }
  }

  // ============================================================================
  // 권한 관리
  // ============================================================================

  /// 오버레이 권한이 있는지 확인합니다
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

  /// 오버레이 권한을 요청합니다
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

  /// 저장소 권한이 있는지 확인합니다
  Future<bool> hasStoragePermission() async {
    try {
      final hasPermission = await _bridge.hasStoragePermission();
      return hasPermission;
    } catch (e) {
      live2dLog.error(_tag, '저장소 권한 확인 실패', error: e);
      return false;
    }
  }

  /// 저장소 권한을 요청합니다
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

  /// 모든 필요한 권한 확인
  Future<Map<String, bool>> checkAllPermissions() async {
    return {
      'overlay': await hasOverlayPermission(),
      'storage': await hasStoragePermission(),
    };
  }

  // ============================================================================
  // 디스플레이 설정
  // ============================================================================

  /// 크기 배율 설정
  Future<void> setScale(double newScale) async {
    _scale = newScale.clamp(0.5, 2.0);
    live2dLog.debug(_tag, '크기 배율 설정', details: _scale.toString());

    await _bridge.setScale(_scale);
    
    // 오버레이 창 크기도 업데이트
    if (_isOverlayVisible) {
      await _bridge.setSize(overlayWidth, overlayHeight);
    }
  }

  /// 투명도 설정
  Future<void> setOpacity(double newOpacity) async {
    _opacity = newOpacity.clamp(0.3, 1.0);
    live2dLog.debug(_tag, '투명도 설정', details: _opacity.toString());
    
    await _bridge.setOpacity(_opacity);
  }

  /// 위치 설정
  Future<void> setPosition(int x, int y) async {
    try {
      await _bridge.setPosition(x.toDouble(), y.toDouble());
      live2dLog.debug(_tag, '위치 변경', details: '($x, $y)');
    } catch (e) {
      live2dLog.error(_tag, '위치 변경 실패', error: e);
    }
  }

  /// 크기 설정
  Future<void> setSize(int width, int height) async {
    try {
      await _bridge.setSize(width, height);
      live2dLog.debug(_tag, '크기 변경', details: '${width}x$height');
    } catch (e) {
      live2dLog.error(_tag, '크기 변경 실패', error: e);
    }
  }

  // ============================================================================
  // 오버레이 제어
  // ============================================================================

  /// 오버레이를 표시합니다
  Future<bool> showOverlay() async {
    // 알림 권한 확인 (Android 13+ 포그라운드 서비스 알림에 필수)
    if (await Permission.notification.isDenied) {
      live2dLog.info(_tag, '알림 권한 요청 중...');
      final status = await Permission.notification.request();
      if (!status.isGranted) {
        live2dLog.warning(_tag, '알림 권한 거부됨 - 서비스가 강제 종료될 수 있음');
      }
    }
    
    // 오버레이 권한 확인
    if (!await hasOverlayPermission()) {
      live2dLog.warning(_tag, '오버레이 권한 없음');
      return false;
    }

    try {
      // 이미 표시 중인지 확인
      final isActive = await _bridge.isOverlayVisible();
      if (isActive) {
        live2dLog.info(_tag, '오버레이가 이미 표시 중');
        _isOverlayVisible = true;
        return true;
      }

      // 오버레이 표시
      final result = await _bridge.showOverlay();
      
      if (result) {
        _isOverlayVisible = true;
        live2dLog.info(
          _tag,
          '오버레이 표시됨',
          details: '${overlayWidth}x$overlayHeight',
        );

        // 설정 적용
        await _bridge.setScale(_scale);
        await _bridge.setOpacity(_opacity);
        await _bridge.setSize(overlayWidth, overlayHeight);

        // 현재 모델이 있으면 로드
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

  /// 오버레이를 숨깁니다
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

  /// 오버레이 표시 상태 토글
  Future<bool> toggleOverlay() async {
    if (_isOverlayVisible) {
      return await hideOverlay();
    } else {
      return await showOverlay();
    }
  }

  /// 현재 오버레이 활성 상태 확인
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
  // 모델 제어
  // ============================================================================

  /// 모델 로드
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

  /// 모델 언로드
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

  /// 모션 재생
  Future<bool> playMotion(String group, int index, {int priority = 2}) async {
    try {
      return await _bridge.playMotion(group, index, priority: priority);
    } catch (e) {
      live2dLog.error(_tag, '모션 재생 오류', error: e);
      return false;
    }
  }

  /// 표정 설정
  Future<bool> setExpression(String expressionId) async {
    try {
      return await _bridge.setExpression(expressionId);
    } catch (e) {
      live2dLog.error(_tag, '표정 설정 오류', error: e);
      return false;
    }
  }

  /// 랜덤 표정 설정
  Future<bool> setRandomExpression() async {
    try {
      return await _bridge.setRandomExpression();
    } catch (e) {
      live2dLog.error(_tag, '랜덤 표정 설정 오류', error: e);
      return false;
    }
  }

  // ============================================================================
  // 자동 동작 설정
  // ============================================================================

  /// 눈 깜빡임 설정
  Future<bool> setEyeBlink(bool enabled) async {
    return await _bridge.setEyeBlink(enabled);
  }

  /// 호흡 설정
  Future<bool> setBreathing(bool enabled) async {
    return await _bridge.setBreathing(enabled);
  }

  /// 시선 추적 설정
  Future<bool> setLookAt(bool enabled) async {
    return await _bridge.setLookAt(enabled);
  }

  // ============================================================================
  // 렌더링 설정
  // ============================================================================

  /// 목표 FPS 설정
  Future<bool> setTargetFps(int fps) async {
    return await _bridge.setTargetFps(fps);
  }

  /// 저전력 모드 설정
  Future<bool> setLowPowerMode(bool enabled) async {
    return await _bridge.setLowPowerMode(enabled);
  }

  // ============================================================================
  // 모델 정보 조회
  // ============================================================================

  /// 모션 그룹 목록
  Future<List<String>> getMotionGroups() async {
    return await _bridge.getMotionGroups();
  }

  /// 표정 목록
  Future<List<String>> getExpressions() async {
    return await _bridge.getExpressions();
  }

  /// 모델 상세 정보
  Future<Map<String, dynamic>> getModelInfo() async {
    return await _bridge.getModelInfo();
  }

  /// 모델 분석 (로드 없이 정보만 추출)
  Future<Map<String, dynamic>> analyzeModel(String modelPath) async {
    return await _bridge.analyzeModel(modelPath);
  }

  // ============================================================================
  // 신호 전송
  // ============================================================================

  /// 외부 신호 전송
  Future<bool> sendSignal(String signalName, {Map<String, dynamic>? data}) async {
    return await _bridge.sendSignal(signalName, data: data);
  }

  // ============================================================================
  // 리소스 정리
  // ============================================================================

  /// 리소스 정리
  Future<void> dispose() async {
    if (_isOverlayVisible) {
      await hideOverlay();
    }
    _currentModelPath = null;
    live2dLog.info(_tag, 'Live2D Overlay Service 정리됨');
  }
}

// ============================================================================
// Live2D 오버레이 서비스 (Live2D Overlay Service)
// ============================================================================
// Android Foreground Service로 오버레이를 관리합니다.
// flutter_overlay_window 패키지를 사용합니다.
// ============================================================================

import 'dart:async';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:permission_handler/permission_handler.dart';
import 'live2d_log_service.dart';

/// 오버레이 윈도우를 관리하는 싱글톤 서비스
class Live2DOverlayService {
  // === 싱글톤 패턴 ===
  static final Live2DOverlayService _instance = Live2DOverlayService._internal();
  factory Live2DOverlayService() => _instance;
  Live2DOverlayService._internal();

  static const String _tag = 'Overlay';

  // === 기본 크기 설정 ===
  static const int _baseWidth = 300;
  static const int _baseHeight = 400;

  // === 상태 변수 ===
  bool _isOverlayVisible = false;
  double _scale = 1.0;
  double _opacity = 1.0;
  String? _currentModelUrl;

  // === Getter ===
  bool get isOverlayVisible => _isOverlayVisible;
  double get scale => _scale;
  double get opacity => _opacity;
  String? get currentModelUrl => _currentModelUrl;

  /// 현재 오버레이 너비
  int get overlayWidth => (_baseWidth * _scale).toInt();

  /// 현재 오버레이 높이
  int get overlayHeight => (_baseHeight * _scale).toInt();

  /// 오버레이 권한이 있는지 확인합니다
  Future<bool> hasOverlayPermission() async {
    try {
      final status = await Permission.systemAlertWindow.status;
      final hasPermission = status.isGranted;
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
      final status = await Permission.systemAlertWindow.request();
      final granted = status.isGranted;
      
      live2dLog.info(
        _tag,
        '오버레이 권한 요청 결과',
        details: granted ? '허용됨' : '거부됨',
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
      final status = await Permission.manageExternalStorage.status;
      return status.isGranted;
    } catch (e) {
      live2dLog.error(_tag, '저장소 권한 확인 실패', error: e);
      return false;
    }
  }

  /// 저장소 권한을 요청합니다
  Future<bool> requestStoragePermission() async {
    try {
      live2dLog.info(_tag, '저장소 권한 요청 중...');
      final status = await Permission.manageExternalStorage.request();
      final granted = status.isGranted;
      
      live2dLog.info(
        _tag,
        '저장소 권한 요청 결과',
        details: granted ? '허용됨' : '거부됨',
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

  /// 크기 배율 설정
  void setScale(double newScale) {
    _scale = newScale.clamp(0.5, 2.0);
    live2dLog.debug(_tag, '크기 배율 설정', details: _scale.toString());

    // 오버레이가 이미 표시 중이면 크기 업데이트
    if (_isOverlayVisible) {
      _updateOverlaySize();
    }
  }

  /// 투명도 설정
  void setOpacity(double newOpacity) {
    _opacity = newOpacity.clamp(0.3, 1.0);
    live2dLog.debug(_tag, '투명도 설정', details: _opacity.toString());
  }

  /// 오버레이 크기 업데이트
  Future<void> _updateOverlaySize() async {
    try {
      await FlutterOverlayWindow.resizeOverlay(
        overlayWidth,
        overlayHeight,
        true, // enableDrag
      );
      live2dLog.debug(
        _tag,
        '오버레이 크기 업데이트',
        details: '${overlayWidth}x$overlayHeight',
      );
    } catch (e) {
      live2dLog.error(_tag, '오버레이 크기 업데이트 실패', error: e);
    }
  }

  /// 오버레이를 표시합니다
  Future<bool> showOverlay() async {
    // 권한 확인
    if (!await hasOverlayPermission()) {
      live2dLog.warning(_tag, '오버레이 권한 없음');
      return false;
    }

    try {
      // 이미 표시 중인지 확인
      final isActive = await FlutterOverlayWindow.isActive();
      if (isActive) {
        live2dLog.info(_tag, '오버레이가 이미 표시 중');
        _isOverlayVisible = true;
        return true;
      }

      // 오버레이 설정
      await FlutterOverlayWindow.showOverlay(
        enableDrag: true,
        overlayTitle: "Live2D Viewer",
        overlayContent: "Live2D 캐릭터 오버레이",
        flag: OverlayFlag.defaultFlag,
        visibility: NotificationVisibility.visibilityPublic,
        positionGravity: PositionGravity.auto,
        height: overlayHeight,
        width: overlayWidth,
        startPosition: const OverlayPosition(0, 100),
      );

      _isOverlayVisible = true;
      live2dLog.info(
        _tag,
        '오버레이 표시됨',
        details: '${overlayWidth}x$overlayHeight',
      );

      // 현재 모델이 있으면 로드 (오버레이 초기화 대기)
      if (_currentModelUrl != null) {
        // 더 긴 딜레이 - 오버레이 WebView 초기화 대기
        await Future.delayed(const Duration(milliseconds: 1000));
        await sendModelUrl(_currentModelUrl!);
        // 재전송 (안정성 향상)
        await Future.delayed(const Duration(milliseconds: 500));
        await sendModelUrl(_currentModelUrl!);
      }

      return true;
    } catch (e, stack) {
      live2dLog.error(_tag, '오버레이 표시 실패', error: e, stackTrace: stack);
      return false;
    }
  }

  /// 오버레이를 숨깁니다
  Future<bool> hideOverlay() async {
    try {
      final isActive = await FlutterOverlayWindow.isActive();
      if (!isActive) {
        live2dLog.info(_tag, '오버레이가 표시되어 있지 않음');
        _isOverlayVisible = false;
        return true;
      }

      await FlutterOverlayWindow.closeOverlay();
      _isOverlayVisible = false;
      live2dLog.info(_tag, '오버레이 숨김');
      return true;
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

  /// 오버레이에 모델 URL 전송
  Future<void> sendModelUrl(String url) async {
    _currentModelUrl = url;
    
    try {
      live2dLog.info(_tag, '모델 URL 전송', details: url);
      
      // URL을 직접 문자열로 전송 (가장 안정적)
      await FlutterOverlayWindow.shareData(url);
      live2dLog.debug(_tag, '데이터 전송 완료 (URL 직접)');
    } catch (e) {
      live2dLog.error(_tag, '모델 URL 전송 실패', error: e);
    }
  }

  /// 오버레이 위치 변경
  Future<void> setPosition(double x, double y) async {
    try {
      await FlutterOverlayWindow.moveOverlay(OverlayPosition(x, y));
      live2dLog.debug(_tag, '위치 변경', details: '($x, $y)');
    } catch (e) {
      live2dLog.error(_tag, '위치 변경 실패', error: e);
    }
  }

  /// 현재 오버레이 활성 상태 확인
  Future<bool> checkOverlayStatus() async {
    try {
      final isActive = await FlutterOverlayWindow.isActive();
      _isOverlayVisible = isActive;
      return isActive;
    } catch (e) {
      return false;
    }
  }

  /// 리소스 정리
  Future<void> dispose() async {
    if (_isOverlayVisible) {
      await hideOverlay();
    }
    _currentModelUrl = null;
  }
}

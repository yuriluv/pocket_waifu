// ============================================================================
// 오버레이 서비스 (Overlay Service)
// ============================================================================
// 이 파일은 Flutter Overlay Window를 관리합니다.
// Live2D WebView를 시스템 오버레이로 표시합니다.
// 
// 주요 기능:
// - 오버레이 윈도우 표시/숨김
// - 윈도우 크기 조절
// - 권한 확인 및 요청
// ============================================================================

import 'package:flutter/foundation.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:permission_handler/permission_handler.dart';

/// 오버레이 윈도우를 관리하는 싱글톤 서비스
class OverlayService {
  // === 싱글톤 패턴 ===
  static final OverlayService _instance = OverlayService._internal();
  factory OverlayService() => _instance;
  OverlayService._internal();

  // === 기본 크기 설정 ===
  // 기본 오버레이 크기 (픽셀)
  static const int _baseWidth = 300;
  static const int _baseHeight = 400;

  // === 상태 변수 ===
  bool _isOverlayVisible = false;
  double _sizeMultiplier = 1.0;

  // === Getter ===
  bool get isOverlayVisible => _isOverlayVisible;
  double get sizeMultiplier => _sizeMultiplier;

  /// 현재 오버레이 너비
  int get overlayWidth => (_baseWidth * _sizeMultiplier).toInt();
  
  /// 현재 오버레이 높이
  int get overlayHeight => (_baseHeight * _sizeMultiplier).toInt();

  /// 오버레이 권한이 있는지 확인합니다
  Future<bool> hasOverlayPermission() async {
    try {
      final status = await Permission.systemAlertWindow.status;
      return status.isGranted;
    } catch (e) {
      debugPrint('[Overlay] 권한 확인 실패: $e');
      return false;
    }
  }

  /// 오버레이 권한을 요청합니다
  Future<bool> requestOverlayPermission() async {
    try {
      final status = await Permission.systemAlertWindow.request();
      debugPrint('[Overlay] 권한 요청 결과: $status');
      return status.isGranted;
    } catch (e) {
      debugPrint('[Overlay] 권한 요청 실패: $e');
      return false;
    }
  }

  /// 저장소 권한이 있는지 확인합니다
  Future<bool> hasStoragePermission() async {
    try {
      final status = await Permission.manageExternalStorage.status;
      return status.isGranted;
    } catch (e) {
      debugPrint('[Overlay] 저장소 권한 확인 실패: $e');
      return false;
    }
  }

  /// 저장소 권한을 요청합니다
  Future<bool> requestStoragePermission() async {
    try {
      final status = await Permission.manageExternalStorage.request();
      debugPrint('[Overlay] 저장소 권한 요청 결과: $status');
      return status.isGranted;
    } catch (e) {
      debugPrint('[Overlay] 저장소 권한 요청 실패: $e');
      return false;
    }
  }

  /// 모든 필요한 권한이 있는지 확인합니다
  Future<Map<String, bool>> checkAllPermissions() async {
    return {
      'overlay': await hasOverlayPermission(),
      'storage': await hasStoragePermission(),
    };
  }

  /// 오버레이 크기 배율을 설정합니다
  void setSizeMultiplier(double multiplier) {
    _sizeMultiplier = multiplier.clamp(0.5, 3.0);
    debugPrint('[Overlay] 크기 배율 설정: $_sizeMultiplier');
    
    // 오버레이가 이미 표시 중이면 크기 업데이트
    if (_isOverlayVisible) {
      _updateOverlaySize();
    }
  }

  /// 오버레이 크기를 업데이트합니다
  Future<void> _updateOverlaySize() async {
    try {
      await FlutterOverlayWindow.resizeOverlay(
        overlayWidth,
        overlayHeight,
        true,  // enableDrag
      );
      debugPrint('[Overlay] 크기 업데이트: ${overlayWidth}x$overlayHeight');
    } catch (e) {
      debugPrint('[Overlay] 크기 업데이트 실패: $e');
    }
  }

  /// 오버레이를 표시합니다
  Future<bool> showOverlay() async {
    // 권한 확인
    if (!await hasOverlayPermission()) {
      debugPrint('[Overlay] 오버레이 권한이 없습니다.');
      return false;
    }

    try {
      // 이미 표시 중인지 확인
      final isActive = await FlutterOverlayWindow.isActive();
      if (isActive) {
        debugPrint('[Overlay] 이미 표시 중입니다.');
        _isOverlayVisible = true;
        return true;
      }

      // 오버레이 설정
      await FlutterOverlayWindow.showOverlay(
        enableDrag: true,           // 드래그로 이동 가능
        overlayTitle: "Pocket Waifu Live2D",
        overlayContent: "Live2D 캐릭터 오버레이",
        flag: OverlayFlag.defaultFlag,
        visibility: NotificationVisibility.visibilityPublic,
        positionGravity: PositionGravity.auto,
        height: overlayHeight,
        width: overlayWidth,
        startPosition: const OverlayPosition(0, 100),
      );

      _isOverlayVisible = true;
      debugPrint('[Overlay] 오버레이 표시됨: ${overlayWidth}x$overlayHeight');
      return true;
    } catch (e) {
      debugPrint('[Overlay] 오버레이 표시 실패: $e');
      return false;
    }
  }

  /// 오버레이를 숨깁니다
  Future<bool> hideOverlay() async {
    try {
      final isActive = await FlutterOverlayWindow.isActive();
      if (!isActive) {
        debugPrint('[Overlay] 오버레이가 표시되어 있지 않습니다.');
        _isOverlayVisible = false;
        return true;
      }

      await FlutterOverlayWindow.closeOverlay();
      _isOverlayVisible = false;
      debugPrint('[Overlay] 오버레이 숨겨짐');
      return true;
    } catch (e) {
      debugPrint('[Overlay] 오버레이 숨기기 실패: $e');
      return false;
    }
  }

  /// 오버레이 표시 상태를 토글합니다
  Future<bool> toggleOverlay() async {
    if (_isOverlayVisible) {
      return await hideOverlay();
    } else {
      return await showOverlay();
    }
  }

  /// 오버레이 위치를 변경합니다
  Future<void> setPosition(double x, double y) async {
    try {
      await FlutterOverlayWindow.moveOverlay(
        OverlayPosition(x, y),
      );
      debugPrint('[Overlay] 위치 변경: ($x, $y)');
    } catch (e) {
      debugPrint('[Overlay] 위치 변경 실패: $e');
    }
  }

  /// 오버레이가 현재 표시 중인지 확인합니다
  Future<bool> isActive() async {
    try {
      return await FlutterOverlayWindow.isActive();
    } catch (e) {
      debugPrint('[Overlay] 활성 상태 확인 실패: $e');
      return false;
    }
  }

  /// 메인 앱에서 오버레이로 데이터를 전송합니다
  Future<void> sendDataToOverlay(Map<String, dynamic> data) async {
    try {
      // 데이터를 JSON 문자열로 변환하여 전송
      final jsonString = data.toString();
      await FlutterOverlayWindow.shareData(jsonString);
      debugPrint('[Overlay] 데이터 전송: $jsonString');
    } catch (e) {
      debugPrint('[Overlay] 데이터 전송 실패: $e');
    }
  }

  /// 오버레이에서 메인 앱으로 데이터를 수신하는 스트림
  Stream<dynamic> get dataStream => FlutterOverlayWindow.overlayListener;
}

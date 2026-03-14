import '../features/live2d/data/services/live2d_overlay_service.dart';
import '../models/message.dart';
import '../models/screen_share_settings.dart';
import 'adb_screen_capture_service.dart';
import 'mini_menu_service.dart';
import 'screen_capture_service.dart';

class UnifiedCaptureService {
  UnifiedCaptureService({
    ScreenCaptureService? mediaProjectionService,
    AdbScreenCaptureService? adbService,
  }) : _mediaProjectionService = mediaProjectionService ?? ScreenCaptureService(),
       _adbService = adbService ?? AdbScreenCaptureService();

  final ScreenCaptureService _mediaProjectionService;
  final AdbScreenCaptureService _adbService;

  Future<ImageAttachment?> capture(ScreenShareSettings settings) async {
    switch (settings.captureMethod) {
      case CaptureMethod.mediaProjection:
        return _mediaProjectionService.capture();
      case CaptureMethod.adb:
        return _captureWithHiddenOverlays(
          maxResolution: settings.maxResolution,
        );
    }
  }

  Future<bool> hasPermission(CaptureMethod method) async {
    switch (method) {
      case CaptureMethod.mediaProjection:
        return _mediaProjectionService.hasPermission();
      case CaptureMethod.adb:
        return _adbService.hasPermission();
    }
  }

  Future<bool> requestPermission(CaptureMethod method) async {
    switch (method) {
      case CaptureMethod.mediaProjection:
        return _mediaProjectionService.requestPermission();
      case CaptureMethod.adb:
        return _adbService.requestPermission();
    }
  }

  Future<Map<String, dynamic>> getAdbConnectionStatus() {
    return _adbService.getConnectionStatus();
  }

  Future<ImageAttachment?> _captureWithHiddenOverlays({
    required int maxResolution,
  }) async {
    final snapshot = await _hideOverlays();
    try {
      await Future<void>.delayed(const Duration(milliseconds: 100));
      return _adbService.capture(maxResolution: maxResolution);
    } finally {
      await _restoreOverlays(snapshot);
    }
  }

  Future<_OverlaySnapshot> _hideOverlays() async {
    final overlayService = Live2DOverlayService();
    final miniMenuService = MiniMenuService.instance;

    final overlayVisibleBefore = await overlayService.checkOverlayStatus();
    final miniMenuOpenBefore = miniMenuService.isMiniMenuOpen;
    final miniMenuSessionId = miniMenuService.lastSessionId;

    if (miniMenuOpenBefore) {
      await miniMenuService.closeMiniMenu();
    }
    if (overlayVisibleBefore) {
      await overlayService.suspendOverlayForCapture();
    }

    return _OverlaySnapshot(
      overlayVisibleBefore: overlayVisibleBefore,
      miniMenuOpenBefore: miniMenuOpenBefore,
      miniMenuSessionId: miniMenuSessionId,
    );
  }

  Future<void> _restoreOverlays(_OverlaySnapshot snapshot) async {
    final overlayService = Live2DOverlayService();
    final miniMenuService = MiniMenuService.instance;

    if (snapshot.overlayVisibleBefore) {
      await overlayService.showOverlay();
      if (snapshot.miniMenuOpenBefore) {
        await miniMenuService.openMiniMenu(sessionId: snapshot.miniMenuSessionId);
      }
    }
  }
}

class _OverlaySnapshot {
  const _OverlaySnapshot({
    required this.overlayVisibleBefore,
    required this.miniMenuOpenBefore,
    required this.miniMenuSessionId,
  });

  final bool overlayVisibleBefore;
  final bool miniMenuOpenBefore;
  final String? miniMenuSessionId;
}

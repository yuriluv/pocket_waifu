import '../features/live2d/data/services/live2d_overlay_service.dart';
import '../models/message.dart';
import '../models/screen_share_settings.dart';
import 'adb_screen_capture_service.dart';
import 'mini_menu_service.dart';

class UnifiedCaptureService {
  UnifiedCaptureService({AdbScreenCaptureService? adbService})
    : _adbService = adbService ?? AdbScreenCaptureService();

  final AdbScreenCaptureService _adbService;

  Future<ImageAttachment?> capture(ScreenShareSettings settings) async {
    switch (settings.screenshotMode) {
      case ScreenshotMode.includeOverlays:
        return _captureWithPreparedOverlays(
          maxResolution: settings.maxResolution,
          suspendOverlay: false,
        );
      case ScreenshotMode.excludeOverlays:
        return _captureWithPreparedOverlays(
          maxResolution: settings.maxResolution,
          suspendOverlay: true,
        );
    }
  }

  Future<bool> hasPermission() async {
    return _adbService.hasPermission();
  }

  Future<bool> requestPermission() async {
    return _adbService.requestPermission();
  }

  Future<Map<String, dynamic>> getAdbConnectionStatus() {
    return _adbService.getConnectionStatus();
  }

  Future<ImageAttachment?> _captureWithPreparedOverlays({
    required int maxResolution,
    required bool suspendOverlay,
  }) async {
    final snapshot = await _prepareOverlaysForCapture(
      suspendOverlay: suspendOverlay,
    );
    try {
      await Future<void>.delayed(const Duration(milliseconds: 100));
      return _adbService.capture(maxResolution: maxResolution);
    } finally {
      await _restoreOverlays(snapshot);
    }
  }

  Future<_OverlaySnapshot> _prepareOverlaysForCapture({
    required bool suspendOverlay,
  }) async {
    final overlayService = Live2DOverlayService();
    final miniMenuService = MiniMenuService.instance;

    final overlayVisibleBefore = await overlayService.checkOverlayStatus();
    final miniMenuOpenBefore = miniMenuService.isMiniMenuOpen;
    final miniMenuSessionId = miniMenuService.lastSessionId;
    var overlaySuspended = false;

    if (miniMenuOpenBefore) {
      await miniMenuService.closeMiniMenu();
    }
    if (suspendOverlay && overlayVisibleBefore) {
      await overlayService.suspendOverlayForCapture();
      overlaySuspended = true;
    }

    return _OverlaySnapshot(
      overlaySuspended: overlaySuspended,
      miniMenuOpenBefore: miniMenuOpenBefore,
      miniMenuSessionId: miniMenuSessionId,
    );
  }

  Future<void> _restoreOverlays(_OverlaySnapshot snapshot) async {
    final overlayService = Live2DOverlayService();
    final miniMenuService = MiniMenuService.instance;

    if (snapshot.overlaySuspended) {
      await overlayService.showOverlay();
    }
    if (snapshot.miniMenuOpenBefore) {
      await miniMenuService.openMiniMenu(sessionId: snapshot.miniMenuSessionId);
    }
  }
}

class _OverlaySnapshot {
  const _OverlaySnapshot({
    required this.overlaySuspended,
    required this.miniMenuOpenBefore,
    required this.miniMenuSessionId,
  });

  final bool overlaySuspended;
  final bool miniMenuOpenBefore;
  final String? miniMenuSessionId;
}

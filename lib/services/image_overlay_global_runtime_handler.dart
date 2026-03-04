import 'package:flutter/foundation.dart';

import '../features/image_overlay/data/models/image_overlay_settings.dart';
import '../features/image_overlay/data/services/image_overlay_native_bridge.dart';
import '../features/live2d/data/services/live2d_native_bridge.dart';
import 'global_runtime_registry.dart';

class ImageOverlayGlobalRuntimeHandler implements GlobalRuntimeListener {
  final Live2DNativeBridge _live2dBridge = Live2DNativeBridge();
  final ImageOverlayNativeBridge _imageBridge = ImageOverlayNativeBridge.instance;

  @override
  void onGlobalDisabled() {
    _live2dBridge.hideOverlay();
  }

  @override
  Future<void> onGlobalEnabled() async {
    try {
      final settings = await ImageOverlaySettings.load();
      if (!settings.isEnabled) {
        return;
      }
      if (settings.selectedEmotionFile == null) {
        return;
      }
      await _imageBridge.setOverlayMode('image');
      await _live2dBridge.showOverlay();
      await _live2dBridge.setSize(settings.overlayWidth, settings.overlayHeight);
      await _live2dBridge.setCharacterOpacity(settings.opacity);
      await _live2dBridge.setTouchThroughEnabled(settings.touchThroughEnabled);
      await _live2dBridge.setTouchThroughAlpha(settings.touchThroughAlpha);
      await _imageBridge.loadOverlayImage(settings.selectedEmotionFile!);
    } catch (e) {
      debugPrint('ImageOverlayGlobalRuntimeHandler enable failed: $e');
    }
  }
}

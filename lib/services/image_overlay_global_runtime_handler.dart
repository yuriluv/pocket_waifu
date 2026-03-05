import 'package:flutter/foundation.dart';

import '../features/image_overlay/data/models/image_overlay_settings.dart';
import '../features/image_overlay/data/services/image_overlay_native_bridge.dart';
import '../features/live2d/data/services/live2d_native_bridge.dart';
import 'global_runtime_registry.dart';

class ImageOverlayGlobalRuntimeHandler implements GlobalRuntimeListener {
  final Live2DNativeBridge _live2dBridge = Live2DNativeBridge();
  final ImageOverlayNativeBridge _imageBridge =
      ImageOverlayNativeBridge.instance;

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
      final isBasic =
          settings.overlayInteractionMode ==
          ImageOverlaySettings.overlayModeBasic;
      await _imageBridge.setOverlayMode(isBasic ? 'image_basic' : 'image');
      await _live2dBridge.showOverlay();
      await _live2dBridge.setSize(
        settings.overlayWidth,
        settings.overlayHeight,
      );
      await _live2dBridge.setHitboxSize(
        isBasic ? settings.overlayWidth : settings.hitboxWidth,
        isBasic ? settings.overlayHeight : settings.hitboxHeight,
      );

      final state = await _live2dBridge.getDisplayState();
      final screenWidth = (state['screenWidth'] as num?)?.toInt() ?? 0;
      final screenHeight = (state['screenHeight'] as num?)?.toInt() ?? 0;
      if (screenWidth > 0 && screenHeight > 0) {
        final hitboxWidth = isBasic
            ? settings.overlayWidth
            : settings.hitboxWidth;
        final hitboxHeight = isBasic
            ? settings.overlayHeight
            : settings.hitboxHeight;
        final maxX = (screenWidth - hitboxWidth).clamp(0, screenWidth);
        final maxY = (screenHeight - hitboxHeight).clamp(0, screenHeight);
        final targetX = (maxX * settings.positionX).round();
        final targetY = (maxY * settings.positionY).round();
        await _live2dBridge.setPosition(targetX.toDouble(), targetY.toDouble());
      }

      if (isBasic) {
        await _live2dBridge.setCharacterPinned(false);
        await _live2dBridge.setEditMode(false);
      }
      await _live2dBridge.setCharacterOpacity(settings.opacity);
      await _live2dBridge.setTouchThroughEnabled(settings.touchThroughEnabled);
      await _live2dBridge.setTouchThroughAlpha(settings.touchThroughAlpha);
      await _imageBridge.loadOverlayImage(settings.selectedEmotionFile!);
    } catch (e) {
      debugPrint('ImageOverlayGlobalRuntimeHandler enable failed: $e');
    }
  }
}

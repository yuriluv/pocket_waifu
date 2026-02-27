import 'package:flutter/foundation.dart';

import '../features/live2d/data/models/live2d_settings.dart';
import '../features/live2d/data/services/live2d_native_bridge.dart';
import '../services/global_runtime_registry.dart';

class Live2DGlobalRuntimeHandler implements GlobalRuntimeListener {
  final Live2DNativeBridge _bridge = Live2DNativeBridge();

  @override
  void onGlobalDisabled() {
    _bridge.hideOverlay();
  }

  @override
  Future<void> onGlobalEnabled() async {
    try {
      final settings = await Live2DSettings.load();
      if (!settings.isEnabled) return;
      if (settings.selectedModelPath == null) return;
      await _bridge.showOverlay();
      await _bridge.setScale(settings.scale);
      await _bridge.setCharacterOpacity(settings.opacity);
      await _bridge.setTouchThroughEnabled(settings.touchThroughEnabled);
      await _bridge.setTouchThroughAlpha(settings.touchThroughAlpha);
      await _bridge.loadModel(settings.selectedModelPath!);
    } catch (e) {
      debugPrint('Live2DGlobalRuntimeHandler enable failed: $e');
    }
  }
}

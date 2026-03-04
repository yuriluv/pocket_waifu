import '../features/live2d/data/models/live2d_settings.dart';
import '../features/live2d/data/services/live2d_native_bridge.dart';
import '../features/image_overlay/data/models/image_overlay_settings.dart';

class Live2DQuickToggleService {
  Live2DQuickToggleService._internal();

  static final Live2DQuickToggleService instance =
      Live2DQuickToggleService._internal();

  Future<bool> toggleTouchThrough() async {
    final bridge = Live2DNativeBridge();
    final mode = await bridge.getOverlayMode();
    if (mode == 'image') {
      final settings = await ImageOverlaySettings.load();
      final next = !settings.touchThroughEnabled;
      final updated = settings.copyWith(touchThroughEnabled: next);
      await updated.save();
      await bridge.setTouchThroughEnabled(next);
      await bridge.setTouchThroughAlpha(updated.touchThroughAlpha);
      return next;
    }

    final settings = await Live2DSettings.load();
    final next = !settings.touchThroughEnabled;
    final updated = settings.copyWith(touchThroughEnabled: next);
    await updated.save();

    await bridge.setTouchThroughEnabled(next);
    await bridge.setTouchThroughAlpha(updated.touchThroughAlpha);
    return next;
  }
}

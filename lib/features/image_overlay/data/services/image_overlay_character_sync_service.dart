import '../models/image_overlay_settings.dart';
import 'image_overlay_storage_service.dart';
import '../../../live2d/data/services/live2d_native_bridge.dart';
import 'image_overlay_native_bridge.dart';

class ImageOverlayCharacterSyncService {
  ImageOverlayCharacterSyncService._();

  static final ImageOverlayCharacterSyncService instance =
      ImageOverlayCharacterSyncService._();

  final ImageOverlayStorageService _storage =
      ImageOverlayStorageService.instance;
  final Live2DNativeBridge _live2dBridge = Live2DNativeBridge();
  final ImageOverlayNativeBridge _imageBridge =
      ImageOverlayNativeBridge.instance;

  Future<void> syncFromSessionCharacterName(String characterName) async {
    final settings = await ImageOverlaySettings.load();
    if (!settings.syncCharacterNameWithSession) {
      return;
    }
    final folder = settings.dataFolderPath;
    if (folder == null || folder.trim().isEmpty) {
      return;
    }

    _storage.restoreRootPath(folder);
    final characters = await _storage.scanCharacters();
    final lowered = characterName.trim().toLowerCase();
    if (lowered.isEmpty) {
      return;
    }
    for (final character in characters) {
      if (character.name.toLowerCase() != lowered) {
        continue;
      }
      final firstEmotion = character.emotions.isNotEmpty
          ? character.emotions.first.filePath
          : null;
      final next = settings.copyWith(
        selectedCharacterFolder: character.folderPath,
        selectedEmotionFile: firstEmotion,
      );
      await next.save();

      if (next.isEnabled && firstEmotion != null) {
        final isBasic =
            next.overlayInteractionMode ==
            ImageOverlaySettings.overlayModeBasic;
        await _imageBridge.setOverlayMode(isBasic ? 'image_basic' : 'image');
        await _live2dBridge.showOverlay();
        await _live2dBridge.setSize(next.overlayWidth, next.overlayHeight);
        await _live2dBridge.setHitboxSize(
          isBasic ? next.overlayWidth : next.hitboxWidth,
          isBasic ? next.overlayHeight : next.hitboxHeight,
        );

        final state = await _live2dBridge.getDisplayState();
        final screenWidth = (state['screenWidth'] as num?)?.toInt() ?? 0;
        final screenHeight = (state['screenHeight'] as num?)?.toInt() ?? 0;
        if (screenWidth > 0 && screenHeight > 0) {
          final hitboxWidth = isBasic ? next.overlayWidth : next.hitboxWidth;
          final hitboxHeight = isBasic ? next.overlayHeight : next.hitboxHeight;
          final maxX = (screenWidth - hitboxWidth).clamp(0, screenWidth);
          final maxY = (screenHeight - hitboxHeight).clamp(0, screenHeight);
          final targetX = (maxX * next.positionX).round();
          final targetY = (maxY * next.positionY).round();
          await _live2dBridge.setPosition(
            targetX.toDouble(),
            targetY.toDouble(),
          );
        }

        if (isBasic) {
          await _live2dBridge.setCharacterPinned(false);
          await _live2dBridge.setEditMode(false);
        }
        await _live2dBridge.setCharacterOpacity(next.opacity);
        await _live2dBridge.setTouchThroughEnabled(next.touchThroughEnabled);
        await _live2dBridge.setTouchThroughAlpha(next.touchThroughAlpha);
        await _imageBridge.loadOverlayImage(firstEmotion);
      }
      return;
    }
  }
}

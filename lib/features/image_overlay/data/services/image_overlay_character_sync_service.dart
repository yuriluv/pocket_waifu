import '../models/image_overlay_settings.dart';
import 'image_overlay_storage_service.dart';

class ImageOverlayCharacterSyncService {
  ImageOverlayCharacterSyncService._();

  static final ImageOverlayCharacterSyncService instance =
      ImageOverlayCharacterSyncService._();

  final ImageOverlayStorageService _storage = ImageOverlayStorageService.instance;

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
      final firstEmotion =
          character.emotions.isNotEmpty ? character.emotions.first.filePath : null;
      final next = settings.copyWith(
        selectedCharacterFolder: character.folderPath,
        selectedEmotionFile: firstEmotion,
      );
      await next.save();
      return;
    }
  }
}

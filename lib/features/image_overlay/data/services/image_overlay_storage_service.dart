import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as path;

import '../models/image_overlay_character.dart';

class ImageOverlayStorageService {
  ImageOverlayStorageService._();

  static final ImageOverlayStorageService instance = ImageOverlayStorageService._();

  String? _rootPath;

  String? get rootPath => _rootPath;
  bool get hasFolderSelected => _rootPath != null;

  void restoreRootPath(String? pathValue) {
    if (pathValue == null || pathValue.trim().isEmpty) {
      _rootPath = null;
      return;
    }
    _rootPath = path.normalize(pathValue);
  }

  Future<String?> pickRootFolder() async {
    final result = await FilePicker.platform.getDirectoryPath(
      dialogTitle: '이미지 오버레이 폴더 선택',
      lockParentWindow: true,
    );
    if (result == null || result.trim().isEmpty) {
      return null;
    }
    _rootPath = path.normalize(result);
    return _rootPath;
  }

  void clear() {
    _rootPath = null;
  }

  Future<List<ImageOverlayCharacter>> scanCharacters() async {
    final root = _rootPath;
    if (root == null) {
      return const [];
    }
    final dir = Directory(root);
    if (!await dir.exists()) {
      return const [];
    }

    final characters = <ImageOverlayCharacter>[];
    await for (final entity in dir.list(followLinks: false)) {
      if (entity is! Directory) {
        continue;
      }
      final characterName = path.basename(entity.path);
      final emotions = await _scanEmotions(entity);
      if (emotions.isEmpty) {
        continue;
      }
      characters.add(
        ImageOverlayCharacter(
          name: characterName,
          folderPath: entity.path,
          emotions: emotions,
        ),
      );
    }

    characters.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return characters;
  }

  Future<List<ImageOverlayEmotion>> _scanEmotions(Directory characterDir) async {
    final out = <ImageOverlayEmotion>[];
    await for (final entity in characterDir.list(followLinks: false)) {
      if (entity is! File) {
        continue;
      }
      final ext = path.extension(entity.path).toLowerCase();
      if (ext != '.png' && ext != '.jpg' && ext != '.jpeg' && ext != '.webp') {
        continue;
      }
      final name = path.basenameWithoutExtension(entity.path);
      out.add(ImageOverlayEmotion(name: name, filePath: entity.path));
    }
    out.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return out;
  }

  Future<bool> renameEmotionFile({
    required String originalPath,
    required String nextName,
  }) async {
    final nextTrimmed = nextName.trim();
    if (nextTrimmed.isEmpty) {
      return false;
    }
    final file = File(originalPath);
    if (!await file.exists()) {
      return false;
    }
    final ext = path.extension(originalPath);
    final newPath = path.join(path.dirname(originalPath), '$nextTrimmed$ext');
    if (newPath == originalPath) {
      return true;
    }
    final nextFile = File(newPath);
    if (await nextFile.exists()) {
      return false;
    }
    await file.rename(newPath);
    return true;
  }
}

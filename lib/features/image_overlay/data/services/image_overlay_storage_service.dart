import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as path;

import '../models/image_overlay_character.dart';

class ImageOverlayStorageService {
  ImageOverlayStorageService._();

  static final ImageOverlayStorageService instance = ImageOverlayStorageService._();

  String? _rootPath;

  static const Set<String> _supportedEmotionExtensions = {
    '.png',
    '.jpg',
    '.jpeg',
    '.webp',
  };

  String? get rootPath => _rootPath;
  bool get hasFolderSelected => _rootPath != null;

  void restoreRootPath(String? pathValue) {
    if (pathValue == null || pathValue.trim().isEmpty) {
      _rootPath = null;
      return;
    }
    _rootPath = _normalizeFolderPath(pathValue);
  }

  Future<String?> pickRootFolder() async {
    final result = await FilePicker.platform.getDirectoryPath(
      dialogTitle: '이미지 오버레이 폴더 선택',
      lockParentWindow: true,
    );
    if (result == null || result.trim().isEmpty) {
      return null;
    }
    _rootPath = _normalizeFolderPath(result);
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
    try {
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
    } on FileSystemException {
      return const [];
    }

    if (characters.isEmpty) {
      final recursiveCharacters = await _scanCharactersRecursiveFallback(dir, root);
      characters.addAll(recursiveCharacters);
    }

    characters.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return characters;
  }

  Future<List<ImageOverlayEmotion>> _scanEmotions(Directory characterDir) async {
    final out = <ImageOverlayEmotion>[];
    try {
      await for (final entity in characterDir.list(followLinks: false)) {
        if (entity is! File) {
          continue;
        }
        final ext = path.extension(entity.path).toLowerCase();
        if (!_supportedEmotionExtensions.contains(ext)) {
          continue;
        }
        final name = path.basenameWithoutExtension(entity.path);
        out.add(ImageOverlayEmotion(name: name, filePath: entity.path));
      }
    } on FileSystemException {
      return const [];
    }
    out.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return out;
  }

  Future<List<ImageOverlayCharacter>> _scanCharactersRecursiveFallback(
    Directory rootDir,
    String rootPath,
  ) async {
    final map = <String, List<ImageOverlayEmotion>>{};
    final names = <String, String>{};

    try {
      await for (final entity in rootDir.list(recursive: true, followLinks: false)) {
        if (entity is! File) {
          continue;
        }
        final ext = path.extension(entity.path).toLowerCase();
        if (!_supportedEmotionExtensions.contains(ext)) {
          continue;
        }

        final relative = path
            .relative(entity.path, from: rootPath)
            .replaceAll('\\', '/');
        final segments = relative
            .split('/')
            .where((segment) => segment.isNotEmpty)
            .toList(growable: false);
        if (segments.isEmpty) {
          continue;
        }

        final String characterFolder;
        final String characterName;
        if (segments.length == 1) {
          characterFolder = rootPath;
          final rootName = path.basename(rootPath);
          characterName = rootName.isEmpty ? 'character' : rootName;
        } else {
          characterName = segments.first;
          characterFolder = path.join(rootPath, segments.first);
        }

        final emotion = ImageOverlayEmotion(
          name: path.basenameWithoutExtension(entity.path),
          filePath: entity.path,
        );
        map.putIfAbsent(characterFolder, () => <ImageOverlayEmotion>[]).add(emotion);
        names[characterFolder] = characterName;
      }
    } on FileSystemException {
      return const [];
    }

    final characters = <ImageOverlayCharacter>[];
    map.forEach((folderPath, emotions) {
      emotions.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      characters.add(
        ImageOverlayCharacter(
          name: names[folderPath] ?? path.basename(folderPath),
          folderPath: folderPath,
          emotions: emotions,
        ),
      );
    });

    characters.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return characters;
  }

  String _normalizeFolderPath(String rawPath) {
    final trimmed = rawPath.trim();
    final resolved = _resolvePrimaryStoragePath(trimmed);
    return path.normalize((resolved ?? trimmed).trim());
  }

  String? _resolvePrimaryStoragePath(String rawPath) {
    final decoded = Uri.decodeFull(rawPath).trim();
    final marker = 'primary:';
    final index = decoded.lastIndexOf(marker);
    if (index == -1) {
      return null;
    }

    final relative = decoded
        .substring(index + marker.length)
        .split('?')
        .first
        .replaceAll('\\', '/')
        .trim();

    if (relative.isEmpty) {
      return '/storage/emulated/0';
    }

    return path.join('/storage/emulated/0', relative);
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

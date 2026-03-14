import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:permission_handler/permission_handler.dart';

import '../models/image_overlay_character.dart';
import 'image_overlay_charx_service.dart';

enum ImageOverlayScanIssue { none, folderMissing, permissionDenied, emptyFolder }

class ImageOverlayStorageService {
  ImageOverlayStorageService._({
    ImageOverlayCharxService? charxService,
    Future<bool> Function()? hasExternalStorageAccess,
    bool Function(String path)? isLikelyExternalStoragePath,
  }) : _charxService = charxService ?? ImageOverlayCharxService.instance,
       _hasExternalStorageAccess =
           hasExternalStorageAccess ?? _defaultHasExternalStorageAccess,
       _isLikelyExternalStoragePath =
           isLikelyExternalStoragePath ?? _defaultIsLikelyExternalStoragePath;

  static final ImageOverlayStorageService instance =
      ImageOverlayStorageService._();

  final ImageOverlayCharxService _charxService;
  final Future<bool> Function() _hasExternalStorageAccess;
  final bool Function(String path) _isLikelyExternalStoragePath;

  String? _rootPath;
  ImageOverlayScanIssue _lastScanIssue = ImageOverlayScanIssue.none;
  String? _lastScanDetails;

  static const Set<String> _supportedEmotionExtensions = {
    '.png',
    '.jpg',
    '.jpeg',
    '.webp',
  };

  @visibleForTesting
  factory ImageOverlayStorageService.createForTesting({
    ImageOverlayCharxService? charxService,
    Future<bool> Function()? hasExternalStorageAccess,
    bool Function(String path)? isLikelyExternalStoragePath,
  }) {
    return ImageOverlayStorageService._(
      charxService: charxService,
      hasExternalStorageAccess: hasExternalStorageAccess,
      isLikelyExternalStoragePath: isLikelyExternalStoragePath,
    );
  }

  String? get rootPath => _rootPath;
  bool get hasFolderSelected => _rootPath != null;
  ImageOverlayScanIssue get lastScanIssue => _lastScanIssue;
  String? get lastScanDetails => _lastScanDetails;
  bool get needsStoragePermission =>
      _lastScanIssue == ImageOverlayScanIssue.permissionDenied;

  String? get lastScanMessage {
    switch (_lastScanIssue) {
      case ImageOverlayScanIssue.none:
        return null;
      case ImageOverlayScanIssue.folderMissing:
        return '선택한 데이터 폴더를 다시 열 수 없습니다. 경로가 바뀌었거나 Android 저장소 접근이 끊겼을 수 있습니다.';
      case ImageOverlayScanIssue.permissionDenied:
        return 'Android가 선택한 폴더를 직접 읽지 못하고 있습니다. Android 11+에서는 모든 파일 접근 권한을 허용한 뒤 다시 스캔해야 할 수 있습니다.';
      case ImageOverlayScanIssue.emptyFolder:
        return '선택한 폴더 안에서 캐릭터 폴더나 .charx 파일을 찾지 못했습니다.';
    }
  }

  void restoreRootPath(String? pathValue) {
    if (pathValue == null || pathValue.trim().isEmpty) {
      _rootPath = null;
      _clearScanIssue();
      return;
    }
    _rootPath = normalizeFolderPath(pathValue);
  }

  Future<String?> pickRootFolder() async {
    final result = await FilePicker.platform.getDirectoryPath(
      dialogTitle: '이미지 오버레이 폴더 선택',
      lockParentWindow: true,
    );
    if (result == null || result.trim().isEmpty) {
      return null;
    }
    _rootPath = normalizeFolderPath(result);
    _clearScanIssue();
    return _rootPath;
  }

  void clear() {
    _rootPath = null;
    _clearScanIssue();
  }

  Future<void> clearCharxCache() {
    return _charxService.clearCache();
  }

  Future<bool> requestStoragePermission() async {
    if (!Platform.isAndroid) {
      return true;
    }

    final status = await Permission.manageExternalStorage.request();
    return status.isGranted;
  }

  Future<bool> openStoragePermissionSettings() {
    return openAppSettings();
  }

  Future<List<ImageOverlayCharacter>> scanCharacters() async {
    _clearScanIssue();

    final root = _rootPath;
    if (root == null) {
      return const [];
    }
    final dir = Directory(root);
    if (!await dir.exists()) {
      _setScanIssue(ImageOverlayScanIssue.folderMissing, details: root);
      return const [];
    }

    final characters = <ImageOverlayCharacter>[];
    try {
      await for (final entity in dir.list(followLinks: false)) {
        if (entity is Directory) {
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
          continue;
        }

        if (entity is File && _isCharxFile(entity.path)) {
          final character = await _charxService.loadCharacter(entity);
          if (character != null) {
            characters.add(character);
          }
        }
      }
    } on FileSystemException catch (error, stackTrace) {
      _reportScanPermissionError(root, error, stackTrace);
      return const [];
    }

    if (characters.isEmpty) {
      final recursiveCharacters = await _scanCharactersRecursiveFallback(
        dir,
        root,
      );
      characters.addAll(recursiveCharacters);
    }

    if (characters.isEmpty && _lastScanIssue == ImageOverlayScanIssue.none) {
      final missingExternalPermission =
          _isLikelyExternalStoragePath(root) &&
          !await _hasExternalStorageAccess();
      if (missingExternalPermission) {
        _setScanIssue(ImageOverlayScanIssue.permissionDenied, details: root);
        debugPrint(
          'ImageOverlayStorageService.scanCharacters found no entries '
          'because external storage access is missing. root=$root',
        );
      } else {
        _setScanIssue(ImageOverlayScanIssue.emptyFolder, details: root);
      }
    }

    characters.sort(_compareCharacters);
    return characters;
  }

  Future<List<ImageOverlayEmotion>> _scanEmotions(
    Directory characterDir,
  ) async {
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
    } on FileSystemException catch (error, stackTrace) {
      _reportScanPermissionError(characterDir.path, error, stackTrace);
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
    final charxCharacters = <ImageOverlayCharacter>[];

    try {
      await for (final entity in rootDir.list(
        recursive: true,
        followLinks: false,
      )) {
        if (entity is! File) {
          continue;
        }

        if (_isCharxFile(entity.path)) {
          final character = await _charxService.loadCharacter(entity);
          if (character != null) {
            charxCharacters.add(character);
          }
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
        map
            .putIfAbsent(characterFolder, () => <ImageOverlayEmotion>[])
            .add(emotion);
        names[characterFolder] = characterName;
      }
    } on FileSystemException catch (error, stackTrace) {
      _reportScanPermissionError(rootPath, error, stackTrace);
      return const [];
    }

    final characters = <ImageOverlayCharacter>[];
    characters.addAll(charxCharacters);
    map.forEach((folderPath, emotions) {
      emotions.sort(
        (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      );
      characters.add(
        ImageOverlayCharacter(
          name: names[folderPath] ?? path.basename(folderPath),
          folderPath: folderPath,
          emotions: emotions,
        ),
      );
    });

    characters.sort(_compareCharacters);
    return characters;
  }

  int _compareCharacters(ImageOverlayCharacter a, ImageOverlayCharacter b) {
    final nameCompare = a.name.toLowerCase().compareTo(b.name.toLowerCase());
    if (nameCompare != 0) {
      return nameCompare;
    }
    return a.folderPath.toLowerCase().compareTo(b.folderPath.toLowerCase());
  }

  bool _isCharxFile(String filePath) {
    return path.extension(filePath).toLowerCase() == '.charx';
  }

  static String normalizeFolderPath(String rawPath) {
    final trimmed = rawPath.trim();
    final decoded = Uri.decodeFull(trimmed).trim();
    final resolved =
        _resolveFileUriPath(decoded) ??
        _resolveRawStoragePath(decoded) ??
        _resolvePrimaryStoragePath(decoded);
    return path.normalize((resolved ?? decoded).trim());
  }

  @visibleForTesting
  static String normalizeFolderPathForTesting(String rawPath) {
    return normalizeFolderPath(rawPath);
  }

  static String? _resolvePrimaryStoragePath(String rawPath) {
    final marker = 'primary:';
    final index = rawPath.lastIndexOf(marker);
    if (index == -1) {
      return null;
    }

    final relative = rawPath
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

  static String? _resolveFileUriPath(String rawPath) {
    if (!rawPath.startsWith('file://')) {
      return null;
    }

    final uri = Uri.tryParse(rawPath);
    if (uri == null) {
      return null;
    }

    try {
      return uri.toFilePath(windows: false);
    } catch (_) {
      return null;
    }
  }

  static String? _resolveRawStoragePath(String rawPath) {
    final marker = 'raw:';
    final index = rawPath.lastIndexOf(marker);
    if (index == -1) {
      return null;
    }

    final resolved = rawPath.substring(index + marker.length).split('?').first;
    final normalized = resolved.replaceAll('\\', '/').trim();
    if (!normalized.startsWith('/')) {
      return null;
    }

    return path.normalize(normalized);
  }

  static Future<bool> _defaultHasExternalStorageAccess() async {
    if (!Platform.isAndroid) {
      return true;
    }

    final manageStatus = await Permission.manageExternalStorage.status;
    if (manageStatus.isGranted) {
      return true;
    }

    final storageStatus = await Permission.storage.status;
    return storageStatus.isGranted;
  }

  static bool _defaultIsLikelyExternalStoragePath(String filePath) {
    final normalized = filePath.replaceAll('\\', '/');
    return normalized.startsWith('/storage/') || normalized.startsWith('/sdcard/');
  }

  void _clearScanIssue() {
    _lastScanIssue = ImageOverlayScanIssue.none;
    _lastScanDetails = null;
  }

  void _setScanIssue(ImageOverlayScanIssue issue, {String? details}) {
    _lastScanIssue = issue;
    _lastScanDetails = details;
  }

  void _reportScanPermissionError(
    String rootPath,
    FileSystemException error,
    StackTrace stackTrace,
  ) {
    _setScanIssue(
      ImageOverlayScanIssue.permissionDenied,
      details: '$rootPath :: ${error.message}',
    );
    debugPrint(
      'ImageOverlayStorageService.scanCharacters failed '
      '(permissionDenied) root=$rootPath error=$error stack=$stackTrace',
    );
  }

  Future<String?> renameEmotionFile({
    required String originalPath,
    required String nextName,
  }) async {
    final nextTrimmed = nextName.trim();
    if (nextTrimmed.isEmpty) {
      return null;
    }
    final file = File(originalPath);
    if (!await file.exists()) {
      return null;
    }
    final ext = path.extension(originalPath);
    final newPath = path.join(path.dirname(originalPath), '$nextTrimmed$ext');
    if (newPath == originalPath) {
      return originalPath;
    }
    final nextFile = File(newPath);
    if (await nextFile.exists()) {
      return null;
    }
    await file.rename(newPath);
    return newPath;
  }
}

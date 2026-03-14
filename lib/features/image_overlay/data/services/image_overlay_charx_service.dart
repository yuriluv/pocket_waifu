import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import '../models/image_overlay_character.dart';

class ImageOverlayCharxService {
  ImageOverlayCharxService({Future<Directory> Function()? cacheRootProvider})
    : _cacheRootProvider = cacheRootProvider ?? _defaultCacheRootProvider;

  static final ImageOverlayCharxService instance = ImageOverlayCharxService();

  static const _cacheDirectoryName = 'image_overlay_charx_cache';
  static const _manifestFileName = '.charx_manifest.json';
  static const _overlayAssetPrefix = 'assets/other/image/';

  static const Set<String> _supportedUriPrefixes = {
    'embeded://',
    'embedded://',
    '__asset:',
  };

  final Future<Directory> Function() _cacheRootProvider;

  Future<ImageOverlayCharacter?> loadCharacter(File charxFile) async {
    if (!await charxFile.exists()) {
      return null;
    }

    final cacheRoot = await _cacheRootProvider();
    if (!await cacheRoot.exists()) {
      await cacheRoot.create(recursive: true);
    }

    final cacheKey = sha1
        .convert(utf8.encode(path.normalize(charxFile.absolute.path)))
        .toString();
    final characterDir = Directory(path.join(cacheRoot.path, cacheKey));
    final stagingDir = Directory(
      path.join(cacheRoot.path, '$cacheKey.staging'),
    );
    final sourceStat = await charxFile.stat();

    final cachedCharacter = await _loadFromCacheIfFresh(
      charxFile: charxFile,
      characterDir: characterDir,
      sourceStat: sourceStat,
    );
    if (cachedCharacter != null) {
      return cachedCharacter;
    }

    await _deleteIfExists(stagingDir);
    await stagingDir.create(recursive: true);

    try {
      final outputFileNames = await Isolate.run(
        () => _extractCharxArchive(charxFile.path, stagingDir.path),
      );
      if (outputFileNames.isEmpty) {
        await _deleteIfExists(stagingDir);
        return null;
      }

      await _writeManifest(stagingDir: stagingDir, sourceStat: sourceStat);

      await _deleteIfExists(characterDir);
      final finalizedDir = await stagingDir.rename(characterDir.path);
      return _buildCharacter(charxFile, finalizedDir, outputFileNames);
    } catch (_) {
      await _deleteIfExists(stagingDir);
      return null;
    }
  }

  Future<void> clearCache() async {
    final cacheRoot = await _cacheRootProvider();
    await _deleteIfExists(cacheRoot);
  }

  static Future<Directory> _defaultCacheRootProvider() async {
    final docsDir = await getApplicationDocumentsDirectory();
    return Directory(path.join(docsDir.path, _cacheDirectoryName));
  }

  Future<void> _deleteIfExists(Directory dir) async {
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
  }

  Future<ImageOverlayCharacter?> _loadFromCacheIfFresh({
    required File charxFile,
    required Directory characterDir,
    required FileStat sourceStat,
  }) async {
    if (!await characterDir.exists()) {
      return null;
    }

    final manifestFile = File(path.join(characterDir.path, _manifestFileName));
    if (!await manifestFile.exists()) {
      return null;
    }

    try {
      final decoded = jsonDecode(await manifestFile.readAsString());
      if (decoded is! Map<String, dynamic>) {
        return null;
      }

      if (decoded['sourceSize'] != sourceStat.size ||
          decoded['sourceModifiedMs'] !=
              sourceStat.modified.millisecondsSinceEpoch) {
        return null;
      }

      final outputFileNames = <String>[];
      await for (final entity in characterDir.list(followLinks: false)) {
        if (entity is! File) {
          continue;
        }
        final fileName = path.basename(entity.path);
        if (fileName == _manifestFileName) {
          continue;
        }
        outputFileNames.add(fileName);
      }

      if (outputFileNames.isEmpty) {
        return null;
      }

      return _buildCharacter(charxFile, characterDir, outputFileNames);
    } catch (_) {
      return null;
    }
  }

  Future<void> _writeManifest({
    required Directory stagingDir,
    required FileStat sourceStat,
  }) async {
    final manifestFile = File(path.join(stagingDir.path, _manifestFileName));
    await manifestFile.writeAsString(
      jsonEncode(<String, Object>{
        'sourceSize': sourceStat.size,
        'sourceModifiedMs': sourceStat.modified.millisecondsSinceEpoch,
      }),
      flush: true,
    );
  }

  ImageOverlayCharacter _buildCharacter(
    File charxFile,
    Directory characterDir,
    List<String> outputFileNames,
  ) {
    outputFileNames.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    final emotions = outputFileNames
        .map(
          (fileName) => ImageOverlayEmotion(
            name: path.basenameWithoutExtension(fileName),
            filePath: path.join(characterDir.path, fileName),
            supportsRename: false,
          ),
        )
        .toList(growable: false);

    return ImageOverlayCharacter(
      name: path.basenameWithoutExtension(charxFile.path),
      folderPath: characterDir.path,
      emotions: emotions,
    );
  }

  static List<_CharxAssetMapping> _parseAssetMappings(String rawCardJson) {
    final decoded = jsonDecode(rawCardJson);
    if (decoded is! Map) {
      return const <_CharxAssetMapping>[];
    }

    final data = decoded['data'];
    if (data is! Map) {
      return const <_CharxAssetMapping>[];
    }

    final assets = data['assets'];
    if (assets is! List) {
      return const <_CharxAssetMapping>[];
    }

    final mappings = <_CharxAssetMapping>[];
    for (final rawAsset in assets) {
      if (rawAsset is! Map) {
        continue;
      }

      final asset = Map<String, dynamic>.from(rawAsset);
      final archivePath = _embeddedUriToArchivePath(asset['uri']);
      if (archivePath == null || !_isOverlayAssetPath(archivePath)) {
        continue;
      }

      final stem = _sanitizeFileStem(asset['name'] as Object?);
      final extension = _sanitizeExtension(asset['ext'] as Object?);
      if (stem.isEmpty || extension.isEmpty) {
        continue;
      }

      mappings.add(
        _CharxAssetMapping(
          archivePath: archivePath,
          targetFileName: '$stem.$extension',
        ),
      );
    }

    return mappings;
  }

  static bool _isOverlayAssetPath(String archivePath) {
    return archivePath.toLowerCase().startsWith(_overlayAssetPrefix);
  }

  static String? _embeddedUriToArchivePath(Object? rawUri) {
    if (rawUri is! String) {
      return null;
    }

    final trimmed = rawUri.trim();
    if (trimmed.isEmpty) {
      return null;
    }

    for (final prefix in _supportedUriPrefixes) {
      if (trimmed.startsWith(prefix)) {
        return _normalizeArchivePath(trimmed.substring(prefix.length));
      }
    }

    return null;
  }

  static String _normalizeArchivePath(String rawPath) {
    final normalized = path.posix.normalize(rawPath.replaceAll('\\', '/'));
    if (normalized == '.' || normalized.isEmpty) {
      return '';
    }

    return normalized
        .replaceFirst(RegExp(r'^\./'), '')
        .replaceFirst(RegExp(r'^/+'), '');
  }

  static String _sanitizeFileStem(Object? rawName) {
    if (rawName is! String) {
      return '';
    }

    final invalidChars = RegExp(r'[<>:"/\\|?*\x00-\x1F]');
    var sanitized = rawName.replaceAll(invalidChars, '_').trim();
    sanitized = sanitized.replaceAll(RegExp(r'\s+'), ' ');
    sanitized = sanitized.replaceAll(RegExp(r'^[. ]+|[. ]+$'), '');
    return sanitized;
  }

  static String _sanitizeExtension(Object? rawExt) {
    if (rawExt is! String) {
      return '';
    }

    final trimmed = rawExt.trim().replaceFirst('.', '').toLowerCase();
    if (trimmed.isEmpty) {
      return '';
    }

    return trimmed.replaceAll(RegExp(r'[^a-z0-9]+'), '');
  }

  static String _reserveFileName(
    String requestedName,
    Set<String> reservedNames,
  ) {
    final basename = path.basenameWithoutExtension(requestedName);
    final extension = path.extension(requestedName);
    var candidate = requestedName;
    var suffix = 2;

    while (!reservedNames.add(candidate.toLowerCase())) {
      candidate = '${basename}_$suffix$extension';
      suffix += 1;
    }

    return candidate;
  }

  static String _readArchiveText(ArchiveFile entry) {
    return utf8.decode(_readArchiveBytes(entry), allowMalformed: true);
  }

  static List<int> _readArchiveBytes(ArchiveFile entry) {
    return entry.readBytes() ?? const <int>[];
  }
}

List<String> _extractCharxArchive(String charxPath, String stagingDirPath) {
  final archive = ZipDecoder().decodeBytes(File(charxPath).readAsBytesSync());
  final entriesByPath = <String, ArchiveFile>{};
  ArchiveFile? cardEntry;

  for (final entry in archive.files) {
    final normalizedPath = ImageOverlayCharxService._normalizeArchivePath(
      entry.name,
    );
    if (normalizedPath.isEmpty) {
      continue;
    }

    final loweredPath = normalizedPath.toLowerCase();
    entriesByPath[loweredPath] = entry;
    if (!entry.isFile) {
      continue;
    }

    if (loweredPath == 'card.json') {
      cardEntry = entry;
      continue;
    }
    if (cardEntry == null && loweredPath.endsWith('/card.json')) {
      cardEntry = entry;
    }
  }

  if (cardEntry == null) {
    return const <String>[];
  }

  final mappings = ImageOverlayCharxService._parseAssetMappings(
    ImageOverlayCharxService._readArchiveText(cardEntry),
  );
  if (mappings.isEmpty) {
    return const <String>[];
  }

  final outputFileNames = <String>[];
  final reservedNames = <String>{};

  for (final mapping in mappings) {
    final archiveEntry = entriesByPath[mapping.archivePath.toLowerCase()];
    if (archiveEntry == null || !archiveEntry.isFile) {
      continue;
    }

    final targetFileName = ImageOverlayCharxService._reserveFileName(
      mapping.targetFileName,
      reservedNames,
    );
    final targetFile = File(path.join(stagingDirPath, targetFileName));
    targetFile.createSync(recursive: true);
    targetFile.writeAsBytesSync(
      ImageOverlayCharxService._readArchiveBytes(archiveEntry),
      flush: true,
    );
    outputFileNames.add(targetFileName);
  }

  return outputFileNames;
}

class _CharxAssetMapping {
  const _CharxAssetMapping({
    required this.archivePath,
    required this.targetFileName,
  });

  final String archivePath;
  final String targetFileName;
}

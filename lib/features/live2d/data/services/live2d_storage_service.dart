// ============================================================================
// ============================================================================
// ============================================================================

import 'dart:io';
import 'dart:convert';
import 'package:flutter/services.dart' show ByteData, rootBundle;
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import '../models/live2d_settings.dart';
import 'live2d_log_service.dart';
import '../../utils/folder_validator.dart';

enum DefaultModelBootstrapFailure {
  manifestMissing,
  invalidManifest,
  missingAsset,
  ioFailure,
}

class DefaultModelBootstrapResult {
  final bool bootstrapped;
  final String? rootFolderPath;
  final String? defaultModelRelativePath;
  final DefaultModelBootstrapFailure? failure;
  final String? details;

  const DefaultModelBootstrapResult._({
    required this.bootstrapped,
    this.rootFolderPath,
    this.defaultModelRelativePath,
    this.failure,
    this.details,
  });

  const DefaultModelBootstrapResult.success({
    required String rootFolderPath,
    required String defaultModelRelativePath,
  }) : this._(
         bootstrapped: true,
         rootFolderPath: rootFolderPath,
         defaultModelRelativePath: defaultModelRelativePath,
       );

  const DefaultModelBootstrapResult.skipped({String? details})
    : this._(bootstrapped: false, details: details);

  const DefaultModelBootstrapResult.failed({
    required DefaultModelBootstrapFailure failure,
    String? details,
  }) : this._(bootstrapped: false, failure: failure, details: details);
}

typedef DirectoryProvider = Future<Directory> Function();
typedef AssetStringLoader = Future<String> Function(String);
typedef AssetByteLoader = Future<ByteData> Function(String);

class _ArchetypeManifest {
  final String id;
  final String modelFile;
  final List<String> files;

  const _ArchetypeManifest({
    required this.id,
    required this.modelFile,
    required this.files,
  });
}

class _BundleManifest {
  final String defaultArchetype;
  final List<_ArchetypeManifest> archetypes;

  const _BundleManifest({
    required this.defaultArchetype,
    required this.archetypes,
  });
}

class Live2DStorageService {
  static final Live2DStorageService _instance = Live2DStorageService._internal();
  factory Live2DStorageService() => _instance;
  Live2DStorageService._internal({
    DirectoryProvider? appDocumentDirectoryProvider,
    AssetStringLoader? assetStringLoader,
    AssetByteLoader? assetByteLoader,
  }) : _appDocumentDirectoryProvider =
           appDocumentDirectoryProvider ?? getApplicationDocumentsDirectory,
       _assetStringLoader = assetStringLoader ?? rootBundle.loadString,
       _assetByteLoader = assetByteLoader ?? rootBundle.load;

  factory Live2DStorageService.test({
    required DirectoryProvider appDocumentDirectoryProvider,
    required AssetStringLoader assetStringLoader,
    required AssetByteLoader assetByteLoader,
  }) {
    return Live2DStorageService._internal(
      appDocumentDirectoryProvider: appDocumentDirectoryProvider,
      assetStringLoader: assetStringLoader,
      assetByteLoader: assetByteLoader,
    );
  }

  static const String _tag = 'Storage';
  static const String _manifestAssetPath =
      'artifacts/live2d/archetypes/manifest.json';
  static const String _assetRootPath = 'artifacts/live2d/archetypes';
  static const String _bootstrapRootFolderName = 'live2d_bootstrap';
  static const List<String> _requiredArchetypeIds = [
    'a_requires_preprocess',
    'b_partial_parameters',
    'c_full_ready',
  ];

  String? _currentFolderPath;
  String? _currentFolderUri;
  final DirectoryProvider _appDocumentDirectoryProvider;
  final AssetStringLoader _assetStringLoader;
  final AssetByteLoader _assetByteLoader;

  // === Getter ===
  String? get currentFolderPath => _currentFolderPath;
  String? get currentFolderUri => _currentFolderUri;
  bool get hasFolderSelected => _currentFolderPath != null;

  void restoreFromSettings(Live2DSettings settings) {
    _currentFolderPath = FolderValidator.normalizePath(settings.dataFolderPath);
    _currentFolderUri = FolderValidator.normalizePath(settings.dataFolderUri);

    if (_currentFolderPath == null) {
      _currentFolderUri = null;
    }
    
    if (_currentFolderPath != null) {
      live2dLog.info(_tag, '폴더 정보 복원됨', details: _currentFolderPath);
    }
  }

  /// 
  Future<String?> pickFolder() async {
    try {
      live2dLog.info(_tag, '폴더 선택 다이얼로그 열기...');

      final result = await FilePicker.platform.getDirectoryPath(
        dialogTitle: 'Live2D 모델 폴더 선택',
        lockParentWindow: true,
      );

      if (result == null) {
        live2dLog.info(_tag, '폴더 선택 취소됨');
        return null;
      }

      final normalizedPath = FolderValidator.normalizePath(result);
      if (normalizedPath == null) {
        live2dLog.warning(_tag, '선택한 폴더 경로가 비어 있음');
        return null;
      }

      final dir = Directory(normalizedPath);
      if (!await dir.exists()) {
        live2dLog.error(_tag, '선택한 폴더가 존재하지 않음', details: normalizedPath);
        return null;
      }

      _currentFolderPath = normalizedPath;
      _currentFolderUri = normalizedPath;

      live2dLog.info(_tag, '폴더 선택 완료', details: normalizedPath);
      
      final live2dFolder = Directory(path.join(normalizedPath, 'Live2D'));
      if (await live2dFolder.exists()) {
        live2dLog.info(_tag, 'Live2D 하위 폴더 발견', details: live2dFolder.path);
      } else {
        live2dLog.warning(
          _tag, 
          'Live2D 하위 폴더 없음',
          details: '선택한 폴더에 Live2D 서브폴더가 없습니다. '
                   '모델들이 직접 이 폴더에 있거나, Live2D 폴더를 생성해주세요.',
        );
      }

      return normalizedPath;
    } catch (e, stack) {
      live2dLog.error(
        _tag,
        '폴더 선택 실패',
        error: e,
        stackTrace: stack,
      );
      return null;
    }
  }

  Future<bool> validateCurrentFolder() async {
    if (_currentFolderPath == null) {
      return false;
    }

    try {
      final exists = await FolderValidator.isExistingDirectory(_currentFolderPath);
      
      if (!exists) {
        live2dLog.warning(
          _tag,
          '저장된 폴더가 더 이상 존재하지 않음',
          details: _currentFolderPath,
        );
        _currentFolderPath = null;
        _currentFolderUri = null;
        return false;
      }

      return true;
    } catch (e) {
      live2dLog.error(_tag, '폴더 유효성 검증 실패', error: e);
      return false;
    }
  }

  void clearFolder() {
    _currentFolderPath = null;
    _currentFolderUri = null;
    live2dLog.info(_tag, '폴더 설정 초기화됨');
  }

  /// 
  Future<String?> getModelRootPath() async {
    if (_currentFolderPath == null) return null;

    final live2dFolder = Directory(path.join(_currentFolderPath!, 'Live2D'));
    if (await live2dFolder.exists()) {
      return live2dFolder.path;
    }

    return _currentFolderPath;
  }

  Future<DefaultModelBootstrapResult> bootstrapDefaultModelRootIfNeeded() async {
    if (_currentFolderPath != null) {
      return const DefaultModelBootstrapResult.skipped(
        details: 'folder already configured',
      );
    }

    final manifestLoad = await _loadManifest();
    if (manifestLoad.$1 == null) {
      return manifestLoad.$2!;
    }

    final manifest = manifestLoad.$1!;

    try {
      final docsDir = await _appDocumentDirectoryProvider();
      final bootstrapRoot = Directory(
        path.join(docsDir.path, _bootstrapRootFolderName),
      );
      final live2dRoot = Directory(path.join(bootstrapRoot.path, 'Live2D'));

      if (await bootstrapRoot.exists()) {
        final isValid = await _validateBootstrappedRoot(live2dRoot.path, manifest);
        if (isValid) {
          _currentFolderPath = bootstrapRoot.path;
          _currentFolderUri = bootstrapRoot.path;
          return DefaultModelBootstrapResult.success(
            rootFolderPath: bootstrapRoot.path,
            defaultModelRelativePath: _defaultModelPath(manifest),
          );
        }

        await bootstrapRoot.delete(recursive: true);
      }

      await live2dRoot.create(recursive: true);

      for (final archetype in manifest.archetypes) {
        final archetypeDir = Directory(path.join(live2dRoot.path, archetype.id));
        await archetypeDir.create(recursive: true);

        for (final relativeFile in archetype.files) {
          final sourceAssetPath =
              '$_assetRootPath/${archetype.id}/$relativeFile';
          final targetFile = File(path.join(archetypeDir.path, relativeFile));
          await targetFile.parent.create(recursive: true);
          try {
            final bytes = await _assetByteLoader(sourceAssetPath);
            await targetFile.writeAsBytes(
              bytes.buffer.asUint8List(
                bytes.offsetInBytes,
                bytes.lengthInBytes,
              ),
              flush: true,
            );
          } catch (e) {
            if (await bootstrapRoot.exists()) {
              await bootstrapRoot.delete(recursive: true);
            }
            return DefaultModelBootstrapResult.failed(
              failure: DefaultModelBootstrapFailure.missingAsset,
              details: '$sourceAssetPath ($e)',
            );
          }
        }
      }

      final validCopy = await _validateBootstrappedRoot(live2dRoot.path, manifest);
      if (!validCopy) {
        if (await bootstrapRoot.exists()) {
          await bootstrapRoot.delete(recursive: true);
        }
        return const DefaultModelBootstrapResult.failed(
          failure: DefaultModelBootstrapFailure.invalidManifest,
          details: 'bootstrapped output does not satisfy archetype contract',
        );
      }

      _currentFolderPath = bootstrapRoot.path;
      _currentFolderUri = bootstrapRoot.path;
      live2dLog.info(_tag, '기본 모델 번들 부트스트랩 완료', details: bootstrapRoot.path);

      return DefaultModelBootstrapResult.success(
        rootFolderPath: bootstrapRoot.path,
        defaultModelRelativePath: _defaultModelPath(manifest),
      );
    } catch (e, stack) {
      live2dLog.error(_tag, '기본 모델 번들 부트스트랩 실패', error: e, stackTrace: stack);
      return DefaultModelBootstrapResult.failed(
        failure: DefaultModelBootstrapFailure.ioFailure,
        details: '$e',
      );
    }
  }

  Future<(_BundleManifest?, DefaultModelBootstrapResult?)> _loadManifest() async {
    String rawManifest;
    try {
      rawManifest = await _assetStringLoader(_manifestAssetPath);
    } catch (e) {
      live2dLog.warning(_tag, '기본 번들 manifest 로드 실패', details: '$e');
      return (
        null,
        DefaultModelBootstrapResult.failed(
          failure: DefaultModelBootstrapFailure.manifestMissing,
          details: '$e',
        ),
      );
    }

    try {
      final decoded = jsonDecode(rawManifest);
      if (decoded is! Map<String, dynamic>) {
        return (
          null,
          const DefaultModelBootstrapResult.failed(
            failure: DefaultModelBootstrapFailure.invalidManifest,
            details: 'manifest root must be an object',
          ),
        );
      }

      final defaultArchetype = decoded['defaultArchetype'];
      final archetypesRaw = decoded['archetypes'];
      if (defaultArchetype is! String || archetypesRaw is! List) {
        return (
          null,
          const DefaultModelBootstrapResult.failed(
            failure: DefaultModelBootstrapFailure.invalidManifest,
            details: 'manifest requires defaultArchetype and archetypes',
          ),
        );
      }

      final archetypes = <_ArchetypeManifest>[];
      for (final entry in archetypesRaw) {
        if (entry is! Map<String, dynamic>) {
          return (
            null,
            const DefaultModelBootstrapResult.failed(
              failure: DefaultModelBootstrapFailure.invalidManifest,
              details: 'archetype entry must be an object',
            ),
          );
        }

        final id = entry['id'];
        final modelFile = entry['modelFile'];
        final filesRaw = entry['files'];
        if (id is! String || modelFile is! String || filesRaw is! List) {
          return (
            null,
            const DefaultModelBootstrapResult.failed(
              failure: DefaultModelBootstrapFailure.invalidManifest,
              details: 'archetype requires id, modelFile, files',
            ),
          );
        }

        final files = <String>[];
        for (final file in filesRaw) {
          if (file is! String || file.trim().isEmpty) {
            return (
              null,
              const DefaultModelBootstrapResult.failed(
                failure: DefaultModelBootstrapFailure.invalidManifest,
                details: 'archetype files must be non-empty strings',
              ),
            );
          }
          files.add(file);
        }

        archetypes.add(_ArchetypeManifest(id: id, modelFile: modelFile, files: files));
      }

      final manifest = _BundleManifest(
        defaultArchetype: defaultArchetype,
        archetypes: archetypes,
      );

      final valid = _validateManifestContract(manifest);
      if (!valid) {
        return (
          null,
          const DefaultModelBootstrapResult.failed(
            failure: DefaultModelBootstrapFailure.invalidManifest,
            details: 'manifest contract validation failed',
          ),
        );
      }

      return (manifest, null);
    } catch (e) {
      return (
        null,
        DefaultModelBootstrapResult.failed(
          failure: DefaultModelBootstrapFailure.invalidManifest,
          details: '$e',
        ),
      );
    }
  }

  bool _validateManifestContract(_BundleManifest manifest) {
    final ids = manifest.archetypes.map((a) => a.id).toSet();
    for (final required in _requiredArchetypeIds) {
      if (!ids.contains(required)) {
        return false;
      }
    }

    if (!ids.contains(manifest.defaultArchetype)) {
      return false;
    }

    for (final archetype in manifest.archetypes) {
      final modelFileCount =
          archetype.files.where((f) => f.toLowerCase().endsWith('.model3.json')).length;
      if (modelFileCount != 1) {
        return false;
      }
      if (!archetype.files.contains(archetype.modelFile)) {
        return false;
      }

      final hasMoc3 = archetype.files.any((f) => f.toLowerCase().endsWith('.moc3'));
      final hasTexture = archetype.files.any(
        (f) => f.toLowerCase().endsWith('.png') &&
            (f.startsWith('textures/') || !f.contains('/')),
      );
      final hasMotion = archetype.files.any(
        (f) => f.toLowerCase().endsWith('.motion3.json'),
      );

      if (!hasMoc3 || !hasTexture || !hasMotion) {
        return false;
      }
    }

    return true;
  }

  Future<bool> _validateBootstrappedRoot(
    String live2dRootPath,
    _BundleManifest manifest,
  ) async {
    final live2dRoot = Directory(live2dRootPath);
    if (!await live2dRoot.exists()) {
      return false;
    }

    for (final archetype in manifest.archetypes) {
      final archetypeDir = Directory(path.join(live2dRootPath, archetype.id));
      if (!await archetypeDir.exists()) {
        return false;
      }

      final modelFilePath = path.join(archetypeDir.path, archetype.modelFile);
      if (!await File(modelFilePath).exists()) {
        return false;
      }

      var mocCount = 0;
      var textureCount = 0;
      var motionCount = 0;
      var model3Count = 0;

      await for (final entity
          in archetypeDir.list(recursive: true, followLinks: false)) {
        if (entity is! File) {
          continue;
        }
        final relative = path.relative(entity.path, from: archetypeDir.path);
        final normalized = relative.replaceAll('\\', '/').toLowerCase();
        if (normalized.endsWith('.model3.json')) {
          model3Count += 1;
        } else if (normalized.endsWith('.moc3')) {
          mocCount += 1;
        } else if (normalized.endsWith('.motion3.json')) {
          motionCount += 1;
        } else if (normalized.endsWith('.png') &&
            (normalized.startsWith('textures/') || !normalized.contains('/'))) {
          textureCount += 1;
        }
      }

      if (model3Count != 1 || mocCount < 1 || textureCount < 1 || motionCount < 1) {
        return false;
      }
    }

    return true;
  }

  String _defaultModelPath(_BundleManifest manifest) {
    final defaultArchetype = manifest.archetypes.firstWhere(
      (a) => a.id == manifest.defaultArchetype,
    );
    return '${defaultArchetype.id}/${defaultArchetype.modelFile}';
  }

  Future<bool> fileExists(String filePath) async {
    try {
      return await File(filePath).exists();
    } catch (e) {
      return false;
    }
  }

  Future<List<String>> listDirectory(String dirPath, {bool recursive = false}) async {
    final result = <String>[];
    
    try {
      final dir = Directory(dirPath);
      if (!await dir.exists()) {
        live2dLog.warning(_tag, '디렉토리 없음', details: dirPath);
        return result;
      }

      await for (final entity in dir.list(recursive: recursive, followLinks: false)) {
        result.add(entity.path);
      }

      live2dLog.debug(
        _tag,
        '디렉토리 내용 (${result.length}개)',
        details: dirPath,
      );
    } catch (e) {
      live2dLog.error(_tag, '디렉토리 나열 실패', error: e, details: dirPath);
    }

    return result;
  }

  String? get folderDisplayName {
    return FolderValidator.displayName(_currentFolderPath);
  }
}

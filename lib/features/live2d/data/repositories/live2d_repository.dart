// ============================================================================
// ============================================================================
// ============================================================================

import 'dart:io';
import 'package:path/path.dart' as path;
import '../models/live2d_model_info.dart';
import '../models/model3_data.dart';
import '../services/live2d_log_service.dart';
import '../services/model3_json_parser.dart';

class Live2DRepository {
  static final Live2DRepository _instance = Live2DRepository._internal();
  factory Live2DRepository() => _instance;
  Live2DRepository._internal();

  static const String _tag = 'Repository';

  List<Live2DModelInfo> _cachedModels = [];
  String? _lastScannedPath;
  final Model3JsonParser _model3Parser = Model3JsonParser();

  // === Getter ===
  List<Live2DModelInfo> get models => List.unmodifiable(_cachedModels);
  int get modelCount => _cachedModels.length;
  bool get hasModels => _cachedModels.isNotEmpty;

  /// 
  /// 
  /// └── Live2D/
  ///     ├── Hiyori/
  ///     │   └── ...
  ///     └── Mao/
  ///         ├── Mao.model3.json
  ///         └── ...
  /// 
  /// ├── Hiyori/
  /// │   ├── Hiyori.model3.json
  /// │   └── ...
  /// └── Mao/
  ///     ├── Mao.model3.json
  ///     └── ...
  Future<List<Live2DModelInfo>> scanModels(String folderPath) async {
    live2dLog.info(_tag, '모델 스캔 시작', details: folderPath);
    _cachedModels = [];
    _lastScannedPath = folderPath;

    try {
      final rootDir = Directory(folderPath);
      if (!await rootDir.exists()) {
        live2dLog.error(_tag, '폴더가 존재하지 않음', details: folderPath);
        return _cachedModels;
      }

      String scanPath = folderPath;
      final live2dDir = Directory(path.join(folderPath, 'Live2D'));
      if (await live2dDir.exists()) {
        scanPath = live2dDir.path;
        live2dLog.info(_tag, 'Live2D 하위 폴더 사용', details: scanPath);
      }

      final dir = Directory(scanPath);
      await for (final entity in dir.list(recursive: true, followLinks: false)) {
        if (entity is File) {
          final fileName = path.basename(entity.path).toLowerCase();
          
          if (fileName.endsWith('.model3.json') || fileName.endsWith('.model.json')) {
            final modelInfo = await Live2DModelInfo.fromModelFile(entity, scanPath);
            
            if (modelInfo != null) {
              _cachedModels.add(modelInfo);
              live2dLog.debug(
                _tag,
                '모델 발견: ${modelInfo.name}',
                details: modelInfo.relativePath,
              );
            }
          }
        }
      }

      _cachedModels.sort((a, b) => 
          a.name.toLowerCase().compareTo(b.name.toLowerCase()));

      live2dLog.info(
        _tag,
        '스캔 완료',
        details: '${_cachedModels.length}개 모델 발견',
      );

      return _cachedModels;
    } catch (e, stack) {
      live2dLog.error(
        _tag,
        '모델 스캔 실패',
        error: e,
        stackTrace: stack,
      );
      return _cachedModels;
    }
  }

  Live2DModelInfo? getModelById(String id) {
    try {
      return _cachedModels.firstWhere((m) => m.id == id);
    } catch (e) {
      return null;
    }
  }

  Live2DModelInfo? getModelByLegacyId(String legacyId) {
    try {
      return _cachedModels.firstWhere((m) => m.legacyId == legacyId);
    } catch (e) {
      return null;
    }
  }

  Live2DModelInfo? getModelByPath(String relativePath) {
    final normalizedPath = relativePath.replaceAll('\\', '/');
    try {
      return _cachedModels.firstWhere(
        (m) => m.normalizedRelativePath == normalizedPath,
      );
    } catch (e) {
      return null;
    }
  }

  Future<bool> validateModel(String modelPath) async {
    try {
      final file = File(modelPath);
      
      if (!await file.exists()) {
        live2dLog.warning(_tag, '모델 파일 없음', details: modelPath);
        return false;
      }

      final content = await file.readAsString();
      
      if (!content.trim().startsWith('{') || !content.trim().endsWith('}')) {
        live2dLog.warning(_tag, '유효하지 않은 JSON 형식', details: modelPath);
        return false;
      }

      if (modelPath.toLowerCase().endsWith('.model3.json')) {
        if (!content.contains('"FileReferences"') && 
            !content.contains('"Moc"')) {
          live2dLog.warning(
            _tag,
            'model3.json 필수 필드 없음',
            details: modelPath,
          );
          return false;
        }
      }

      live2dLog.debug(_tag, '모델 검증 통과', details: modelPath);
      return true;
    } catch (e) {
      live2dLog.error(_tag, '모델 검증 실패', error: e, details: modelPath);
      return false;
    }
  }

  Future<Map<String, dynamic>> getModelDetails(String modelPath) async {
    final result = <String, dynamic>{
      'motions': <String>[],
      'expressions': <String>[],
      'textures': <String>[],
    };

    try {
      final file = File(modelPath);
      if (!await file.exists()) return result;

      final content = await file.readAsString();
      
      final motionMatches = RegExp(r'"(\w+)":\s*\[').allMatches(content);
      for (final match in motionMatches) {
        final groupName = match.group(1);
        if (groupName != null && 
            !['FileReferences', 'Moc', 'Textures', 'Physics', 'Expressions']
                .contains(groupName)) {
          (result['motions'] as List<String>).add(groupName);
        }
      }

      live2dLog.debug(_tag, '모델 상세 정보 로드', details: modelPath);
    } catch (e) {
      live2dLog.warning(_tag, '모델 상세 정보 로드 실패', error: e);
    }

    return result;
  }

  Future<Model3Data> getParsedModelData(String modelPath) async {
    return _model3Parser.parseFile(modelPath);
  }

  void clearCache() {
    _cachedModels = [];
    _lastScannedPath = null;
    live2dLog.debug(_tag, '캐시 클리어됨');
  }

  Future<List<Live2DModelInfo>> rescan() async {
    if (_lastScannedPath == null) {
      live2dLog.warning(_tag, '재스캔 불가: 이전 스캔 경로 없음');
      return _cachedModels;
    }
    return scanModels(_lastScannedPath!);
  }
}

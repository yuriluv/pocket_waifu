// ============================================================================
// Live2D 리포지토리 (Live2D Repository)
// ============================================================================
// 모델 파일 시스템 접근을 담당합니다.
// 선택된 폴더에서 모델을 스캔하고 관리합니다.
// ============================================================================

import 'dart:io';
import 'package:path/path.dart' as path;
import '../models/live2d_model_info.dart';
import '../services/live2d_log_service.dart';

/// 모델 파일 시스템 접근 담당 리포지토리 (싱글톤)
class Live2DRepository {
  // === 싱글톤 패턴 ===
  static final Live2DRepository _instance = Live2DRepository._internal();
  factory Live2DRepository() => _instance;
  Live2DRepository._internal();

  static const String _tag = 'Repository';

  // === 캐시된 모델 목록 ===
  List<Live2DModelInfo> _cachedModels = [];
  String? _lastScannedPath;

  // === Getter ===
  List<Live2DModelInfo> get models => List.unmodifiable(_cachedModels);
  int get modelCount => _cachedModels.length;
  bool get hasModels => _cachedModels.isNotEmpty;

  /// 선택된 폴더 하위의 모든 모델 스캔
  /// 
  /// [folderPath]: 스캔할 폴더 경로
  /// 
  /// 폴더 구조 예시:
  /// [선택한 폴더]/
  /// └── Live2D/
  ///     ├── Hiyori/
  ///     │   ├── Hiyori.model3.json  ← 이걸 찾음
  ///     │   └── ...
  ///     └── Mao/
  ///         ├── Mao.model3.json
  ///         └── ...
  /// 
  /// 또는:
  /// [선택한 폴더]/
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
      // 폴더 존재 확인
      final rootDir = Directory(folderPath);
      if (!await rootDir.exists()) {
        live2dLog.error(_tag, '폴더가 존재하지 않음', details: folderPath);
        return _cachedModels;
      }

      // Live2D 하위 폴더 확인
      String scanPath = folderPath;
      final live2dDir = Directory(path.join(folderPath, 'Live2D'));
      if (await live2dDir.exists()) {
        scanPath = live2dDir.path;
        live2dLog.info(_tag, 'Live2D 하위 폴더 사용', details: scanPath);
      }

      // 재귀적으로 모델 파일 찾기
      final dir = Directory(scanPath);
      await for (final entity in dir.list(recursive: true, followLinks: false)) {
        if (entity is File) {
          final fileName = path.basename(entity.path).toLowerCase();
          
          // .model3.json 또는 .model.json 파일 찾기
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

      // 이름순 정렬
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

  /// 모델 ID로 모델 찾기
  Live2DModelInfo? getModelById(String id) {
    try {
      return _cachedModels.firstWhere((m) => m.id == id);
    } catch (e) {
      return null;
    }
  }

  /// 상대 경로로 모델 찾기
  Live2DModelInfo? getModelByPath(String relativePath) {
    try {
      return _cachedModels.firstWhere((m) => m.relativePath == relativePath);
    } catch (e) {
      return null;
    }
  }

  /// 모델 파일 유효성 검증
  Future<bool> validateModel(String modelPath) async {
    try {
      final file = File(modelPath);
      
      // 파일 존재 확인
      if (!await file.exists()) {
        live2dLog.warning(_tag, '모델 파일 없음', details: modelPath);
        return false;
      }

      // JSON 파일 읽기 시도
      final content = await file.readAsString();
      
      // 기본 JSON 구조 확인 (최소한 { 와 } 가 있어야 함)
      if (!content.trim().startsWith('{') || !content.trim().endsWith('}')) {
        live2dLog.warning(_tag, '유효하지 않은 JSON 형식', details: modelPath);
        return false;
      }

      // model3.json 필수 필드 확인
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

  /// 모델 디렉토리에서 모션/표정 목록 추출 (선택적)
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
      
      // 간단한 문자열 검색으로 모션 그룹 찾기
      // (실제로는 JSON 파싱이 필요하지만, 간단한 버전)
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

  /// 캐시 클리어
  void clearCache() {
    _cachedModels = [];
    _lastScannedPath = null;
    live2dLog.debug(_tag, '캐시 클리어됨');
  }

  /// 마지막 스캔 경로로 다시 스캔
  Future<List<Live2DModelInfo>> rescan() async {
    if (_lastScannedPath == null) {
      live2dLog.warning(_tag, '재스캔 불가: 이전 스캔 경로 없음');
      return _cachedModels;
    }
    return scanModels(_lastScannedPath!);
  }
}

// ============================================================================
// Live2D 서비스 (Live2D Service)
// ============================================================================
// 이 파일은 Live2D 모델 파일들을 관리합니다.
// 사용자가 선택한 폴더를 스캔하고 모델 목록을 제공합니다.
// 
// 주요 기능:
// - 사용자가 선택한 폴더에서 모델 스캔
// - .model3.json 파일 재귀적 스캔
// - 모델 정보 제공
// ============================================================================

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:shared_preferences/shared_preferences.dart';

/// Live2D 모델 정보를 담는 클래스
class Live2DModel {
  final String name;              // 모델 이름 (폴더명)
  final String modelFilePath;     // .model3.json 파일 전체 경로
  final String relativePath;      // Live2D 루트 기준 상대 경로
  final String folderPath;        // 모델 폴더 경로
  final DateTime? lastModified;   // 마지막 수정일

  Live2DModel({
    required this.name,
    required this.modelFilePath,
    required this.relativePath,
    required this.folderPath,
    this.lastModified,
  });

  @override
  String toString() => 'Live2DModel(name: $name, path: $relativePath)';
}

/// Live2D 모델 파일들을 관리하는 싱글톤 서비스
class Live2DService {
  // === 싱글톤 패턴 ===
  static final Live2DService _instance = Live2DService._internal();
  factory Live2DService() => _instance;
  Live2DService._internal();

  // === 저장 키 상수 ===
  static const String _selectedModelKey = 'live2d_selected_model';
  static const String _overlaySizeKey = 'live2d_overlay_size';
  static const String _overlayEnabledKey = 'live2d_overlay_enabled';
  static const String _modelFolderPathKey = 'live2d_model_folder_path';

  // === 상태 변수 ===
  String? _live2dRootPath;            // Live2D 루트 경로 (사용자가 선택한 폴더)
  List<Live2DModel> _models = [];     // 스캔된 모델 목록
  String? _selectedModelPath;         // 선택된 모델의 상대 경로
  double _overlaySize = 1.0;          // 오버레이 크기 배율
  bool _overlayEnabled = false;       // 오버레이 활성화 여부

  // === Getter ===
  String? get live2dRootPath => _live2dRootPath;
  List<Live2DModel> get models => List.unmodifiable(_models);
  String? get selectedModelPath => _selectedModelPath;
  double get overlaySize => _overlaySize;
  bool get overlayEnabled => _overlayEnabled;

  /// 선택된 모델 정보 가져오기
  Live2DModel? get selectedModel {
    if (_selectedModelPath == null) return null;
    try {
      return _models.firstWhere(
        (model) => model.relativePath == _selectedModelPath,
      );
    } catch (e) {
      return null;
    }
  }

  /// 서비스를 초기화합니다
  /// 앱 시작 시 호출해야 합니다
  Future<void> initialize() async {
    debugPrint('[Live2D] 서비스 초기화 시작...');

    // 저장된 설정 불러오기
    await _loadSettings();
    
    // 저장된 폴더 경로가 있고 유효하면 모델 스캔
    if (_live2dRootPath != null) {
      final dir = Directory(_live2dRootPath!);
      if (await dir.exists()) {
        await scanModels();
        
        // 저장된 선택 모델이 실제로 존재하는지 검증
        if (_selectedModelPath != null) {
          final modelExists = _models.any((m) => m.relativePath == _selectedModelPath);
          if (!modelExists) {
            debugPrint('[Live2D] ⚠️ 저장된 모델 경로가 더 이상 유효하지 않습니다: $_selectedModelPath');
            debugPrint('[Live2D] ⚠️ 선택된 모델을 초기화합니다.');
            _selectedModelPath = null;
            await _saveSettings();
          } else {
            debugPrint('[Live2D] ✓ 저장된 모델 경로 유효: $_selectedModelPath');
          }
        }
      } else {
        debugPrint('[Live2D] 저장된 폴더가 더 이상 존재하지 않습니다: $_live2dRootPath');
        _live2dRootPath = null;
        _selectedModelPath = null;
        await _saveSettings();
      }
    }

    debugPrint('[Live2D] 초기화 완료. 루트: $_live2dRootPath');
    debugPrint('[Live2D] 발견된 모델 수: ${_models.length}');
    debugPrint('[Live2D] 선택된 모델: $_selectedModelPath');
  }

  /// 모델 폴더 경로를 설정합니다 (사용자가 file_picker로 선택)
  Future<void> setModelFolderPath(String folderPath) async {
    _live2dRootPath = folderPath;
    await _saveSettings();
    debugPrint('[Live2D] 모델 폴더 설정됨: $folderPath');
    
    // 새 폴더에서 모델 스캔
    await scanModels();
  }

  /// Live2D 루트 디렉토리를 재귀적으로 스캔하여 모델을 찾습니다
  Future<void> scanModels() async {
    _models.clear();

    if (_live2dRootPath == null) {
      debugPrint('[Live2D] 루트 경로가 설정되지 않았습니다.');
      return;
    }

    final rootDir = Directory(_live2dRootPath!);
    if (!await rootDir.exists()) {
      debugPrint('[Live2D] 루트 디렉토리가 존재하지 않습니다: $_live2dRootPath');
      return;
    }

    debugPrint('[Live2D] 모델 스캔 시작: $_live2dRootPath');

    try {
      // 재귀적으로 .model3.json 파일 찾기
      await for (final entity in rootDir.list(recursive: true, followLinks: false)) {
        if (entity is File && entity.path.endsWith('.model3.json')) {
          final modelFile = entity;
          
          // 모델 정보 추출
          final modelFilePath = modelFile.path;
          final folderPath = path.dirname(modelFilePath);
          final modelName = path.basename(folderPath);  // 폴더명을 모델 이름으로
          final relativePath = path.relative(modelFilePath, from: _live2dRootPath!);
          
          // 디버그: 경로 정보 출력
          debugPrint('[Live2D] === 모델 발견 ===');
          debugPrint('[Live2D]   절대 경로: $modelFilePath');
          debugPrint('[Live2D]   루트 경로: $_live2dRootPath');
          debugPrint('[Live2D]   상대 경로: $relativePath');
          
          // 파일 수정일
          final stat = await modelFile.stat();
          
          final model = Live2DModel(
            name: modelName,
            modelFilePath: modelFilePath,
            relativePath: relativePath,
            folderPath: folderPath,
            lastModified: stat.modified,
          );

          _models.add(model);
          debugPrint('[Live2D] 모델 발견: $modelName ($relativePath)');
        }
      }

      // 이름순 정렬
      _models.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      
      debugPrint('[Live2D] 스캔 완료. 총 ${_models.length}개 모델 발견');
    } catch (e) {
      debugPrint('[Live2D] 모델 스캔 실패: $e');
    }
  }

  /// 저장된 설정을 불러옵니다
  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _live2dRootPath = prefs.getString(_modelFolderPathKey);
      _selectedModelPath = prefs.getString(_selectedModelKey);
      _overlaySize = prefs.getDouble(_overlaySizeKey) ?? 1.0;
      _overlayEnabled = prefs.getBool(_overlayEnabledKey) ?? false;
      
      debugPrint('[Live2D] 설정 불러오기 완료');
      debugPrint('  - 모델 폴더: $_live2dRootPath');
      debugPrint('  - 선택된 모델: $_selectedModelPath');
      debugPrint('  - 오버레이 크기: $_overlaySize');
      debugPrint('  - 오버레이 활성화: $_overlayEnabled');
    } catch (e) {
      debugPrint('[Live2D] 설정 불러오기 실패: $e');
    }
  }

  /// 설정을 저장합니다
  Future<void> _saveSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      if (_live2dRootPath != null) {
        await prefs.setString(_modelFolderPathKey, _live2dRootPath!);
      } else {
        await prefs.remove(_modelFolderPathKey);
      }
      
      if (_selectedModelPath != null) {
        await prefs.setString(_selectedModelKey, _selectedModelPath!);
      } else {
        await prefs.remove(_selectedModelKey);
      }
      
      await prefs.setDouble(_overlaySizeKey, _overlaySize);
      await prefs.setBool(_overlayEnabledKey, _overlayEnabled);
    } catch (e) {
      debugPrint('[Live2D] 설정 저장 실패: $e');
    }
  }

  /// 모델을 선택합니다
  Future<void> selectModel(String? relativePath) async {
    _selectedModelPath = relativePath;
    await _saveSettings();
    debugPrint('[Live2D] 모델 선택됨: $relativePath');
  }

  /// 오버레이 크기를 설정합니다
  Future<void> setOverlaySize(double size) async {
    _overlaySize = size.clamp(0.5, 3.0);  // 0.5x ~ 3.0x 범위 제한
    await _saveSettings();
    debugPrint('[Live2D] 오버레이 크기 설정: $_overlaySize');
  }

  /// 오버레이 활성화 상태를 설정합니다
  Future<void> setOverlayEnabled(bool enabled) async {
    _overlayEnabled = enabled;
    await _saveSettings();
    debugPrint('[Live2D] 오버레이 활성화: $_overlayEnabled');
  }

  /// 특정 모델의 전체 경로를 반환합니다
  String? getModelFullPath(String relativePath) {
    if (_live2dRootPath == null) return null;
    return path.join(_live2dRootPath!, relativePath);
  }

  /// 모델이 존재하는지 확인합니다
  Future<bool> modelExists(String relativePath) async {
    final fullPath = getModelFullPath(relativePath);
    if (fullPath == null) return false;
    return await File(fullPath).exists();
  }
}

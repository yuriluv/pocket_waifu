// ============================================================================
// 모델 스캐너 서비스 (Model Scanner Service)
// ============================================================================
// 지정된 live2d 폴더를 스캔하여 모든 모델 폴더를 찾습니다.
// 각 폴더에서 .model3.json 파일을 찾아 모델 목록을 반환합니다.
// ============================================================================

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;

/// Live2D 모델 정보를 담는 클래스
class ModelInfo {
  final String name;           // 표시 이름 (폴더명)
  final String relativePath;   // 서버 기준 상대 경로 (예: "hiyori/hiyori.model3.json")
  final String absolutePath;   // 파일 절대 경로
  
  ModelInfo({
    required this.name,
    required this.relativePath,
    required this.absolutePath,
  });

  @override
  String toString() => 'ModelInfo(name: $name, relativePath: $relativePath)';
}

/// Live2D 모델 파일을 스캔하는 서비스
class ModelScannerService {
  // === 싱글톤 패턴 ===
  static final ModelScannerService _instance = ModelScannerService._internal();
  factory ModelScannerService() => _instance;
  ModelScannerService._internal();

  /// live2d 폴더를 스캔하여 모델 목록 반환
  /// 
  /// [live2dFolderPath]: live2d 모델들이 있는 폴더 경로
  /// 예: /storage/emulated/0/MyApp/live2d
  Future<List<ModelInfo>> scanModels(String live2dFolderPath) async {
    final models = <ModelInfo>[];
    final dir = Directory(live2dFolderPath);
    
    if (!await dir.exists()) {
      debugPrint('[ModelScanner] 폴더가 존재하지 않음: $live2dFolderPath');
      return models;
    }
    
    debugPrint('[ModelScanner] 스캔 시작: $live2dFolderPath');
    
    try {
      await for (final entity in dir.list(followLinks: false)) {
        if (entity is Directory) {
          final folderName = path.basename(entity.path);
          final modelFile = await _findModelFile(entity);
          
          if (modelFile != null) {
            final fileName = path.basename(modelFile.path);
            models.add(ModelInfo(
              name: folderName,
              relativePath: '$folderName/$fileName',
              absolutePath: modelFile.path,
            ));
            debugPrint('[ModelScanner] 모델 발견: $folderName/$fileName');
          }
        }
      }
    } catch (e) {
      debugPrint('[ModelScanner] 스캔 오류: $e');
    }
    
    // 이름순 정렬
    models.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    
    debugPrint('[ModelScanner] 총 ${models.length}개 모델 발견');
    return models;
  }

  /// 재귀적으로 모델을 스캔합니다 (중첩 폴더 지원)
  /// 
  /// [live2dFolderPath]: live2d 모델들이 있는 폴더 경로
  Future<List<ModelInfo>> scanModelsRecursive(String live2dFolderPath) async {
    final models = <ModelInfo>[];
    final dir = Directory(live2dFolderPath);
    
    if (!await dir.exists()) {
      debugPrint('[ModelScanner] 폴더가 존재하지 않음: $live2dFolderPath');
      return models;
    }
    
    debugPrint('[ModelScanner] 재귀 스캔 시작: $live2dFolderPath');
    
    try {
      await for (final entity in dir.list(recursive: true, followLinks: false)) {
        if (entity is File && entity.path.endsWith('.model3.json')) {
          final modelFilePath = entity.path;
          final folderPath = path.dirname(modelFilePath);
          final folderName = path.basename(folderPath);
          final relativePath = path.relative(modelFilePath, from: live2dFolderPath);
          
          models.add(ModelInfo(
            name: folderName,
            relativePath: relativePath.replaceAll('\\', '/'), // Windows 경로 정규화
            absolutePath: modelFilePath,
          ));
          
          debugPrint('[ModelScanner] 모델 발견: $relativePath');
        }
      }
    } catch (e) {
      debugPrint('[ModelScanner] 재귀 스캔 오류: $e');
    }
    
    // 이름순 정렬
    models.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    
    debugPrint('[ModelScanner] 총 ${models.length}개 모델 발견');
    return models;
  }
  
  /// 폴더 내에서 .model3.json 파일 찾기
  Future<File?> _findModelFile(Directory dir) async {
    try {
      await for (final file in dir.list(followLinks: false)) {
        if (file is File && file.path.endsWith('.model3.json')) {
          return file;
        }
      }
    } catch (e) {
      debugPrint('[ModelScanner] 폴더 읽기 실패: ${dir.path}');
    }
    return null;
  }
  
  /// 특정 폴더가 유효한 Live2D 모델 폴더인지 확인
  Future<bool> isValidModelFolder(String folderPath) async {
    final dir = Directory(folderPath);
    if (!await dir.exists()) return false;
    
    final modelFile = await _findModelFile(dir);
    return modelFile != null;
  }
}

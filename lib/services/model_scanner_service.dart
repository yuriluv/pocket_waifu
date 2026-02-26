// ============================================================================
// ============================================================================
// ============================================================================

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;

class ModelInfo {
  final String name;
  final String relativePath;
  final String absolutePath;
  
  ModelInfo({
    required this.name,
    required this.relativePath,
    required this.absolutePath,
  });

  @override
  String toString() => 'ModelInfo(name: $name, relativePath: $relativePath)';
}

class ModelScannerService {
  static final ModelScannerService _instance = ModelScannerService._internal();
  factory ModelScannerService() => _instance;
  ModelScannerService._internal();

  /// 
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
    
    models.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    
    debugPrint('[ModelScanner] 총 ${models.length}개 모델 발견');
    return models;
  }

  /// 
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
            relativePath: relativePath.replaceAll('\\', '/'),
            absolutePath: modelFilePath,
          ));
          
          debugPrint('[ModelScanner] 모델 발견: $relativePath');
        }
      }
    } catch (e) {
      debugPrint('[ModelScanner] 재귀 스캔 오류: $e');
    }
    
    models.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    
    debugPrint('[ModelScanner] 총 ${models.length}개 모델 발견');
    return models;
  }
  
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
  
  Future<bool> isValidModelFolder(String folderPath) async {
    final dir = Directory(folderPath);
    if (!await dir.exists()) return false;
    
    final modelFile = await _findModelFile(dir);
    return modelFile != null;
  }
}

// ============================================================================
// Live2D 모델 정보 (Live2D Model Info)
// ============================================================================
// Live2D 모델의 정보를 담는 불변 데이터 클래스입니다.
// 모델 폴더를 스캔할 때 생성됩니다.
// ============================================================================

import 'dart:io';
import 'package:path/path.dart' as path;

/// Live2D 모델 타입 (Cubism 버전)
enum Live2DModelType {
  cubism2,  // .model.json
  cubism3,  // .model3.json
  cubism4,  // .model3.json (Cubism 4도 model3.json 사용)
  unknown,
}

/// Live2D 모델 정보를 담는 불변 데이터 클래스
class Live2DModelInfo {
  /// 고유 식별자 (폴더명 기반)
  final String id;

  /// 표시용 이름
  final String name;

  /// model3.json 또는 model.json 절대 경로
  final String modelFilePath;

  /// Live2D 루트 폴더 기준 상대 경로
  final String relativePath;

  /// 모델 폴더 절대 경로
  final String folderPath;

  /// 썸네일 이미지 경로 (없으면 null)
  final String? thumbnailPath;

  /// 모델 타입 (Cubism 버전)
  final Live2DModelType type;

  /// 마지막 수정일
  final DateTime? lastModified;

  const Live2DModelInfo({
    required this.id,
    required this.name,
    required this.modelFilePath,
    required this.relativePath,
    required this.folderPath,
    this.thumbnailPath,
    required this.type,
    this.lastModified,
  });

  /// 디렉토리에서 모델 정보 추출
  /// 
  /// [modelFile]: model.json 또는 model3.json 파일
  /// [rootPath]: Live2D 루트 폴더 경로
  static Future<Live2DModelInfo?> fromModelFile(
    File modelFile,
    String rootPath,
  ) async {
    try {
      final modelFilePath = modelFile.path;
      final folderPath = path.dirname(modelFilePath);
      final folderName = path.basename(folderPath);
      final fileName = path.basename(modelFilePath).toLowerCase();

      // 모델 타입 결정
      Live2DModelType type;
      if (fileName.endsWith('.model3.json')) {
        type = Live2DModelType.cubism3; // Cubism 3/4
      } else if (fileName.endsWith('.model.json')) {
        type = Live2DModelType.cubism2;
      } else {
        type = Live2DModelType.unknown;
      }

      // 상대 경로 계산
      final relativePath = path.relative(modelFilePath, from: rootPath);

      // ID 생성 (폴더명 기반, 특수문자 제거)
      final id = folderName
          .toLowerCase()
          .replaceAll(RegExp(r'[^a-z0-9_]'), '_');

      // 썸네일 찾기
      final thumbnailPath = await _findThumbnail(folderPath);

      // 파일 수정일
      final stat = await modelFile.stat();

      return Live2DModelInfo(
        id: id,
        name: folderName,
        modelFilePath: modelFilePath,
        relativePath: relativePath,
        folderPath: folderPath,
        thumbnailPath: thumbnailPath,
        type: type,
        lastModified: stat.modified,
      );
    } catch (e) {
      return null;
    }
  }

  /// 폴더 내에서 썸네일 이미지 찾기
  static Future<String?> _findThumbnail(String folderPath) async {
    final dir = Directory(folderPath);
    if (!await dir.exists()) return null;

    // 우선순위: icon.png > thumbnail.png > preview.png > 첫 번째 png/jpg
    final priorityNames = ['icon.png', 'thumbnail.png', 'preview.png'];

    try {
      await for (final entity in dir.list(recursive: false)) {
        if (entity is File) {
          final fileName = path.basename(entity.path).toLowerCase();
          
          // 우선순위 이름 확인
          for (final priorityName in priorityNames) {
            if (fileName == priorityName) {
              return entity.path;
            }
          }
        }
      }

      // 우선순위 이름이 없으면 첫 번째 이미지 파일
      await for (final entity in dir.list(recursive: false)) {
        if (entity is File) {
          final ext = path.extension(entity.path).toLowerCase();
          if (ext == '.png' || ext == '.jpg' || ext == '.jpeg') {
            return entity.path;
          }
        }
      }
    } catch (e) {
      // 무시
    }

    return null;
  }

  /// JSON으로 직렬화
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'modelFilePath': modelFilePath,
      'relativePath': relativePath,
      'folderPath': folderPath,
      'thumbnailPath': thumbnailPath,
      'type': type.name,
      'lastModified': lastModified?.toIso8601String(),
    };
  }

  /// JSON에서 역직렬화
  factory Live2DModelInfo.fromJson(Map<String, dynamic> json) {
    return Live2DModelInfo(
      id: json['id'] as String,
      name: json['name'] as String,
      modelFilePath: json['modelFilePath'] as String,
      relativePath: json['relativePath'] as String,
      folderPath: json['folderPath'] as String,
      thumbnailPath: json['thumbnailPath'] as String?,
      type: Live2DModelType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => Live2DModelType.unknown,
      ),
      lastModified: json['lastModified'] != null
          ? DateTime.parse(json['lastModified'] as String)
          : null,
    );
  }

  @override
  String toString() => 'Live2DModelInfo(id: $id, name: $name, type: ${type.name})';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Live2DModelInfo && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

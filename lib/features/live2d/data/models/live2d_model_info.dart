// ============================================================================
// ============================================================================
// ============================================================================

import 'dart:io';
import 'package:path/path.dart' as path;

enum Live2DModelType {
  cubism2,  // .model.json
  cubism3,  // .model3.json
  cubism4,
  unknown,
}

class Live2DModelInfo {
  final String id;

  final String name;

  final String modelFilePath;

  final String relativePath;

  final String folderPath;

  final String? thumbnailPath;

  final Live2DModelType type;

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

  /// 
  static Future<Live2DModelInfo?> fromModelFile(
    File modelFile,
    String rootPath,
  ) async {
    try {
      final modelFilePath = modelFile.path;
      final folderPath = path.dirname(modelFilePath);
      final folderName = path.basename(folderPath);
      final fileName = path.basename(modelFilePath).toLowerCase();

      Live2DModelType type;
      if (fileName.endsWith('.model3.json')) {
        type = Live2DModelType.cubism3; // Cubism 3/4
      } else if (fileName.endsWith('.model.json')) {
        type = Live2DModelType.cubism2;
      } else {
        type = Live2DModelType.unknown;
      }

      final relativePath = path.relative(modelFilePath, from: rootPath);

      final id = folderName
          .toLowerCase()
          .replaceAll(RegExp(r'[^a-z0-9_]'), '_');

      final thumbnailPath = await _findThumbnail(folderPath);

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

  static Future<String?> _findThumbnail(String folderPath) async {
    final dir = Directory(folderPath);
    if (!await dir.exists()) return null;

    final priorityNames = ['icon.png', 'thumbnail.png', 'preview.png'];

    try {
      await for (final entity in dir.list(recursive: false)) {
        if (entity is File) {
          final fileName = path.basename(entity.path).toLowerCase();
          
          for (final priorityName in priorityNames) {
            if (fileName == priorityName) {
              return entity.path;
            }
          }
        }
      }

      await for (final entity in dir.list(recursive: false)) {
        if (entity is File) {
          final ext = path.extension(entity.path).toLowerCase();
          if (ext == '.png' || ext == '.jpg' || ext == '.jpeg') {
            return entity.path;
          }
        }
      }
    } catch (e) {
    }

    return null;
  }

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

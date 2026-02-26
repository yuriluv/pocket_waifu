import 'dart:io';

enum FolderValidationResult {
  valid,
  pathMissing,
  noModel,
  permissionDenied,
}

class FolderValidator {
  static Future<(FolderValidationResult, int)> validate(
    String path,
    Future<List<dynamic>> Function(String) scanModels,
  ) async {
    final dir = Directory(path);
    if (!await dir.exists()) {
      return (FolderValidationResult.pathMissing, 0);
    }

    try {
      // Trying to list directory to catch permission denied early
      await dir.list().isEmpty;
    } on FileSystemException catch (_) {
      return (FolderValidationResult.permissionDenied, 0);
    }

    try {
      final models = await scanModels(path);
      if (models.isEmpty) {
        return (FolderValidationResult.noModel, 0);
      }
      return (FolderValidationResult.valid, models.length);
    } catch (e) {
      return (FolderValidationResult.permissionDenied, 0);
    }
  }
}

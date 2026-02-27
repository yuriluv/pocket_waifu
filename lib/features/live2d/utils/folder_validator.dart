import 'dart:io';

enum FolderValidationResult {
  valid,
  pathMissing,
  noModel,
  permissionDenied,
}

class FolderValidator {
  static String? normalizePath(String? input) {
    if (input == null) return null;
    final trimmed = input.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  static Future<bool> isExistingDirectory(String? input) async {
    final normalized = normalizePath(input);
    if (normalized == null) return false;
    try {
      return await Directory(normalized).exists();
    } catch (_) {
      return false;
    }
  }

  static String? displayName(String? input) {
    final normalized = normalizePath(input);
    if (normalized == null) return null;
    final parts = normalized.replaceAll('\\', '/').split('/').where((e) => e.isNotEmpty).toList();
    return parts.isEmpty ? normalized : parts.last;
  }

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

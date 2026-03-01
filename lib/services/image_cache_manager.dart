import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

class ImageCacheManager {
  ImageCacheManager._();

  static final ImageCacheManager instance = ImageCacheManager._();

  Future<Directory> _cacheDir() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(path.join(docs.path, 'chat_image_cache'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<String> saveImageBytes({
    required String imageId,
    required Uint8List bytes,
    required String extension,
  }) async {
    final dir = await _cacheDir();
    final safeExt = extension.startsWith('.') ? extension : '.$extension';
    final file = File(path.join(dir.path, '$imageId$safeExt'));
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }

  Future<Uint8List?> loadImageBytes(String filePath) async {
    if (filePath.isEmpty) return null;
    final file = File(filePath);
    if (!await file.exists()) return null;
    return file.readAsBytes();
  }

  Future<String?> loadBase64(String filePath) async {
    final bytes = await loadImageBytes(filePath);
    if (bytes == null) return null;
    return base64Encode(bytes);
  }

  Future<void> deleteFile(String? filePath) async {
    if (filePath == null || filePath.isEmpty) return;
    final file = File(filePath);
    if (await file.exists()) {
      await file.delete();
    }
  }

  Future<void> clearAll() async {
    final dir = await _cacheDir();
    if (await dir.exists()) {
      await dir.delete(recursive: true);
      await dir.create(recursive: true);
    }
  }

  Future<int> totalSizeBytes() async {
    final dir = await _cacheDir();
    if (!await dir.exists()) return 0;

    var total = 0;
    await for (final entity in dir.list(recursive: true, followLinks: false)) {
      if (entity is File) {
        total += await entity.length();
      }
    }
    return total;
  }
}

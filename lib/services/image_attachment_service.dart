import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

import '../models/message.dart';
import 'image_cache_manager.dart';

class ImageAttachmentService {
  ImageAttachmentService._();

  static final ImagePicker _picker = ImagePicker();
  static const Uuid _uuid = Uuid();
  static const int _maxFileBytes = 5 * 1024 * 1024;

  static Future<ImageAttachment?> pickImage(ImageSource source) async {
    final picked = await _picker.pickImage(
      source: source,
      imageQuality: 85,
      maxWidth: 1024,
      maxHeight: 1024,
    );
    if (picked == null) {
      return null;
    }

    final file = File(picked.path);
    final rawBytes = await file.readAsBytes();
    if (rawBytes.length > _maxFileBytes) {
      throw Exception('Image is too large. Please use an image under 5MB.');
    }

    final decoded = await _decodeImage(rawBytes);
    final mimeType = _mimeTypeFromPath(picked.path);
    final imageId = _uuid.v4();
    final cachedPath = await ImageCacheManager.instance.saveImageBytes(
      imageId: imageId,
      bytes: rawBytes,
      extension: _extensionFromMimeType(mimeType),
    );

    return ImageAttachment(
      id: imageId,
      base64Data: base64Encode(rawBytes),
      mimeType: mimeType,
      width: decoded?.width ?? 0,
      height: decoded?.height ?? 0,
      thumbnailPath: cachedPath,
    );
  }

  static Future<ui.Image?> _decodeImage(Uint8List bytes) async {
    try {
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      return frame.image;
    } catch (_) {
      return null;
    }
  }

  static String _mimeTypeFromPath(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.png')) {
      return 'image/png';
    }
    if (lower.endsWith('.webp')) {
      return 'image/webp';
    }
    if (lower.endsWith('.heic')) {
      return 'image/heic';
    }
    return 'image/jpeg';
  }

  static String _extensionFromMimeType(String mimeType) {
    switch (mimeType) {
      case 'image/png':
        return '.png';
      case 'image/webp':
        return '.webp';
      case 'image/heic':
        return '.heic';
      default:
        return '.jpg';
    }
  }
}

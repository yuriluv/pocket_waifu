import 'package:flutter/services.dart';
import 'dart:convert';

import '../models/message.dart';
import 'image_cache_manager.dart';

class ScreenCaptureService {
  static const MethodChannel _channel = MethodChannel(
    'com.pocketwaifu/screen_capture',
  );

  Future<bool> requestPermission() async {
    final granted = await _channel.invokeMethod<bool>('requestPermission');
    return granted ?? false;
  }

  Future<bool> hasPermission() async {
    final granted = await _channel.invokeMethod<bool>('hasPermission');
    return granted ?? false;
  }

  Future<bool> isAvailable() async {
    final available = await _channel.invokeMethod<bool>('isAvailable');
    return available ?? true;
  }

  Future<Map<String, dynamic>?> captureScreen() async {
    final raw = await _channel.invokeMethod<dynamic>('captureScreen');
    if (raw is Map) {
      return Map<String, dynamic>.from(raw);
    }
    return null;
  }

  Future<ImageAttachment?> capture() async {
    final raw = await captureScreen();
    if (raw == null || raw.isEmpty) {
      return null;
    }

    final base64Data = raw['base64Data'];
    if (base64Data is! String || base64Data.isEmpty) {
      return null;
    }

    final mimeTypeRaw = raw['mimeType'];
    final mimeType = mimeTypeRaw is String && mimeTypeRaw.isNotEmpty
        ? mimeTypeRaw
        : 'image/png';
    final imageId = DateTime.now().microsecondsSinceEpoch.toString();
    final bytes = base64Decode(base64Data);
    final cachedPath = await ImageCacheManager.instance.saveImageBytes(
      imageId: imageId,
      bytes: bytes,
      extension: _extensionFromMimeType(mimeType),
    );
    final widthRaw = raw['width'];
    final heightRaw = raw['height'];

    return ImageAttachment(
      id: imageId,
      base64Data: base64Data,
      mimeType: mimeType,
      width: widthRaw is num ? widthRaw.toInt() : 0,
      height: heightRaw is num ? heightRaw.toInt() : 0,
      thumbnailPath: cachedPath,
    );
  }

  String _extensionFromMimeType(String mimeType) {
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

  Future<void> release() async {
    await _channel.invokeMethod<void>('release');
  }
}

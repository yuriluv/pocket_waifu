import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/message.dart';
import 'image_cache_manager.dart';

class AdbScreenCaptureService {
  static const MethodChannel _channel = MethodChannel(
    'com.pocketwaifu/adb_screen_capture',
  );

  Future<bool> isShizukuInstalled() async {
    final installed = await _channel.invokeMethod<bool>('isShizukuInstalled');
    return installed ?? false;
  }

  Future<bool> isShizukuRunning() async {
    final running = await _channel.invokeMethod<bool>('isShizukuRunning');
    return running ?? false;
  }

  Future<bool> hasPermission() async {
    final granted = await _channel.invokeMethod<bool>('hasPermission');
    return granted ?? false;
  }

  Future<bool> requestPermission() async {
    final granted = await _channel.invokeMethod<bool>('requestPermission');
    return granted ?? false;
  }

  Future<Map<String, dynamic>> getConnectionStatus() async {
    final raw = await _channel.invokeMethod<dynamic>('getConnectionStatus');
    if (raw is Map) {
      return Map<String, dynamic>.from(raw);
    }
    return const {
      'installed': false,
      'running': false,
      'permission': false,
    };
  }

  Future<Map<String, dynamic>?> captureScreen({int maxResolution = 0}) async {
    final raw = await _channel.invokeMethod<dynamic>('captureScreen', {
      'maxResolution': maxResolution,
    });
    if (raw is Map) {
      return Map<String, dynamic>.from(raw);
    }
    return null;
  }

  Future<void> openShizukuPlayStore() async {
    await _channel.invokeMethod<void>('openShizukuPlayStore');
  }

  Future<void> openShizukuApp() async {
    await _channel.invokeMethod<void>('openShizukuApp');
  }

  Future<ImageAttachment?> capture({int maxResolution = 0}) async {
    final raw = await captureScreen(maxResolution: maxResolution);
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
}

import 'package:flutter/services.dart';

class ImageOverlayNativeBridge {
  ImageOverlayNativeBridge._();

  static final ImageOverlayNativeBridge instance = ImageOverlayNativeBridge._();

  static const MethodChannel _channel =
      MethodChannel('com.example.flutter_application_1/live2d');

  Future<bool> setOverlayMode(String mode) async {
    try {
      final result = await _channel.invokeMethod<bool>('setOverlayMode', {
        'mode': mode,
      });
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<String> getOverlayMode() async {
    try {
      final result = await _channel.invokeMethod<String>('getOverlayMode');
      if (result == null || result.isEmpty) {
        return 'live2d';
      }
      return result;
    } catch (_) {
      return 'live2d';
    }
  }

  Future<bool> loadOverlayImage(String imagePath) async {
    try {
      final result = await _channel.invokeMethod<bool>('loadOverlayImage', {
        'path': imagePath,
      });
      return result ?? false;
    } catch (_) {
      return false;
    }
  }
}

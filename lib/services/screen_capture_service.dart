import 'package:flutter/services.dart';

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

  Future<String?> captureScreen() async {
    return _channel.invokeMethod<String>('captureScreen');
  }

  Future<void> release() async {
    await _channel.invokeMethod<void>('release');
  }
}

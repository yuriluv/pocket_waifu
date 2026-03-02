import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/screen_share_settings.dart';
import '../services/adb_screen_capture_service.dart';
import '../services/screen_capture_service.dart';

class ScreenShareProvider extends ChangeNotifier {
  static const String _prefsKey = 'screen_share_settings_v1';

  final ScreenCaptureService _captureService = ScreenCaptureService();
  final AdbScreenCaptureService _adbCaptureService = AdbScreenCaptureService();

  ScreenShareSettings _settings = const ScreenShareSettings();
  bool _isLoading = false;

  ScreenShareSettings get settings => _settings;
  bool get isLoading => _isLoading;

  ScreenShareProvider() {
    load();
  }

  Future<void> load() async {
    _isLoading = true;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw != null && raw.isNotEmpty) {
        _settings = ScreenShareSettings.fromMap(
          Map<String, dynamic>.from(jsonDecode(raw) as Map),
        );
      }
      final hasPermission = await _captureService.hasPermission();
      _settings = _settings.copyWith(isPermissionGranted: hasPermission);
      if (_settings.captureMethod == CaptureMethod.adb) {
        final shizukuConnected = await _adbCaptureService.isShizukuRunning();
        _settings = _settings.copyWith(isAdbConnected: shizukuConnected);
      }
    } catch (e) {
      debugPrint('ScreenShareProvider load failed: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> requestPermission() async {
    final granted = await _captureService.requestPermission();
    _settings = _settings.copyWith(isPermissionGranted: granted);
    await _persist();
    notifyListeners();
  }

  Future<void> refreshPermission() async {
    final granted = await _captureService.hasPermission();
    _settings = _settings.copyWith(isPermissionGranted: granted);
    await _persist();
    notifyListeners();
  }

  Future<void> revokePermission() async {
    await _captureService.release();
    final granted = await _captureService.hasPermission();
    _settings = _settings.copyWith(isPermissionGranted: granted);
    await _persist();
    notifyListeners();
  }

  Future<void> setAutoAttachToMessage(bool value) async {
    _settings = _settings.copyWith(autoAttachToMessage: value, autoCapture: value);
    await _persist();
    notifyListeners();
  }

  Future<void> setEnabled(bool value) async {
    _settings = _settings.copyWith(enabled: value);
    await _persist();
    notifyListeners();
  }

  Future<void> setCaptureInterval(int seconds) async {
    final safe = seconds.clamp(5, 600).toInt();
    _settings = _settings.copyWith(captureInterval: safe);
    await _persist();
    notifyListeners();
  }

  Future<void> setAutoCapture(bool value) async {
    _settings = _settings.copyWith(autoCapture: value, autoAttachToMessage: value);
    await _persist();
    notifyListeners();
  }

  Future<void> setImageQuality(ImageQuality quality) async {
    _settings = _settings.copyWith(imageQuality: quality);
    await _persist();
    notifyListeners();
  }

  Future<void> setMaxResolution(int resolution) async {
    _settings = _settings.copyWith(maxResolution: resolution);
    await _persist();
    notifyListeners();
  }

  Future<void> setCaptureMethod(CaptureMethod method) async {
    var isAdbConnected = _settings.isAdbConnected;
    if (method == CaptureMethod.adb) {
      isAdbConnected = await _adbCaptureService.isShizukuRunning();
    }
    _settings = _settings.copyWith(
      captureMethod: method,
      isAdbConnected: isAdbConnected,
    );
    await _persist();
    notifyListeners();
  }

  Future<void> requestAdbPermission() async {
    final granted = await _adbCaptureService.requestPermission();
    final connected = await _adbCaptureService.isShizukuRunning();
    _settings = _settings.copyWith(
      isAdbConnected: connected && granted,
      isPermissionGranted:
          _settings.captureMethod == CaptureMethod.mediaProjection
          ? _settings.isPermissionGranted
          : granted,
    );
    await _persist();
    notifyListeners();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, jsonEncode(_settings.toMap()));
  }
}

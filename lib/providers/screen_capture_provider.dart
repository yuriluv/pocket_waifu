import 'package:flutter/foundation.dart';

import '../models/message.dart';
import '../services/screen_capture_service.dart';

enum ScreenCapturePermissionStatus { unknown, denied, granted, unavailable }

class ScreenCaptureProvider extends ChangeNotifier {
  final ScreenCaptureService _service = ScreenCaptureService();

  ScreenCapturePermissionStatus _permissionStatus =
      ScreenCapturePermissionStatus.unknown;
  bool _isCapturing = false;
  ImageAttachment? _lastCapture;

  bool get hasPermission =>
      _permissionStatus == ScreenCapturePermissionStatus.granted;
  ScreenCapturePermissionStatus get permissionStatus => _permissionStatus;
  bool get isCapturing => _isCapturing;
  ImageAttachment? get lastCapture => _lastCapture;

  Future<void> refreshPermission() async {
    final available = await _service.isAvailable();
    if (!available) {
      _permissionStatus = ScreenCapturePermissionStatus.unavailable;
      notifyListeners();
      return;
    }

    final granted = await _service.hasPermission();
    _permissionStatus = granted
        ? ScreenCapturePermissionStatus.granted
        : ScreenCapturePermissionStatus.denied;
    notifyListeners();
  }

  Future<void> requestPermission() async {
    final available = await _service.isAvailable();
    if (!available) {
      _permissionStatus = ScreenCapturePermissionStatus.unavailable;
      notifyListeners();
      return;
    }

    final granted = await _service.requestPermission();
    _permissionStatus = granted
        ? ScreenCapturePermissionStatus.granted
        : ScreenCapturePermissionStatus.denied;
    notifyListeners();
  }

  Future<ImageAttachment?> capture() async {
    _isCapturing = true;
    notifyListeners();
    try {
      _lastCapture = await _service.capture();
      return _lastCapture;
    } finally {
      _isCapturing = false;
      notifyListeners();
    }
  }

  Future<List<ImageAttachment>> captureAndAttach(
    List<ImageAttachment> currentAttachments, {
    int maxAttachments = 4,
  }) async {
    if (permissionStatus == ScreenCapturePermissionStatus.unavailable) {
      return currentAttachments;
    }

    if (!hasPermission) {
      await requestPermission();
      if (!hasPermission) {
        return currentAttachments;
      }
    }

    final captureImage = await capture();
    if (captureImage == null) {
      return currentAttachments;
    }

    final next = <ImageAttachment>[...currentAttachments];
    if (next.length >= maxAttachments) {
      next.removeAt(0);
    }
    next.add(captureImage);
    return next;
  }
}

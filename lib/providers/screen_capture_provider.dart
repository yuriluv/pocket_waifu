import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../models/message.dart';
import '../services/screen_capture_service.dart';

class ScreenCaptureProvider extends ChangeNotifier {
  final ScreenCaptureService _service = ScreenCaptureService();
  static const Uuid _uuid = Uuid();

  bool _hasPermission = false;
  bool _isCapturing = false;
  ImageAttachment? _lastCapture;

  bool get hasPermission => _hasPermission;
  bool get isCapturing => _isCapturing;
  ImageAttachment? get lastCapture => _lastCapture;

  Future<void> refreshPermission() async {
    _hasPermission = await _service.hasPermission();
    notifyListeners();
  }

  Future<void> requestPermission() async {
    _hasPermission = await _service.requestPermission();
    notifyListeners();
  }

  Future<ImageAttachment?> capture() async {
    _isCapturing = true;
    notifyListeners();
    try {
      final raw = await _service.captureScreen();
      if (raw == null || raw.isEmpty) {
        return null;
      }

      final parsed = _parseCapture(raw);
      if (parsed == null) {
        return null;
      }

      _lastCapture = ImageAttachment(
        id: _uuid.v4(),
        base64Data: parsed.$2,
        mimeType: parsed.$1,
      );
      return _lastCapture;
    } finally {
      _isCapturing = false;
      notifyListeners();
    }
  }

  (String, String)? _parseCapture(String raw) {
    if (raw.startsWith('data:')) {
      final comma = raw.indexOf(',');
      if (comma == -1) return null;
      final meta = raw.substring(5, comma);
      final data = raw.substring(comma + 1);
      final semi = meta.indexOf(';');
      final mimeType = semi == -1 ? meta : meta.substring(0, semi);
      if (mimeType.isEmpty || data.isEmpty) return null;
      return (mimeType, data);
    }

    return ('image/jpeg', raw);
  }
}

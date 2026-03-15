enum ImageQuality { low, medium, high }

enum ScreenshotMode { includeOverlays, excludeOverlays }

class ScreenShareSettings {
  final bool enabled;
  final int captureInterval;
  final bool autoCapture;
  final bool isPermissionGranted;
  final bool autoAttachToMessage;
  final ImageQuality imageQuality;
  final int maxResolution;
  final ScreenshotMode screenshotMode;
  final bool isAdbConnected;

  const ScreenShareSettings({
    this.enabled = false,
    this.captureInterval = 60,
    this.autoCapture = false,
    this.isPermissionGranted = false,
    this.autoAttachToMessage = false,
    this.imageQuality = ImageQuality.medium,
    this.maxResolution = 1080,
    this.screenshotMode = ScreenshotMode.includeOverlays,
    this.isAdbConnected = false,
  });

  ScreenShareSettings copyWith({
    bool? enabled,
    int? captureInterval,
    bool? autoCapture,
    bool? isPermissionGranted,
    bool? autoAttachToMessage,
    ImageQuality? imageQuality,
    int? maxResolution,
    ScreenshotMode? screenshotMode,
    bool? isAdbConnected,
  }) {
    return ScreenShareSettings(
      enabled: enabled ?? this.enabled,
      captureInterval: captureInterval ?? this.captureInterval,
      autoCapture: autoCapture ?? this.autoCapture,
      isPermissionGranted: isPermissionGranted ?? this.isPermissionGranted,
      autoAttachToMessage: autoAttachToMessage ?? this.autoAttachToMessage,
      imageQuality: imageQuality ?? this.imageQuality,
      maxResolution: maxResolution ?? this.maxResolution,
      screenshotMode: screenshotMode ?? this.screenshotMode,
      isAdbConnected: isAdbConnected ?? this.isAdbConnected,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'enabled': enabled,
      'captureInterval': captureInterval,
      'autoCapture': autoCapture,
      'isPermissionGranted': isPermissionGranted,
      'autoAttachToMessage': autoAttachToMessage,
      'imageQuality': imageQuality.name,
      'maxResolution': maxResolution,
      'screenshotMode': screenshotMode.name,
      'isAdbConnected': isAdbConnected,
    };
  }

  factory ScreenShareSettings.fromMap(Map<String, dynamic> map) {
    final autoCapture = map['autoCapture'] == true;
    final screenshotMode = _parseScreenshotMode(
      map['screenshotMode']?.toString(),
      legacyCaptureMethod: map['captureMethod']?.toString(),
    );
    return ScreenShareSettings(
      enabled: map['enabled'] == true,
      captureInterval: map['captureInterval'] is int
          ? map['captureInterval'] as int
          : 60,
      autoCapture: autoCapture,
      isPermissionGranted: map['isPermissionGranted'] == true,
      autoAttachToMessage: map['autoAttachToMessage'] == true || autoCapture,
      imageQuality: _parseQuality(map['imageQuality']?.toString()),
      maxResolution: map['maxResolution'] is int
          ? map['maxResolution'] as int
          : 1080,
      screenshotMode: screenshotMode,
      isAdbConnected: map['isAdbConnected'] == true,
    );
  }

  static ImageQuality _parseQuality(String? raw) {
    return ImageQuality.values.firstWhere(
      (quality) => quality.name == raw,
      orElse: () => ImageQuality.medium,
    );
  }

  static ScreenshotMode _parseScreenshotMode(
    String? raw, {
    String? legacyCaptureMethod,
  }) {
    if (raw != null) {
      return ScreenshotMode.values.firstWhere(
        (mode) => mode.name == raw,
        orElse: () => ScreenshotMode.includeOverlays,
      );
    }

    switch (legacyCaptureMethod) {
      case 'adb':
        return ScreenshotMode.excludeOverlays;
      case 'mediaProjection':
        return ScreenshotMode.includeOverlays;
      default:
        return ScreenshotMode.includeOverlays;
    }
  }
}

enum ImageQuality { low, medium, high }

enum CaptureMethod { mediaProjection, adb }

class ScreenShareSettings {
  final bool enabled;
  final int captureInterval;
  final bool autoCapture;
  final bool isPermissionGranted;
  final bool autoAttachToMessage;
  final ImageQuality imageQuality;
  final int maxResolution;
  final CaptureMethod captureMethod;
  final bool isAdbConnected;

  const ScreenShareSettings({
    this.enabled = false,
    this.captureInterval = 60,
    this.autoCapture = false,
    this.isPermissionGranted = false,
    this.autoAttachToMessage = false,
    this.imageQuality = ImageQuality.medium,
    this.maxResolution = 1080,
    this.captureMethod = CaptureMethod.mediaProjection,
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
    CaptureMethod? captureMethod,
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
      captureMethod: captureMethod ?? this.captureMethod,
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
      'captureMethod': captureMethod.name,
      'isAdbConnected': isAdbConnected,
    };
  }

  factory ScreenShareSettings.fromMap(Map<String, dynamic> map) {
    final autoCapture = map['autoCapture'] == true;
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
      captureMethod: _parseCaptureMethod(map['captureMethod']?.toString()),
      isAdbConnected: map['isAdbConnected'] == true,
    );
  }

  static ImageQuality _parseQuality(String? raw) {
    return ImageQuality.values.firstWhere(
      (quality) => quality.name == raw,
      orElse: () => ImageQuality.medium,
    );
  }

  static CaptureMethod _parseCaptureMethod(String? raw) {
    return CaptureMethod.values.firstWhere(
      (method) => method.name == raw,
      orElse: () => CaptureMethod.mediaProjection,
    );
  }
}

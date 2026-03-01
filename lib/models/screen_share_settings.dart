enum ImageQuality { low, medium, high }

class ScreenShareSettings {
  final bool enabled;
  final int captureInterval;
  final bool autoCapture;
  final bool isPermissionGranted;
  final bool autoAttachToMessage;
  final ImageQuality imageQuality;
  final int maxResolution;

  const ScreenShareSettings({
    this.enabled = false,
    this.captureInterval = 60,
    this.autoCapture = false,
    this.isPermissionGranted = false,
    this.autoAttachToMessage = false,
    this.imageQuality = ImageQuality.medium,
    this.maxResolution = 1080,
  });

  ScreenShareSettings copyWith({
    bool? enabled,
    int? captureInterval,
    bool? autoCapture,
    bool? isPermissionGranted,
    bool? autoAttachToMessage,
    ImageQuality? imageQuality,
    int? maxResolution,
  }) {
    return ScreenShareSettings(
      enabled: enabled ?? this.enabled,
      captureInterval: captureInterval ?? this.captureInterval,
      autoCapture: autoCapture ?? this.autoCapture,
      isPermissionGranted: isPermissionGranted ?? this.isPermissionGranted,
      autoAttachToMessage: autoAttachToMessage ?? this.autoAttachToMessage,
      imageQuality: imageQuality ?? this.imageQuality,
      maxResolution: maxResolution ?? this.maxResolution,
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
    );
  }

  static ImageQuality _parseQuality(String? raw) {
    return ImageQuality.values.firstWhere(
      (quality) => quality.name == raw,
      orElse: () => ImageQuality.medium,
    );
  }
}

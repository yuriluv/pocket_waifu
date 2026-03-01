enum ImageQuality { low, medium, high }

class ScreenShareSettings {
  final bool isPermissionGranted;
  final bool autoAttachToMessage;
  final ImageQuality imageQuality;
  final int maxResolution;

  const ScreenShareSettings({
    this.isPermissionGranted = false,
    this.autoAttachToMessage = false,
    this.imageQuality = ImageQuality.medium,
    this.maxResolution = 1024,
  });

  ScreenShareSettings copyWith({
    bool? isPermissionGranted,
    bool? autoAttachToMessage,
    ImageQuality? imageQuality,
    int? maxResolution,
  }) {
    return ScreenShareSettings(
      isPermissionGranted: isPermissionGranted ?? this.isPermissionGranted,
      autoAttachToMessage: autoAttachToMessage ?? this.autoAttachToMessage,
      imageQuality: imageQuality ?? this.imageQuality,
      maxResolution: maxResolution ?? this.maxResolution,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'isPermissionGranted': isPermissionGranted,
      'autoAttachToMessage': autoAttachToMessage,
      'imageQuality': imageQuality.name,
      'maxResolution': maxResolution,
    };
  }

  factory ScreenShareSettings.fromMap(Map<String, dynamic> map) {
    return ScreenShareSettings(
      isPermissionGranted: map['isPermissionGranted'] == true,
      autoAttachToMessage: map['autoAttachToMessage'] == true,
      imageQuality: _parseQuality(map['imageQuality']?.toString()),
      maxResolution: map['maxResolution'] is int
          ? map['maxResolution'] as int
          : 1024,
    );
  }

  static ImageQuality _parseQuality(String? raw) {
    return ImageQuality.values.firstWhere(
      (quality) => quality.name == raw,
      orElse: () => ImageQuality.medium,
    );
  }
}

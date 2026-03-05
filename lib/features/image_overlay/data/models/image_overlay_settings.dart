import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ImageOverlaySettings {
  static const String prefsKey = 'image_overlay_settings_v1';
  static const double minScale = 0.1;
  static const double maxScale = 20.0;
  static const String overlayModeAdvanced = 'advanced';
  static const String overlayModeBasic = 'basic';

  final bool isEnabled;
  final String? dataFolderPath;
  final String? selectedCharacterFolder;
  final String? selectedEmotionFile;
  final double opacity;
  final bool touchThroughEnabled;
  final int touchThroughAlpha;
  final int overlayWidth;
  final int overlayHeight;
  final int hitboxWidth;
  final int hitboxHeight;
  final double imageScale;
  final double positionX;
  final double positionY;
  final bool syncCharacterNameWithSession;
  final String overlayInteractionMode;

  const ImageOverlaySettings({
    this.isEnabled = false,
    this.dataFolderPath,
    this.selectedCharacterFolder,
    this.selectedEmotionFile,
    this.opacity = 1.0,
    this.touchThroughEnabled = true,
    this.touchThroughAlpha = 80,
    this.overlayWidth = 320,
    this.overlayHeight = 420,
    this.hitboxWidth = 320,
    this.hitboxHeight = 420,
    this.imageScale = 1.0,
    this.positionX = 0.5,
    this.positionY = 0.5,
    this.syncCharacterNameWithSession = false,
    this.overlayInteractionMode = overlayModeAdvanced,
  });

  static Future<ImageOverlaySettings> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(prefsKey);
      if (raw == null || raw.isEmpty) {
        return const ImageOverlaySettings();
      }
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        return const ImageOverlaySettings();
      }
      return ImageOverlaySettings.fromJson(decoded);
    } catch (e) {
      debugPrint('ImageOverlaySettings.load failed: $e');
      return const ImageOverlaySettings();
    }
  }

  Future<void> save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(prefsKey, jsonEncode(toJson()));
    } catch (e) {
      debugPrint('ImageOverlaySettings.save failed: $e');
    }
  }

  ImageOverlaySettings copyWith({
    bool? isEnabled,
    String? dataFolderPath,
    String? selectedCharacterFolder,
    String? selectedEmotionFile,
    double? opacity,
    bool? touchThroughEnabled,
    int? touchThroughAlpha,
    int? overlayWidth,
    int? overlayHeight,
    int? hitboxWidth,
    int? hitboxHeight,
    double? imageScale,
    double? positionX,
    double? positionY,
    bool? syncCharacterNameWithSession,
    String? overlayInteractionMode,
    bool clearDataFolder = false,
    bool clearSelection = false,
  }) {
    final nextOverlayMode = overlayInteractionMode == overlayModeBasic
        ? overlayModeBasic
        : overlayModeAdvanced;
    return ImageOverlaySettings(
      isEnabled: isEnabled ?? this.isEnabled,
      dataFolderPath: clearDataFolder
          ? null
          : (dataFolderPath ?? this.dataFolderPath),
      selectedCharacterFolder: clearSelection
          ? null
          : (selectedCharacterFolder ?? this.selectedCharacterFolder),
      selectedEmotionFile: clearSelection
          ? null
          : (selectedEmotionFile ?? this.selectedEmotionFile),
      opacity: (opacity ?? this.opacity).clamp(0.0, 1.0),
      touchThroughEnabled: touchThroughEnabled ?? this.touchThroughEnabled,
      touchThroughAlpha: (touchThroughAlpha ?? this.touchThroughAlpha)
          .clamp(0, 100)
          .toInt(),
      overlayWidth: (overlayWidth ?? this.overlayWidth)
          .clamp(120, 8192)
          .toInt(),
      overlayHeight: (overlayHeight ?? this.overlayHeight)
          .clamp(160, 8192)
          .toInt(),
      hitboxWidth: (hitboxWidth ?? this.hitboxWidth).clamp(100, 8192).toInt(),
      hitboxHeight: (hitboxHeight ?? this.hitboxHeight)
          .clamp(100, 8192)
          .toInt(),
      imageScale: (imageScale ?? this.imageScale).clamp(minScale, maxScale),
      positionX: (positionX ?? this.positionX).clamp(0.0, 1.0),
      positionY: (positionY ?? this.positionY).clamp(0.0, 1.0),
      syncCharacterNameWithSession:
          syncCharacterNameWithSession ?? this.syncCharacterNameWithSession,
      overlayInteractionMode: nextOverlayMode,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'isEnabled': isEnabled,
      'dataFolderPath': dataFolderPath,
      'selectedCharacterFolder': selectedCharacterFolder,
      'selectedEmotionFile': selectedEmotionFile,
      'opacity': opacity,
      'touchThroughEnabled': touchThroughEnabled,
      'touchThroughAlpha': touchThroughAlpha,
      'overlayWidth': overlayWidth,
      'overlayHeight': overlayHeight,
      'hitboxWidth': hitboxWidth,
      'hitboxHeight': hitboxHeight,
      'imageScale': imageScale,
      'positionX': positionX,
      'positionY': positionY,
      'syncCharacterNameWithSession': syncCharacterNameWithSession,
      'overlayInteractionMode': overlayInteractionMode,
    };
  }

  factory ImageOverlaySettings.fromJson(Map<String, dynamic> json) {
    return ImageOverlaySettings(
      isEnabled: json['isEnabled'] == true,
      dataFolderPath: json['dataFolderPath'] as String?,
      selectedCharacterFolder: json['selectedCharacterFolder'] as String?,
      selectedEmotionFile: json['selectedEmotionFile'] as String?,
      opacity: (json['opacity'] as num?)?.toDouble() ?? 1.0,
      touchThroughEnabled: json['touchThroughEnabled'] as bool? ?? true,
      touchThroughAlpha: json['touchThroughAlpha'] as int? ?? 80,
      overlayWidth: json['overlayWidth'] as int? ?? 320,
      overlayHeight: json['overlayHeight'] as int? ?? 420,
      hitboxWidth:
          json['hitboxWidth'] as int? ?? (json['overlayWidth'] as int? ?? 320),
      hitboxHeight:
          json['hitboxHeight'] as int? ??
          (json['overlayHeight'] as int? ?? 420),
      imageScale: (json['imageScale'] as num?)?.toDouble() ?? 1.0,
      positionX: (json['positionX'] as num?)?.toDouble() ?? 0.5,
      positionY: (json['positionY'] as num?)?.toDouble() ?? 0.5,
      syncCharacterNameWithSession:
          json['syncCharacterNameWithSession'] as bool? ?? false,
      overlayInteractionMode: json['overlayInteractionMode'] == overlayModeBasic
          ? overlayModeBasic
          : overlayModeAdvanced,
    );
  }
}

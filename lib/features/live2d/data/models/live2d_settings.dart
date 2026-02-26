// ============================================================================
// ============================================================================
// ============================================================================

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Live2DSettings {
  static const String _prefsKey = 'live2d_settings';

  final bool isEnabled;

  final String? dataFolderUri;

  final String? dataFolderPath;

  final String? selectedModelId;

  final String? selectedModelPath;

  final double scale;

  final double positionX;

  final double positionY;

  final double opacity;

  final bool touchThroughEnabled;

  final int touchThroughAlpha;

  final int overlayWidth;

  final int overlayHeight;

  final bool editModeEnabled;

  final bool characterPinned;

  final double relativeCharacterScale;

  final double characterOffsetX;

  final double characterOffsetY;

  final int characterRotation;

  const Live2DSettings({
    this.isEnabled = false,
    this.dataFolderUri,
    this.dataFolderPath,
    this.selectedModelId,
    this.selectedModelPath,
    this.scale = 1.0,
    this.positionX = 0.5,
    this.positionY = 0.5,
    this.opacity = 1.0,
    this.touchThroughEnabled = true,
    this.touchThroughAlpha = 80,
    this.overlayWidth = 300,
    this.overlayHeight = 400,
    this.editModeEnabled = false,
    this.characterPinned = false,
    this.relativeCharacterScale = 1.0,
    this.characterOffsetX = 0.0,
    this.characterOffsetY = 0.0,
    this.characterRotation = 0,
  });

  factory Live2DSettings.defaults() => const Live2DSettings();

  static Future<Live2DSettings> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_prefsKey);

      if (jsonString == null) {
        debugPrint('[Live2DSettings] 저장된 설정 없음, 기본값 사용');
        return Live2DSettings.defaults();
      }

      final json = jsonDecode(jsonString) as Map<String, dynamic>;
      return Live2DSettings.fromJson(json);
    } catch (e) {
      debugPrint('[Live2DSettings] 설정 로드 실패: $e');
      return Live2DSettings.defaults();
    }
  }

  Future<bool> save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = jsonEncode(toJson());
      await prefs.setString(_prefsKey, jsonString);
      debugPrint('[Live2DSettings] 설정 저장 완료');
      return true;
    } catch (e) {
      debugPrint('[Live2DSettings] 설정 저장 실패: $e');
      return false;
    }
  }

  Live2DSettings copyWith({
    bool? isEnabled,
    String? dataFolderUri,
    String? dataFolderPath,
    String? selectedModelId,
    String? selectedModelPath,
    double? scale,
    double? positionX,
    double? positionY,
    double? opacity,
    bool? touchThroughEnabled,
    int? touchThroughAlpha,
    int? overlayWidth,
    int? overlayHeight,
    bool? editModeEnabled,
    bool? characterPinned,
    double? relativeCharacterScale,
    double? characterOffsetX,
    double? characterOffsetY,
    int? characterRotation,
    bool clearDataFolder = false,
    bool clearSelectedModel = false,
  }) {
    return Live2DSettings(
      isEnabled: isEnabled ?? this.isEnabled,
      dataFolderUri: clearDataFolder ? null : (dataFolderUri ?? this.dataFolderUri),
      dataFolderPath: clearDataFolder ? null : (dataFolderPath ?? this.dataFolderPath),
      selectedModelId: clearSelectedModel ? null : (selectedModelId ?? this.selectedModelId),
      selectedModelPath: clearSelectedModel ? null : (selectedModelPath ?? this.selectedModelPath),
      scale: (scale ?? this.scale).clamp(0.5, 2.0),
      positionX: (positionX ?? this.positionX).clamp(0.0, 1.0),
      positionY: (positionY ?? this.positionY).clamp(0.0, 1.0),
      opacity: (opacity ?? this.opacity).clamp(0.0, 1.0),
      touchThroughEnabled: touchThroughEnabled ?? this.touchThroughEnabled,
      touchThroughAlpha: (touchThroughAlpha ?? this.touchThroughAlpha).clamp(0, 100),
      overlayWidth: overlayWidth ?? this.overlayWidth,
      overlayHeight: overlayHeight ?? this.overlayHeight,
      editModeEnabled: editModeEnabled ?? this.editModeEnabled,
      characterPinned: characterPinned ?? this.characterPinned,
      relativeCharacterScale: (relativeCharacterScale ?? this.relativeCharacterScale).clamp(0.1, 3.0),
      characterOffsetX: characterOffsetX ?? this.characterOffsetX,
      characterOffsetY: characterOffsetY ?? this.characterOffsetY,
      characterRotation: (characterRotation ?? this.characterRotation) % 360,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'isEnabled': isEnabled,
      'dataFolderUri': dataFolderUri,
      'dataFolderPath': dataFolderPath,
      'selectedModelId': selectedModelId,
      'selectedModelPath': selectedModelPath,
      'scale': scale,
      'positionX': positionX,
      'positionY': positionY,
      'opacity': opacity,
      'touchThroughEnabled': touchThroughEnabled,
      'touchThroughAlpha': touchThroughAlpha,
      'overlayWidth': overlayWidth,
      'overlayHeight': overlayHeight,
      'editModeEnabled': editModeEnabled,
      'characterPinned': characterPinned,
      'relativeCharacterScale': relativeCharacterScale,
      'characterOffsetX': characterOffsetX,
      'characterOffsetY': characterOffsetY,
      'characterRotation': characterRotation,
    };
  }

  factory Live2DSettings.fromJson(Map<String, dynamic> json) {
    return Live2DSettings(
      isEnabled: json['isEnabled'] as bool? ?? false,
      dataFolderUri: json['dataFolderUri'] as String?,
      dataFolderPath: json['dataFolderPath'] as String?,
      selectedModelId: json['selectedModelId'] as String?,
      selectedModelPath: json['selectedModelPath'] as String?,
      scale: (json['scale'] as num?)?.toDouble() ?? 1.0,
      positionX: (json['positionX'] as num?)?.toDouble() ?? 0.5,
      positionY: (json['positionY'] as num?)?.toDouble() ?? 0.5,
      opacity: (json['opacity'] as num?)?.toDouble() ?? 1.0,
      touchThroughEnabled: json['touchThroughEnabled'] as bool? ?? true,
      touchThroughAlpha: json['touchThroughAlpha'] as int? ?? 80,
      overlayWidth: json['overlayWidth'] as int? ?? 300,
      overlayHeight: json['overlayHeight'] as int? ?? 400,
      editModeEnabled: json['editModeEnabled'] as bool? ?? false,
      characterPinned: json['characterPinned'] as bool? ?? false,
      relativeCharacterScale: (json['relativeCharacterScale'] as num?)?.toDouble() ?? 1.0,
      characterOffsetX: (json['characterOffsetX'] as num?)?.toDouble() ?? 0.0,
      characterOffsetY: (json['characterOffsetY'] as num?)?.toDouble() ?? 0.0,
      characterRotation: json['characterRotation'] as int? ?? 0,
    );
  }

  @override
  String toString() => 'Live2DSettings('
      'isEnabled: $isEnabled, '
      'folder: $dataFolderPath, '
      'model: $selectedModelId, '
      'scale: $scale'
      ')';
}

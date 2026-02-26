// ============================================================================
// ============================================================================
// ============================================================================

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DisplayPreset {
  final String id;

  final String name;

  final double relativeCharacterScale;

  final double characterOffsetX;

  final double characterOffsetY;

  final int characterRotation;

  final int overlayWidth;

  final int overlayHeight;

  final double positionX;

  final double positionY;

  final double scale;

  final String? linkedModelFolder;

  final String? linkedModelId;

  const DisplayPreset({
    required this.id,
    required this.name,
    this.relativeCharacterScale = 1.0,
    this.characterOffsetX = 0.0,
    this.characterOffsetY = 0.0,
    this.characterRotation = 0,
    this.overlayWidth = 300,
    this.overlayHeight = 400,
    this.positionX = 0.5,
    this.positionY = 0.5,
    this.scale = 1.0,
    this.linkedModelFolder,
    this.linkedModelId,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'relativeCharacterScale': relativeCharacterScale,
        'characterOffsetX': characterOffsetX,
        'characterOffsetY': characterOffsetY,
        'characterRotation': characterRotation,
        'overlayWidth': overlayWidth,
        'overlayHeight': overlayHeight,
        'positionX': positionX,
        'positionY': positionY,
        'scale': scale,
        'linkedModelFolder': linkedModelFolder,
        'linkedModelId': linkedModelId,
      };

  factory DisplayPreset.fromJson(Map<String, dynamic> json) => DisplayPreset(
        id: json['id'] as String? ?? DateTime.now().millisecondsSinceEpoch.toString(),
        name: json['name'] as String? ?? '프리셋',
        relativeCharacterScale: (json['relativeCharacterScale'] as num?)?.toDouble() ?? 1.0,
        characterOffsetX: (json['characterOffsetX'] as num?)?.toDouble() ?? 0.0,
        characterOffsetY: (json['characterOffsetY'] as num?)?.toDouble() ?? 0.0,
        characterRotation: json['characterRotation'] as int? ?? 0,
        overlayWidth: json['overlayWidth'] as int? ?? 300,
        overlayHeight: json['overlayHeight'] as int? ?? 400,
        positionX: (json['positionX'] as num?)?.toDouble() ?? 0.5,
        positionY: (json['positionY'] as num?)?.toDouble() ?? 0.5,
        scale: (json['scale'] as num?)?.toDouble() ?? 1.0,
        linkedModelFolder: json['linkedModelFolder'] as String?,
        linkedModelId: json['linkedModelId'] as String?,
      );

  DisplayPreset copyWith({
    String? id,
    String? name,
    double? relativeCharacterScale,
    double? characterOffsetX,
    double? characterOffsetY,
    int? characterRotation,
    int? overlayWidth,
    int? overlayHeight,
    double? positionX,
    double? positionY,
    double? scale,
    String? linkedModelFolder,
    String? linkedModelId,
    bool clearLink = false,
  }) =>
      DisplayPreset(
        id: id ?? this.id,
        name: name ?? this.name,
        relativeCharacterScale: relativeCharacterScale ?? this.relativeCharacterScale,
        characterOffsetX: characterOffsetX ?? this.characterOffsetX,
        characterOffsetY: characterOffsetY ?? this.characterOffsetY,
        characterRotation: characterRotation ?? this.characterRotation,
        overlayWidth: overlayWidth ?? this.overlayWidth,
        overlayHeight: overlayHeight ?? this.overlayHeight,
        positionX: positionX ?? this.positionX,
        positionY: positionY ?? this.positionY,
        scale: scale ?? this.scale,
        linkedModelFolder: clearLink ? null : (linkedModelFolder ?? this.linkedModelFolder),
        linkedModelId: clearLink ? null : (linkedModelId ?? this.linkedModelId),
      );

  @override
  String toString() => 'DisplayPreset(name: $name, scale: $relativeCharacterScale, '
      'offset: ($characterOffsetX, $characterOffsetY), rotation: $characterRotation)';
}

class DisplayPresetManager {
  static const String _prefsKey = 'live2d_display_presets';

  static Future<List<DisplayPreset>> loadAll() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_prefsKey);
      if (jsonString == null) return [];

      final list = jsonDecode(jsonString) as List<dynamic>;
      return list
          .map((e) => DisplayPreset.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('[DisplayPreset] 로드 실패: $e');
      return [];
    }
  }

  static Future<bool> saveAll(List<DisplayPreset> presets) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = jsonEncode(presets.map((p) => p.toJson()).toList());
      return prefs.setString(_prefsKey, jsonString);
    } catch (e) {
      debugPrint('[DisplayPreset] 저장 실패: $e');
      return false;
    }
  }

  static Future<bool> add(DisplayPreset preset) async {
    final presets = await loadAll();
    presets.add(preset);
    return saveAll(presets);
  }

  static Future<bool> delete(String presetId) async {
    final presets = await loadAll();
    presets.removeWhere((p) => p.id == presetId);
    return saveAll(presets);
  }

  static Future<bool> update(DisplayPreset updated) async {
    final presets = await loadAll();
    final index = presets.indexWhere((p) => p.id == updated.id);
    if (index < 0) return false;
    presets[index] = updated;
    return saveAll(presets);
  }

  static Future<DisplayPreset?> findLinkedPreset(String modelFolder) async {
    final presets = await loadAll();
    try {
      return presets.firstWhere((p) => p.linkedModelFolder == modelFolder);
    } catch (_) {
      return null;
    }
  }

  static Future<DisplayPreset?> findLinkedPresetForModel(
      String modelFolder, String modelId) async {
    final presets = await loadAll();
    try {
      return presets.firstWhere(
        (p) => p.linkedModelFolder == modelFolder && p.linkedModelId == modelId,
        orElse: () => presets.firstWhere(
          (p) => p.linkedModelFolder == modelFolder && p.linkedModelId == null,
        ),
      );
    } catch (_) {
      return null;
    }
  }
}

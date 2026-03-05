import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class ImageOverlayPreset {
  const ImageOverlayPreset({
    required this.id,
    required this.name,
    required this.overlayWidth,
    required this.overlayHeight,
    this.positionX = 0.5,
    this.positionY = 0.5,
    this.imageScale = 1.0,
    this.linkedCharacterFolder,
  });

  final String id;
  final String name;
  final int overlayWidth;
  final int overlayHeight;
  final double positionX;
  final double positionY;
  final double imageScale;
  final String? linkedCharacterFolder;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'overlayWidth': overlayWidth,
      'overlayHeight': overlayHeight,
      'positionX': positionX,
      'positionY': positionY,
      'imageScale': imageScale,
      'linkedCharacterFolder': linkedCharacterFolder,
    };
  }

  factory ImageOverlayPreset.fromJson(Map<String, dynamic> json) {
    return ImageOverlayPreset(
      id: json['id'] as String,
      name: json['name'] as String,
      overlayWidth: json['overlayWidth'] as int? ?? 320,
      overlayHeight: json['overlayHeight'] as int? ?? 420,
      positionX: (json['positionX'] as num?)?.toDouble() ?? 0.5,
      positionY: (json['positionY'] as num?)?.toDouble() ?? 0.5,
      imageScale: (json['imageScale'] as num?)?.toDouble() ?? 1.0,
      linkedCharacterFolder: json['linkedCharacterFolder'] as String?,
    );
  }

  ImageOverlayPreset copyWith({
    String? id,
    String? name,
    int? overlayWidth,
    int? overlayHeight,
    double? positionX,
    double? positionY,
    double? imageScale,
    String? linkedCharacterFolder,
    bool clearLink = false,
  }) {
    return ImageOverlayPreset(
      id: id ?? this.id,
      name: name ?? this.name,
      overlayWidth: overlayWidth ?? this.overlayWidth,
      overlayHeight: overlayHeight ?? this.overlayHeight,
      positionX: (positionX ?? this.positionX).clamp(0.0, 1.0),
      positionY: (positionY ?? this.positionY).clamp(0.0, 1.0),
      imageScale: (imageScale ?? this.imageScale).clamp(0.1, 5.0),
      linkedCharacterFolder:
          clearLink ? null : (linkedCharacterFolder ?? this.linkedCharacterFolder),
    );
  }
}

class ImageOverlayPresetStore {
  static const String _prefsKey = 'image_overlay_presets_v1';

  static Future<List<ImageOverlayPreset>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null || raw.isEmpty) {
      return [];
    }
    final decoded = jsonDecode(raw);
    if (decoded is! List) {
      return [];
    }
    return decoded
        .whereType<Map>()
        .map((e) => ImageOverlayPreset.fromJson(Map<String, dynamic>.from(e)))
        .toList(growable: false);
  }

  static Future<void> saveAll(List<ImageOverlayPreset> presets) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _prefsKey,
      jsonEncode(presets.map((e) => e.toJson()).toList(growable: false)),
    );
  }
}

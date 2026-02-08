// ============================================================================
// 디스플레이 편집 프리셋 (Display Edit Preset)
// ============================================================================
// 편집 모드에서 설정한 캐릭터의 상대적 위치, 크기, 회전 등을 저장하는 프리셋입니다.
// SharedPreferences로 JSON 배열로 저장/로드됩니다.
// ============================================================================

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 디스플레이 편집 프리셋
class DisplayPreset {
  /// 고유 ID (타임스탬프 기반)
  final String id;

  /// 프리셋 이름
  final String name;

  /// 캐릭터 상대적 크기 (투명상자 대비, 0.1~3.0)
  final double relativeCharacterScale;

  /// 캐릭터 오프셋 X (투명상자 내 상대 위치, 픽셀)
  final double characterOffsetX;

  /// 캐릭터 오프셋 Y (투명상자 내 상대 위치, 픽셀)
  final double characterOffsetY;

  /// 캐릭터 회전 (0~359도)
  final int characterRotation;

  /// 투명상자 너비 (픽셀)
  final int overlayWidth;

  /// 투명상자 높이 (픽셀)
  final int overlayHeight;

  /// 초기 위치 X (화면 비율 0.0~1.0)
  final double positionX;

  /// 초기 위치 Y (화면 비율 0.0~1.0)
  final double positionY;

  /// 모델 스케일
  final double scale;

  /// 링크된 모델 폴더 이름 (null이면 링크 없음)
  final String? linkedModelFolder;

  /// 링크된 모델 ID (null이면 폴더 내 모든 모델)
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

  /// JSON 직렬화
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

  /// JSON 역직렬화
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

  /// 복사본 생성
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

/// 프리셋 매니저 (SharedPreferences 기반)
class DisplayPresetManager {
  static const String _prefsKey = 'live2d_display_presets';

  /// 모든 프리셋 로드
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

  /// 모든 프리셋 저장
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

  /// 프리셋 추가
  static Future<bool> add(DisplayPreset preset) async {
    final presets = await loadAll();
    presets.add(preset);
    return saveAll(presets);
  }

  /// 프리셋 삭제
  static Future<bool> delete(String presetId) async {
    final presets = await loadAll();
    presets.removeWhere((p) => p.id == presetId);
    return saveAll(presets);
  }

  /// 프리셋 업데이트 (링크 등)
  static Future<bool> update(DisplayPreset updated) async {
    final presets = await loadAll();
    final index = presets.indexWhere((p) => p.id == updated.id);
    if (index < 0) return false;
    presets[index] = updated;
    return saveAll(presets);
  }

  /// 모델에 링크된 프리셋 찾기 (폴더 이름 기반)
  static Future<DisplayPreset?> findLinkedPreset(String modelFolder) async {
    final presets = await loadAll();
    try {
      return presets.firstWhere((p) => p.linkedModelFolder == modelFolder);
    } catch (_) {
      return null;
    }
  }

  /// 특정 모델 ID에 링크된 프리셋 찾기
  static Future<DisplayPreset?> findLinkedPresetForModel(
      String modelFolder, String modelId) async {
    final presets = await loadAll();
    try {
      // 모델 ID 매치 우선, 없으면 폴더 매치
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

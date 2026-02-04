// ============================================================================
// Live2D 설정 (Live2D Settings)
// ============================================================================
// Live2D 관련 설정을 담는 데이터 클래스입니다.
// SharedPreferences로 저장/로드됩니다.
// ============================================================================

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Live2D 관련 설정을 담는 데이터 클래스
class Live2DSettings {
  /// SharedPreferences 키
  static const String _prefsKey = 'live2d_settings';

  /// 플로팅 뷰어 활성화 여부
  final bool isEnabled;

  /// SAF로 선택한 폴더 URI (Android)
  final String? dataFolderUri;

  /// SAF로 선택한 폴더의 실제 경로 (디스플레이용)
  final String? dataFolderPath;

  /// 현재 선택된 모델 ID
  final String? selectedModelId;

  /// 현재 선택된 모델 상대 경로
  final String? selectedModelPath;

  /// 모델 크기 (0.5 ~ 2.0, 기본값 1.0)
  final double scale;

  /// 화면 비율 기준 X 위치 (0.0 ~ 1.0)
  final double positionX;

  /// 화면 비율 기준 Y 위치 (0.0 ~ 1.0)
  final double positionY;

  /// 투명도 (0.3 ~ 1.0, 기본값 1.0)
  final double opacity;

  /// 오버레이 너비 (픽셀)
  final int overlayWidth;

  /// 오버레이 높이 (픽셀)
  final int overlayHeight;

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
    this.overlayWidth = 300,
    this.overlayHeight = 400,
  });

  /// 기본 설정
  factory Live2DSettings.defaults() => const Live2DSettings();

  /// SharedPreferences에서 설정 로드
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

  /// SharedPreferences에 설정 저장
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

  /// 복사본 생성 (일부 값 변경)
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
    int? overlayWidth,
    int? overlayHeight,
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
      opacity: (opacity ?? this.opacity).clamp(0.3, 1.0),
      overlayWidth: overlayWidth ?? this.overlayWidth,
      overlayHeight: overlayHeight ?? this.overlayHeight,
    );
  }

  /// JSON으로 직렬화
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
      'overlayWidth': overlayWidth,
      'overlayHeight': overlayHeight,
    };
  }

  /// JSON에서 역직렬화
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
      overlayWidth: json['overlayWidth'] as int? ?? 300,
      overlayHeight: json['overlayHeight'] as int? ?? 400,
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

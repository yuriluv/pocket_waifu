// ============================================================================
// ============================================================================
// ============================================================================

import 'dart:math';

class Live2DDisplayConfig {
  static const int currentSchemaVersion = 1;

  final String modelId;
  final String? modelPath;

  final double containerWidthDp;
  final double containerHeightDp;
  final double containerXRatio;
  final double containerYRatio;
  final double containerWidthRatio;
  final double containerHeightRatio;

  final double modelScaleX;
  final double modelScaleY;
  final double modelOffsetXRatio;
  final double modelOffsetYRatio;
  final double modelOffsetXDp;
  final double modelOffsetYDp;

  final double relativeScaleRatio;

  final int rotationDeg;

  final int schemaVersion;

  const Live2DDisplayConfig({
    required this.modelId,
    this.modelPath,
    required this.containerWidthDp,
    required this.containerHeightDp,
    required this.containerXRatio,
    required this.containerYRatio,
    required this.containerWidthRatio,
    required this.containerHeightRatio,
    required this.modelScaleX,
    required this.modelScaleY,
    required this.modelOffsetXRatio,
    required this.modelOffsetYRatio,
    required this.modelOffsetXDp,
    required this.modelOffsetYDp,
    required this.relativeScaleRatio,
    required this.rotationDeg,
    this.schemaVersion = currentSchemaVersion,
  });

  Live2DDisplayConfig copyWith({
    String? modelId,
    String? modelPath,
    double? containerWidthDp,
    double? containerHeightDp,
    double? containerXRatio,
    double? containerYRatio,
    double? containerWidthRatio,
    double? containerHeightRatio,
    double? modelScaleX,
    double? modelScaleY,
    double? modelOffsetXRatio,
    double? modelOffsetYRatio,
    double? modelOffsetXDp,
    double? modelOffsetYDp,
    double? relativeScaleRatio,
    int? rotationDeg,
    int? schemaVersion,
  }) {
    return Live2DDisplayConfig(
      modelId: modelId ?? this.modelId,
      modelPath: modelPath ?? this.modelPath,
      containerWidthDp: containerWidthDp ?? this.containerWidthDp,
      containerHeightDp: containerHeightDp ?? this.containerHeightDp,
      containerXRatio: containerXRatio ?? this.containerXRatio,
      containerYRatio: containerYRatio ?? this.containerYRatio,
      containerWidthRatio: containerWidthRatio ?? this.containerWidthRatio,
      containerHeightRatio: containerHeightRatio ?? this.containerHeightRatio,
      modelScaleX: modelScaleX ?? this.modelScaleX,
      modelScaleY: modelScaleY ?? this.modelScaleY,
      modelOffsetXRatio: modelOffsetXRatio ?? this.modelOffsetXRatio,
      modelOffsetYRatio: modelOffsetYRatio ?? this.modelOffsetYRatio,
      modelOffsetXDp: modelOffsetXDp ?? this.modelOffsetXDp,
      modelOffsetYDp: modelOffsetYDp ?? this.modelOffsetYDp,
      relativeScaleRatio: relativeScaleRatio ?? this.relativeScaleRatio,
      rotationDeg: rotationDeg ?? this.rotationDeg,
      schemaVersion: schemaVersion ?? this.schemaVersion,
    );
  }

  Map<String, dynamic> toJson() => {
        'schemaVersion': schemaVersion,
        'modelId': modelId,
        'modelPath': modelPath,
        'containerWidthDp': containerWidthDp,
        'containerHeightDp': containerHeightDp,
        'containerXRatio': containerXRatio,
        'containerYRatio': containerYRatio,
        'containerWidthRatio': containerWidthRatio,
        'containerHeightRatio': containerHeightRatio,
        'modelScaleX': modelScaleX,
        'modelScaleY': modelScaleY,
        'modelOffsetXRatio': modelOffsetXRatio,
        'modelOffsetYRatio': modelOffsetYRatio,
        'modelOffsetXDp': modelOffsetXDp,
        'modelOffsetYDp': modelOffsetYDp,
        'relativeScaleRatio': relativeScaleRatio,
        'rotationDeg': rotationDeg,
      };

  factory Live2DDisplayConfig.fromJson(Map<String, dynamic> json) {
    return Live2DDisplayConfig(
      schemaVersion: (json['schemaVersion'] as int?) ?? 0,
      modelId: json['modelId'] as String? ?? '',
      modelPath: json['modelPath'] as String?,
      containerWidthDp: (json['containerWidthDp'] as num?)?.toDouble() ?? 0.0,
      containerHeightDp: (json['containerHeightDp'] as num?)?.toDouble() ?? 0.0,
      containerXRatio: (json['containerXRatio'] as num?)?.toDouble() ?? 0.0,
      containerYRatio: (json['containerYRatio'] as num?)?.toDouble() ?? 0.0,
      containerWidthRatio:
          (json['containerWidthRatio'] as num?)?.toDouble() ?? 0.0,
      containerHeightRatio:
          (json['containerHeightRatio'] as num?)?.toDouble() ?? 0.0,
      modelScaleX: (json['modelScaleX'] as num?)?.toDouble() ?? 1.0,
      modelScaleY: (json['modelScaleY'] as num?)?.toDouble() ?? 1.0,
      modelOffsetXRatio:
          (json['modelOffsetXRatio'] as num?)?.toDouble() ?? 0.0,
      modelOffsetYRatio:
          (json['modelOffsetYRatio'] as num?)?.toDouble() ?? 0.0,
      modelOffsetXDp: (json['modelOffsetXDp'] as num?)?.toDouble() ?? 0.0,
      modelOffsetYDp: (json['modelOffsetYDp'] as num?)?.toDouble() ?? 0.0,
      relativeScaleRatio:
          (json['relativeScaleRatio'] as num?)?.toDouble() ?? 1.0,
      rotationDeg: (json['rotationDeg'] as int?) ?? 0,
    );
  }

  bool get isValid {
    if (modelId.trim().isEmpty) return false;
    if (containerWidthDp <= 0 || containerHeightDp <= 0) return false;
    if (!_ratioOk(containerWidthRatio) || !_ratioOk(containerHeightRatio)) {
      return false;
    }
    if (!_ratioOk(containerXRatio) || !_ratioOk(containerYRatio)) return false;
    return true;
  }

  static bool _ratioOk(double value) {
    return value.isFinite && value >= 0.0 && value <= 1.0;
  }

  static Live2DDisplayConfig fallbackFor(String modelId) {
    return Live2DDisplayConfig(
      modelId: modelId,
      containerWidthDp: 300,
      containerHeightDp: 400,
      containerXRatio: 0.5,
      containerYRatio: 0.5,
      containerWidthRatio: 0.3,
      containerHeightRatio: 0.4,
      modelScaleX: 1.0,
      modelScaleY: 1.0,
      modelOffsetXRatio: 0.0,
      modelOffsetYRatio: 0.0,
      modelOffsetXDp: 0.0,
      modelOffsetYDp: 0.0,
      relativeScaleRatio: 1.0,
      rotationDeg: 0,
    );
  }

  static Live2DDisplayConfig fromOverlayState({
    required String modelId,
    required String? modelPath,
    required int containerWidthPx,
    required int containerHeightPx,
    required int containerX,
    required int containerY,
    required double relativeScale,
    required double offsetX,
    required double offsetY,
    required int rotationDeg,
    required int screenWidthPx,
    required int screenHeightPx,
    required double density,
  }) {
    final safeDensity = density <= 0 ? 1.0 : density;
    final widthRatio = screenWidthPx > 0
        ? (containerWidthPx / screenWidthPx).clamp(0.0, 1.0)
        : 0.0;
    final heightRatio = screenHeightPx > 0
        ? (containerHeightPx / screenHeightPx).clamp(0.0, 1.0)
        : 0.0;
    final xRatio = screenWidthPx > 0
        ? (containerX / screenWidthPx).clamp(0.0, 1.0)
        : 0.0;
    final yRatio = screenHeightPx > 0
        ? (containerY / screenHeightPx).clamp(0.0, 1.0)
        : 0.0;

    final offsetXRatio = containerWidthPx > 0
        ? (offsetX / containerWidthPx).clamp(-1.0, 1.0)
        : 0.0;
    final offsetYRatio = containerHeightPx > 0
        ? (offsetY / containerHeightPx).clamp(-1.0, 1.0)
        : 0.0;

    return Live2DDisplayConfig(
      modelId: modelId,
      modelPath: modelPath,
      containerWidthDp: containerWidthPx / safeDensity,
      containerHeightDp: containerHeightPx / safeDensity,
      containerXRatio: xRatio,
      containerYRatio: yRatio,
      containerWidthRatio: widthRatio,
      containerHeightRatio: heightRatio,
      modelScaleX: relativeScale,
      modelScaleY: relativeScale,
      modelOffsetXRatio: offsetXRatio,
      modelOffsetYRatio: offsetYRatio,
      modelOffsetXDp: offsetX / safeDensity,
      modelOffsetYDp: offsetY / safeDensity,
      relativeScaleRatio: relativeScale,
      rotationDeg: rotationDeg,
    );
  }

  Live2DDisplayConfig normalizeWithScreen(
      int screenWidthPx, int screenHeightPx, double density) {
    final safeDensity = density <= 0 ? 1.0 : density;
    final widthPx = max(1.0, containerWidthRatio * screenWidthPx.toDouble());
    final heightPx =
        max(1.0, containerHeightRatio * screenHeightPx.toDouble());
    return copyWith(
      containerWidthDp: widthPx / safeDensity,
      containerHeightDp: heightPx / safeDensity,
      containerXRatio: containerXRatio.clamp(0.0, 1.0),
      containerYRatio: containerYRatio.clamp(0.0, 1.0),
      modelOffsetXDp:
          (modelOffsetXRatio * widthPx).clamp(-widthPx, widthPx) / safeDensity,
      modelOffsetYDp:
          (modelOffsetYRatio * heightPx).clamp(-heightPx, heightPx) / safeDensity,
    );
  }
}

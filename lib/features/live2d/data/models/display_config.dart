// ============================================================================
// ============================================================================
// ============================================================================

import 'dart:math';
import 'dart:developer' as developer;

class Live2DDisplayConfig {
  static const int currentSchemaVersion = 2;

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
        // Canonical keys required by Part1 contract.
        'containerWidth': containerWidthDp,
        'containerHeight': containerHeightDp,
        'containerX': containerXRatio,
        'containerY': containerYRatio,
        'modelOffsetX': modelOffsetXDp,
        'modelOffsetY': modelOffsetYDp,
        // Backward-compatible keys used by existing app code.
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
    final modelId = json['modelId'] as String? ?? '';
    if (modelId.trim().isEmpty) {
      _logFallback('modelId', modelId.isEmpty ? '(empty)' : modelId);
    }

    final containerWidthMeta = _readDoubleWithMeta(
      json,
      const ['containerWidthDp', 'containerWidth', 'overlayWidth'],
    );
    final containerWidthDp = containerWidthMeta.value;
    if (!containerWidthMeta.found) {
      _logFallback('containerWidthDp', containerWidthDp);
    }

    final containerHeightMeta = _readDoubleWithMeta(
      json,
      const ['containerHeightDp', 'containerHeight', 'overlayHeight'],
    );
    final containerHeightDp = containerHeightMeta.value;
    if (!containerHeightMeta.found) {
      _logFallback('containerHeightDp', containerHeightDp);
    }

    final modelOffsetXMeta = _readDoubleWithMeta(
      json,
      const ['modelOffsetXDp', 'modelOffsetX', 'characterOffsetX'],
    );
    final modelOffsetXDp = modelOffsetXMeta.value;
    if (!modelOffsetXMeta.found) {
      _logFallback('modelOffsetXDp', modelOffsetXDp);
    }

    final modelOffsetYMeta = _readDoubleWithMeta(
      json,
      const ['modelOffsetYDp', 'modelOffsetY', 'characterOffsetY'],
    );
    final modelOffsetYDp = modelOffsetYMeta.value;
    if (!modelOffsetYMeta.found) {
      _logFallback('modelOffsetYDp', modelOffsetYDp);
    }

    final modelOffsetXRatio = json.containsKey('modelOffsetXRatio')
        ? _signedRatio(
            _readDouble(json, const ['modelOffsetXRatio']),
            fallback: 0.0,
          )
        : _deriveSignedRatio(modelOffsetXDp, containerWidthDp);
    final modelOffsetYRatio = json.containsKey('modelOffsetYRatio')
        ? _signedRatio(
            _readDouble(json, const ['modelOffsetYRatio']),
            fallback: 0.0,
          )
        : _deriveSignedRatio(modelOffsetYDp, containerHeightDp);

    if (!json.containsKey('modelOffsetXRatio')) {
      _logFallback('modelOffsetXRatio', modelOffsetXRatio);
    }
    if (!json.containsKey('modelOffsetYRatio')) {
      _logFallback('modelOffsetYRatio', modelOffsetYRatio);
    }

    final containerXMeta = _readDoubleWithMeta(
      json,
      const ['containerXRatio', 'containerX', 'positionX'],
    );
    final containerYMeta = _readDoubleWithMeta(
      json,
      const ['containerYRatio', 'containerY', 'positionY'],
    );
    final containerWidthRatioMeta = _readDoubleWithMeta(
      json,
      const ['containerWidthRatio'],
    );
    final containerHeightRatioMeta = _readDoubleWithMeta(
      json,
      const ['containerHeightRatio'],
    );

    final modelScaleX = (json['modelScaleX'] as num?)?.toDouble() ?? 1.0;
    final modelScaleY = (json['modelScaleY'] as num?)?.toDouble() ?? 1.0;
    final relativeScaleRatio =
        (json['relativeScaleRatio'] as num?)?.toDouble() ?? 1.0;
    final rotationDeg = (json['rotationDeg'] as int?) ?? 0;

    if (!containerXMeta.found) {
      _logFallback('containerXRatio', containerXMeta.value);
    }
    if (!containerYMeta.found) {
      _logFallback('containerYRatio', containerYMeta.value);
    }
    if (!containerWidthRatioMeta.found) {
      _logFallback('containerWidthRatio', containerWidthRatioMeta.value);
    }
    if (!containerHeightRatioMeta.found) {
      _logFallback('containerHeightRatio', containerHeightRatioMeta.value);
    }
    if (json['modelScaleX'] == null) {
      _logFallback('modelScaleX', modelScaleX);
    }
    if (json['modelScaleY'] == null) {
      _logFallback('modelScaleY', modelScaleY);
    }
    if (json['relativeScaleRatio'] == null) {
      _logFallback('relativeScaleRatio', relativeScaleRatio);
    }
    if (json['rotationDeg'] == null) {
      _logFallback('rotationDeg', rotationDeg);
    }

    return Live2DDisplayConfig(
      schemaVersion: (json['schemaVersion'] as int?) ?? 0,
      modelId: modelId,
      modelPath: json['modelPath'] as String?,
      containerWidthDp: containerWidthDp,
      containerHeightDp: containerHeightDp,
      containerXRatio: _ratio(
        containerXMeta.value,
        fallback: 0.5,
      ),
      containerYRatio: _ratio(
        containerYMeta.value,
        fallback: 0.5,
      ),
      containerWidthRatio: _ratio(
        containerWidthRatioMeta.value,
        fallback: 0.0,
      ),
      containerHeightRatio: _ratio(
        containerHeightRatioMeta.value,
        fallback: 0.0,
      ),
      modelScaleX: modelScaleX,
      modelScaleY: modelScaleY,
      modelOffsetXRatio: modelOffsetXRatio,
      modelOffsetYRatio: modelOffsetYRatio,
      modelOffsetXDp: modelOffsetXDp,
      modelOffsetYDp: modelOffsetYDp,
      relativeScaleRatio: relativeScaleRatio,
      rotationDeg: rotationDeg,
    );
  }

  bool get isValid {
    if (modelId.trim().isEmpty) return false;
    if (containerWidthDp <= 0 || containerHeightDp <= 0) return false;
    if (!_ratioOk(containerWidthRatio) || !_ratioOk(containerHeightRatio)) {
      return false;
    }
    if (!_ratioOk(containerXRatio) || !_ratioOk(containerYRatio)) return false;
    if (!relativeScaleRatio.isFinite || relativeScaleRatio <= 0) return false;
    return true;
  }

  static bool _ratioOk(double value) {
    return value.isFinite && value >= 0.0 && value <= 1.0;
  }

  static double _readDouble(
    Map<String, dynamic> source,
    List<String> keys, {
    double defaultValue = 0.0,
  }) {
    for (final key in keys) {
      final value = source[key];
      if (value is num) {
        return value.toDouble();
      }
      if (value is String) {
        final parsed = double.tryParse(value);
        if (parsed != null) {
          return parsed;
        }
      }
    }
    return defaultValue;
  }

  static ({bool found, double value}) _readDoubleWithMeta(
    Map<String, dynamic> source,
    List<String> keys, {
    double defaultValue = 0.0,
  }) {
    for (final key in keys) {
      final value = source[key];
      if (value is num) {
        return (found: true, value: value.toDouble());
      }
      if (value is String) {
        final parsed = double.tryParse(value);
        if (parsed != null) {
          return (found: true, value: parsed);
        }
      }
    }
    return (found: false, value: defaultValue);
  }

  static void _logFallback(String field, Object value) {
    developer.log(
      'Fallback applied for $field: $value',
      name: 'Live2DDisplayConfig',
      level: 900,
    );
  }

  static double _ratio(double value, {double fallback = 0.0}) {
    if (!value.isFinite) {
      return fallback;
    }
    return value.clamp(0.0, 1.0).toDouble();
  }

  static double _signedRatio(double value, {double fallback = 0.0}) {
    if (!value.isFinite) {
      return fallback;
    }
    return value.clamp(-1.0, 1.0).toDouble();
  }

  static double _deriveSignedRatio(double absoluteDp, double containerDp) {
    if (!absoluteDp.isFinite || !containerDp.isFinite || containerDp.abs() < 0.001) {
      return 0.0;
    }
    return (absoluteDp / containerDp).clamp(-1.0, 1.0).toDouble();
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

  static Live2DDisplayConfig defaultConfig(String modelId) {
    return fallbackFor(modelId);
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
    final safeScreenWidth = max(1, screenWidthPx);
    final safeScreenHeight = max(1, screenHeightPx);

    final normalizedWidthRatio = containerWidthRatio > 0
        ? _ratio(containerWidthRatio, fallback: 0.3)
        : _ratio(
            (containerWidthDp * safeDensity) / safeScreenWidth.toDouble(),
            fallback: 0.3,
          );
    final normalizedHeightRatio = containerHeightRatio > 0
        ? _ratio(containerHeightRatio, fallback: 0.4)
        : _ratio(
            (containerHeightDp * safeDensity) / safeScreenHeight.toDouble(),
            fallback: 0.4,
          );

    final widthPx = max(1.0, normalizedWidthRatio * safeScreenWidth.toDouble());
    final heightPx =
        max(1.0, normalizedHeightRatio * safeScreenHeight.toDouble());
    final normalizedOffsetXRatio = modelOffsetXRatio.abs() > 0
        ? _signedRatio(modelOffsetXRatio, fallback: 0.0)
        : _deriveSignedRatio(modelOffsetXDp, containerWidthDp);
    final normalizedOffsetYRatio = modelOffsetYRatio.abs() > 0
        ? _signedRatio(modelOffsetYRatio, fallback: 0.0)
        : _deriveSignedRatio(modelOffsetYDp, containerHeightDp);

    return copyWith(
      containerWidthDp: widthPx / safeDensity,
      containerHeightDp: heightPx / safeDensity,
      containerWidthRatio: normalizedWidthRatio,
      containerHeightRatio: normalizedHeightRatio,
      containerXRatio: _ratio(containerXRatio, fallback: 0.5),
      containerYRatio: _ratio(containerYRatio, fallback: 0.5),
      modelOffsetXRatio: normalizedOffsetXRatio,
      modelOffsetYRatio: normalizedOffsetYRatio,
      modelOffsetXDp:
          (normalizedOffsetXRatio * widthPx).clamp(-widthPx, widthPx) /
              safeDensity,
      modelOffsetYDp:
          (normalizedOffsetYRatio * heightPx).clamp(-heightPx, heightPx) /
              safeDensity,
    );
  }
}

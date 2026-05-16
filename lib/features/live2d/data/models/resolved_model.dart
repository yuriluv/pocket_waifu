import 'dart:collection';

import 'model3_data.dart';

enum ResolvedModelStatus { ready, degraded }

enum ResolvedModelDegradedReason {
  runtimeBridgeUnavailable,
  runtimeReadFailed,
}

enum ResolvedParameterSource { staticOnly, runtimeOnly, merged }

class ResolvedModelDiagnostics {
  const ResolvedModelDiagnostics({
    required this.runtimeBridgeAvailable,
    required this.usedRuntimeParameterFallback,
    required this.usedRuntimeMotionFallback,
    this.degradedReason,
    this.degradedMessage,
  });

  final bool runtimeBridgeAvailable;
  final bool usedRuntimeParameterFallback;
  final bool usedRuntimeMotionFallback;
  final ResolvedModelDegradedReason? degradedReason;
  final String? degradedMessage;
}

class ResolvedModelParameter {
  const ResolvedModelParameter({
    required this.id,
    required this.name,
    required this.min,
    required this.defaultValue,
    required this.max,
    required this.source,
    this.runtimeValue,
  });

  final String id;
  final String name;
  final double min;
  final double defaultValue;
  final double max;
  final double? runtimeValue;
  final ResolvedParameterSource source;

  Model3Parameter toModel3Parameter() {
    return Model3Parameter(
      id: id,
      name: name,
      min: min,
      defaultValue: defaultValue,
      max: max,
    );
  }
}

class ResolvedModel {
  ResolvedModel({
    required this.status,
    required Map<String, List<String>> motionGroups,
    required List<Model3Expression> expressions,
    required List<ResolvedModelParameter> parameters,
    required List<Model3HitArea> hitAreas,
    required this.diagnostics,
  })  : motionGroups = _freezeMotionGroups(motionGroups),
        expressions = List<Model3Expression>.unmodifiable(expressions),
        parameters = List<ResolvedModelParameter>.unmodifiable(parameters),
        hitAreas = List<Model3HitArea>.unmodifiable(hitAreas);

  final ResolvedModelStatus status;
  final Map<String, List<String>> motionGroups;
  final List<Model3Expression> expressions;
  final List<ResolvedModelParameter> parameters;
  final List<Model3HitArea> hitAreas;
  final ResolvedModelDiagnostics diagnostics;

  bool get isDegraded => status == ResolvedModelStatus.degraded;

  Model3Data toModel3Data() {
    return Model3Data(
      motionGroups: motionGroups,
      expressions: expressions,
      parameters: parameters
          .map((parameter) => parameter.toModel3Parameter())
          .toList(growable: false),
      hitAreas: hitAreas,
    );
  }

  static Map<String, List<String>> _freezeMotionGroups(
    Map<String, List<String>> source,
  ) {
    final sorted = SplayTreeMap<String, List<String>>();
    for (final entry in source.entries) {
      sorted[entry.key] = List<String>.unmodifiable(entry.value);
    }
    return UnmodifiableMapView<String, List<String>>(sorted);
  }
}

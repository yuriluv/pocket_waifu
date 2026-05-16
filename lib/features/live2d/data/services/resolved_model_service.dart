import '../models/model3_data.dart';
import '../models/resolved_model.dart';
import 'live2d_native_bridge.dart';

class ResolvedModelRuntimeSnapshot {
  const ResolvedModelRuntimeSnapshot({
    required this.runtimeBridgeAvailable,
    required this.parameterIds,
    required this.parameterValues,
    required this.motionGroups,
    required this.expressions,
    this.unavailableReason,
    this.readFailed = false,
  });

  const ResolvedModelRuntimeSnapshot.unavailable({
    required String reason,
    bool readFailed = false,
  }) : this(
         runtimeBridgeAvailable: false,
         parameterIds: const <String>[],
         parameterValues: const <String, double>{},
         motionGroups: const <String, List<String>>{},
         expressions: const <String>[],
         unavailableReason: reason,
         readFailed: readFailed,
       );

  final bool runtimeBridgeAvailable;
  final List<String> parameterIds;
  final Map<String, double> parameterValues;
  final Map<String, List<String>> motionGroups;
  final List<String> expressions;
  final String? unavailableReason;
  final bool readFailed;
}

abstract class ResolvedModelRuntimeSource {
  Future<ResolvedModelRuntimeSnapshot> read();
}

class Live2DNativeResolvedModelRuntimeSource
    implements ResolvedModelRuntimeSource {
  Live2DNativeResolvedModelRuntimeSource({Live2DNativeBridge? bridge})
    : _bridge = bridge ?? Live2DNativeBridge();

  final Live2DNativeBridge _bridge;

  @override
  Future<ResolvedModelRuntimeSnapshot> read() async {
    try {
      final health = await _bridge.getHealthStatus();
      final error = health['error']?.toString();
      if (error != null && error.isNotEmpty) {
        return ResolvedModelRuntimeSnapshot.unavailable(reason: error);
      }

      final parameterIds = await _bridge.getParameterIds();
      final parameterValues = await _bridge.getRuntimeParameterValues();

      final groups = await _bridge.getMotionGroups();
      final motionGroups = <String, List<String>>{};
      for (final group in groups) {
        final names = await _bridge.getMotionNames(group);
        if (names.isNotEmpty) {
          motionGroups[group] = names;
          continue;
        }
        final count = await _bridge.getMotionCount(group);
        motionGroups[group] = List<String>.generate(
          count,
          (index) => '$group[$index]',
        );
      }

      final expressions = await _bridge.getExpressions();

      return ResolvedModelRuntimeSnapshot(
        runtimeBridgeAvailable: true,
        parameterIds: parameterIds,
        parameterValues: parameterValues,
        motionGroups: motionGroups,
        expressions: expressions,
      );
    } catch (e) {
      return ResolvedModelRuntimeSnapshot.unavailable(
        reason: e.toString(),
        readFailed: true,
      );
    }
  }
}

class ResolvedModelService {
  ResolvedModelService({ResolvedModelRuntimeSource? runtimeSource})
    : _runtimeSource = runtimeSource ?? Live2DNativeResolvedModelRuntimeSource();

  static const double _runtimeFallbackMin = -1e9;
  static const double _runtimeFallbackMax = 1e9;

  final ResolvedModelRuntimeSource _runtimeSource;

  Future<ResolvedModel> resolve(Model3Data staticData) async {
    final runtime = await _runtimeSource.read();

    final mergedMotions = _mergeMotionGroups(
      staticData.motionGroups,
      runtime.motionGroups,
    );
    final mergedExpressions = _mergeExpressions(
      staticData.expressions,
      runtime.expressions,
    );
    final mergedParameters = _mergeParameters(
      staticData.parameters,
      runtime.parameterIds,
      runtime.parameterValues,
    );

    final usedRuntimeParameterFallback =
        staticData.parameters.isEmpty && mergedParameters.isNotEmpty;
    final usedRuntimeMotionFallback =
        staticData.motionGroups.isEmpty && mergedMotions.isNotEmpty;

    final isDegraded = !runtime.runtimeBridgeAvailable;

    return ResolvedModel(
      status: isDegraded ? ResolvedModelStatus.degraded : ResolvedModelStatus.ready,
      motionGroups: mergedMotions,
      expressions: mergedExpressions,
      parameters: mergedParameters,
      hitAreas: staticData.hitAreas,
      diagnostics: ResolvedModelDiagnostics(
        runtimeBridgeAvailable: runtime.runtimeBridgeAvailable,
        usedRuntimeParameterFallback: usedRuntimeParameterFallback,
        usedRuntimeMotionFallback: usedRuntimeMotionFallback,
        degradedReason: isDegraded
            ? (runtime.readFailed
                  ? ResolvedModelDegradedReason.runtimeReadFailed
                  : ResolvedModelDegradedReason.runtimeBridgeUnavailable)
            : null,
        degradedMessage: runtime.unavailableReason,
      ),
    );
  }

  Map<String, List<String>> _mergeMotionGroups(
    Map<String, List<String>> staticGroups,
    Map<String, List<String>> runtimeGroups,
  ) {
    final merged = <String, List<String>>{};
    final keys = <String>{...staticGroups.keys, ...runtimeGroups.keys}.toList()
      ..sort(_compareStable);

    for (final key in keys) {
      final values = <String>[];
      final seen = <String>{};

      for (final item in staticGroups[key] ?? const <String>[]) {
        if (item.isEmpty || !seen.add(item)) {
          continue;
        }
        values.add(item);
      }

      for (final item in runtimeGroups[key] ?? const <String>[]) {
        if (item.isEmpty || !seen.add(item)) {
          continue;
        }
        values.add(item);
      }

      merged[key] = values;
    }

    return merged;
  }

  List<Model3Expression> _mergeExpressions(
    List<Model3Expression> staticExpressions,
    List<String> runtimeExpressionNames,
  ) {
    final merged = <Model3Expression>[];
    final seen = <String>{};

    for (final expression in staticExpressions) {
      final key = expression.name.trim().toLowerCase();
      if (key.isEmpty || !seen.add(key)) {
        continue;
      }
      merged.add(expression);
    }

    final runtimeSorted = runtimeExpressionNames
        .where((name) => name.isNotEmpty)
        .toList()
      ..sort(_compareStable);
    for (final name in runtimeSorted) {
      final key = name.toLowerCase();
      if (!seen.add(key)) {
        continue;
      }
      merged.add(Model3Expression(name: name, filePath: name));
    }

    return merged;
  }

  List<ResolvedModelParameter> _mergeParameters(
    List<Model3Parameter> staticParameters,
    List<String> runtimeParameterIds,
    Map<String, double> runtimeValues,
  ) {
    final byId = <String, ResolvedModelParameter>{};

    for (final param in staticParameters) {
      byId[param.id] = ResolvedModelParameter(
        id: param.id,
        name: param.name,
        min: param.min,
        defaultValue: param.defaultValue,
        max: param.max,
        runtimeValue: runtimeValues[param.id],
        source: runtimeValues.containsKey(param.id)
            ? ResolvedParameterSource.merged
            : ResolvedParameterSource.staticOnly,
      );
    }

    final runtimeIds = <String>{...runtimeParameterIds, ...runtimeValues.keys}
        .where((id) => id.isNotEmpty)
        .toList()
      ..sort(_compareStable);

    for (final id in runtimeIds) {
      if (byId.containsKey(id)) {
        continue;
      }
      final runtimeValue = runtimeValues[id] ?? 0.0;
      byId[id] = ResolvedModelParameter(
        id: id,
        name: id,
        min: _runtimeFallbackMin,
        defaultValue: runtimeValue,
        max: _runtimeFallbackMax,
        runtimeValue: runtimeValues[id],
        source: ResolvedParameterSource.runtimeOnly,
      );
    }

    return byId.values.toList(growable: false)
      ..sort((a, b) => _compareStable(a.id, b.id));
  }

  int _compareStable(String a, String b) {
    final lower = a.toLowerCase().compareTo(b.toLowerCase());
    if (lower != 0) {
      return lower;
    }
    return a.compareTo(b);
  }
}

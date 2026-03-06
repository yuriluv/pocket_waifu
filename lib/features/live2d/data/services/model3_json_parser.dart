import 'dart:convert';
import 'dart:io';

import '../models/model3_data.dart';
import 'live2d_log_service.dart';

class Model3JsonParser {
  static const String _tag = 'Model3JsonParser';

  Future<Model3Data> parseFile(String model3Path) async {
    try {
      final modelFile = File(model3Path);
      if (!await modelFile.exists()) {
        live2dLog.warning(_tag, 'model3.json file not found', details: model3Path);
        return Model3Data.empty;
      }

      final raw = await modelFile.readAsString();
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        live2dLog.warning(_tag, 'model3.json root is not an object', details: model3Path);
        return Model3Data.empty;
      }

      final basic = _parseDecoded(decoded, source: model3Path);
      final modelDir = modelFile.parent;

      final cdiBundle = await _loadCdiBundle(
        root: decoded,
        modelDir: modelDir,
        source: model3Path,
      );
      final physicsBundle = await _loadPhysicsBundle(
        root: decoded,
        modelDir: modelDir,
        source: model3Path,
      );

      final mergedParams = _mergeParametersWithCdi(
        base: basic.parameters,
        cdi: cdiBundle,
      );

      return Model3Data(
        motionGroups: basic.motionGroups,
        expressions: basic.expressions,
        parameters: mergedParams,
        hitAreas: basic.hitAreas,
        parts: cdiBundle?.parts ?? const <Model3Part>[],
        physicsMeta: physicsBundle?.meta,
        physicsSettings: physicsBundle?.settings ?? const <Model3PhysicsSetting>[],
        displayInfoPath: cdiBundle?.filePath,
        physicsPath: physicsBundle?.filePath,
      );
    } catch (e, stack) {
      live2dLog.error(
        _tag,
        'Failed to parse model3.json with linked files',
        details: model3Path,
        error: e,
        stackTrace: stack,
      );
      return Model3Data.empty;
    }
  }

  Model3Data parseContent(String rawJson, {String source = 'memory'}) {
    try {
      final decoded = jsonDecode(rawJson);
      if (decoded is! Map<String, dynamic>) {
        live2dLog.warning(_tag, 'model3.json root is not an object', details: source);
        return Model3Data.empty;
      }
      return _parseDecoded(decoded, source: source);
    } catch (e, stack) {
      live2dLog.warning(
        _tag,
        'Malformed model3.json, returning empty data',
        details: source,
        error: e,
      );
      live2dLog.debug(_tag, 'Malformed parse stack trace', details: '$stack');
      return Model3Data.empty;
    }
  }

  Model3Data _parseDecoded(Map<String, dynamic> decoded, {required String source}) {
    final motionGroups = _parseMotionGroups(decoded, source);
    final expressions = _parseExpressions(decoded, source);
    final parameters = _parseParameters(decoded, source);
    final hitAreas = _parseHitAreas(decoded, source);
    return Model3Data(
      motionGroups: motionGroups,
      expressions: expressions,
      parameters: parameters,
      hitAreas: hitAreas,
    );
  }

  Map<String, List<String>> _parseMotionGroups(
    Map<String, dynamic> root,
    String source,
  ) {
    final fileRefs = root['FileReferences'];
    final motionRoot = fileRefs is Map<String, dynamic>
        ? fileRefs['Motions']
        : root['Motions'];

    if (motionRoot is! Map<String, dynamic>) {
      live2dLog.warning(_tag, 'No motion groups found in model3.json', details: source);
      return const <String, List<String>>{};
    }

    final out = <String, List<String>>{};
    for (final entry in motionRoot.entries) {
      final groupName = entry.key;
      final groupValue = entry.value;
      if (groupValue is! List) {
        continue;
      }

      final files = <String>[];
      for (final item in groupValue) {
        if (item is Map<String, dynamic>) {
          final filePath = item['File'];
          if (filePath is String && filePath.isNotEmpty) {
            files.add(filePath);
          }
        }
      }

      out[groupName] = files;
    }

    return out;
  }

  List<Model3Expression> _parseExpressions(
    Map<String, dynamic> root,
    String source,
  ) {
    final fileRefs = root['FileReferences'];
    final expressionRoot = fileRefs is Map<String, dynamic>
        ? fileRefs['Expressions']
        : root['Expressions'];

    if (expressionRoot is! List) {
      live2dLog.warning(_tag, 'No expressions found in model3.json', details: source);
      return const <Model3Expression>[];
    }

    final out = <Model3Expression>[];
    for (final item in expressionRoot) {
      if (item is! Map<String, dynamic>) {
        continue;
      }
      final filePath = item['File'];
      if (filePath is! String || filePath.isEmpty) {
        continue;
      }
      final name = item['Name'];
      out.add(
        Model3Expression(
          name: name is String && name.isNotEmpty ? name : filePath,
          filePath: filePath,
        ),
      );
    }

    return out;
  }

  List<Model3Parameter> _parseParameters(
    Map<String, dynamic> root,
    String source,
  ) {
    final parameterRoot = root['Parameters'] ??
        (root['FileReferences'] is Map<String, dynamic>
            ? (root['FileReferences'] as Map<String, dynamic>)['Parameters']
            : null);

    if (parameterRoot is! List) {
      final groups = root['Groups'];
      if (groups is List) {
        final paramGroup = groups
            .whereType<Map<String, dynamic>>()
            .where((g) => g['Target'] == 'Parameter')
            .toList();
        if (paramGroup.isNotEmpty) {
          live2dLog.debug(
            _tag,
            'Found parameter groups but no parameter definitions',
            details: source,
          );
        }
      }
      live2dLog.warning(_tag, 'No parameter definitions found in model3.json', details: source);
      return const <Model3Parameter>[];
    }

    final out = <Model3Parameter>[];
    for (final item in parameterRoot) {
      if (item is! Map<String, dynamic>) {
        continue;
      }

      final id = item['Id'];
      if (id is! String || id.isEmpty) {
        continue;
      }

      final displayName = item['Name'];
      final min = _toDouble(item['Min']) ?? _defaultMinForId(id);
      final defaultValue = _toDouble(item['Default']) ?? _defaultValueForId(id, min);
      final max = _toDouble(item['Max']) ?? _defaultMaxForId(id, defaultValue);

      out.add(
        Model3Parameter(
          id: id,
          name: displayName is String && displayName.isNotEmpty ? displayName : id,
          min: min,
          defaultValue: defaultValue,
          max: max,
        ),
      );
    }

    return out;
  }

  List<Model3HitArea> _parseHitAreas(
    Map<String, dynamic> root,
    String source,
  ) {
    final hitAreaRoot = root['HitAreas'];
    if (hitAreaRoot is! List) {
      live2dLog.warning(_tag, 'No hit areas found in model3.json', details: source);
      return const <Model3HitArea>[];
    }

    final out = <Model3HitArea>[];
    for (final item in hitAreaRoot) {
      if (item is! Map<String, dynamic>) {
        continue;
      }

      final name = item['Name'];
      final id = item['Id'];
      if (name is! String || name.isEmpty || id is! String || id.isEmpty) {
        continue;
      }

      out.add(Model3HitArea(name: name, meshIds: <String>[id]));
    }

    return out;
  }

  Future<_CdiBundle?> _loadCdiBundle({
    required Map<String, dynamic> root,
    required Directory modelDir,
    required String source,
  }) async {
    final ref = _fileReference(root, 'DisplayInfo');
    if (ref == null || ref.isEmpty) {
      return null;
    }

    final file = File(_resolveRelativePath(modelDir.path, ref));
    if (!await file.exists()) {
      live2dLog.warning(_tag, 'cdi3 file not found', details: file.path);
      return null;
    }

    try {
      final raw = await file.readAsString();
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        return null;
      }

      final parameterNames = <String, String>{};
      final parameterRoot = decoded['Parameters'];
      if (parameterRoot is List) {
        for (final item in parameterRoot) {
          if (item is! Map<String, dynamic>) continue;
          final id = item['Id'];
          final name = item['Name'];
          if (id is String && id.isNotEmpty && name is String && name.isNotEmpty) {
            parameterNames[id] = name;
          }
        }
      }

      final parts = <Model3Part>[];
      final partsRoot = decoded['Parts'];
      if (partsRoot is List) {
        for (final item in partsRoot) {
          if (item is! Map<String, dynamic>) continue;
          final id = item['Id'];
          final name = item['Name'];
          if (id is String && id.isNotEmpty) {
            parts.add(
              Model3Part(
                id: id,
                name: name is String && name.isNotEmpty ? name : id,
              ),
            );
          }
        }
      }

      return _CdiBundle(
        filePath: file.path,
        parameterNames: parameterNames,
        parts: parts,
      );
    } catch (e) {
      live2dLog.warning(_tag, 'Failed to parse cdi3.json', details: '$source => $e');
      return null;
    }
  }

  Future<_PhysicsBundle?> _loadPhysicsBundle({
    required Map<String, dynamic> root,
    required Directory modelDir,
    required String source,
  }) async {
    final ref = _fileReference(root, 'Physics');
    if (ref == null || ref.isEmpty) {
      return null;
    }

    final file = File(_resolveRelativePath(modelDir.path, ref));
    if (!await file.exists()) {
      live2dLog.warning(_tag, 'physics3 file not found', details: file.path);
      return null;
    }

    try {
      final raw = await file.readAsString();
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        return null;
      }

      final metaRaw = decoded['Meta'];
      final meta = _parsePhysicsMeta(metaRaw is Map<String, dynamic> ? metaRaw : null);
      final settings = _parsePhysicsSettings(decoded);

      return _PhysicsBundle(
        filePath: file.path,
        meta: meta,
        settings: settings,
      );
    } catch (e) {
      live2dLog.warning(_tag, 'Failed to parse physics3.json', details: '$source => $e');
      return null;
    }
  }

  List<Model3Parameter> _mergeParametersWithCdi({
    required List<Model3Parameter> base,
    required _CdiBundle? cdi,
  }) {
    if (cdi == null) {
      return base;
    }

    final byId = <String, Model3Parameter>{
      for (final item in base) item.id: item,
    };

    for (final entry in cdi.parameterNames.entries) {
      final existing = byId[entry.key];
      if (existing == null) {
        byId[entry.key] = Model3Parameter(
          id: entry.key,
          name: entry.value,
          min: _defaultMinForId(entry.key),
          defaultValue: _defaultValueForId(entry.key, _defaultMinForId(entry.key)),
          max: _defaultMaxForId(entry.key, _defaultValueForId(entry.key, _defaultMinForId(entry.key))),
        );
        continue;
      }

      byId[entry.key] = Model3Parameter(
        id: existing.id,
        name: entry.value,
        min: existing.min,
        defaultValue: existing.defaultValue,
        max: existing.max,
      );
    }

    final merged = byId.values.toList(growable: false);
    merged.sort((a, b) => a.id.compareTo(b.id));
    return merged;
  }

  Model3PhysicsMeta? _parsePhysicsMeta(Map<String, dynamic>? raw) {
    if (raw == null) {
      return null;
    }

    final forces = raw['EffectiveForces'];
    final gravity = forces is Map<String, dynamic> ? forces['Gravity'] : null;
    final wind = forces is Map<String, dynamic> ? forces['Wind'] : null;

    return Model3PhysicsMeta(
      fps: _toInt(raw['Fps']) ?? 30,
      settingCount: _toInt(raw['PhysicsSettingCount']) ?? 0,
      totalInputCount: _toInt(raw['TotalInputCount']) ?? 0,
      totalOutputCount: _toInt(raw['TotalOutputCount']) ?? 0,
      vertexCount: _toInt(raw['VertexCount']) ?? 0,
      gravityX: _toDouble(gravity is Map<String, dynamic> ? gravity['X'] : null) ?? 0,
      gravityY: _toDouble(gravity is Map<String, dynamic> ? gravity['Y'] : null) ?? -1,
      windX: _toDouble(wind is Map<String, dynamic> ? wind['X'] : null) ?? 0,
      windY: _toDouble(wind is Map<String, dynamic> ? wind['Y'] : null) ?? 0,
    );
  }

  List<Model3PhysicsSetting> _parsePhysicsSettings(Map<String, dynamic> root) {
    final dictById = <String, String>{};
    final meta = root['Meta'];
    if (meta is Map<String, dynamic>) {
      final dict = meta['PhysicsDictionary'];
      if (dict is List) {
        for (final item in dict) {
          if (item is! Map<String, dynamic>) continue;
          final id = item['Id'];
          final name = item['Name'];
          if (id is String && id.isNotEmpty) {
            dictById[id] = name is String && name.isNotEmpty ? name : id;
          }
        }
      }
    }

    final out = <Model3PhysicsSetting>[];
    final settings = root['PhysicsSettings'];
    if (settings is! List) {
      return out;
    }

    for (final item in settings) {
      if (item is! Map<String, dynamic>) continue;
      final id = item['Id'];
      if (id is! String || id.isEmpty) continue;

      final vertices = item['Vertices'];
      var delaySum = 0.0;
      var mobilitySum = 0.0;
      var count = 0;
      if (vertices is List) {
        for (final vertex in vertices) {
          if (vertex is! Map<String, dynamic>) continue;
          delaySum += _toDouble(vertex['Delay']) ?? 0.0;
          mobilitySum += _toDouble(vertex['Mobility']) ?? 0.0;
          count += 1;
        }
      }

      final averageDelay = count > 0 ? delaySum / count : 0.0;
      final averageMobility = count > 0 ? mobilitySum / count : 0.0;
      out.add(
        Model3PhysicsSetting(
          id: id,
          name: dictById[id] ?? id,
          averageDelay: averageDelay,
          averageMobility: averageMobility,
        ),
      );
    }

    return out;
  }

  String? _fileReference(Map<String, dynamic> root, String key) {
    final fileRefs = root['FileReferences'];
    if (fileRefs is! Map<String, dynamic>) {
      return null;
    }
    final value = fileRefs[key];
    return value is String && value.isNotEmpty ? value : null;
  }

  String _resolveRelativePath(String baseDir, String relativePath) {
    final normalized = relativePath.replaceAll('\\', '/');
    return File('$baseDir/$normalized').path;
  }

  int? _toInt(Object? raw) {
    if (raw is int) {
      return raw;
    }
    if (raw is num) {
      return raw.round();
    }
    if (raw is String) {
      return int.tryParse(raw);
    }
    return null;
  }

  double? _toDouble(Object? raw) {
    if (raw is num) {
      return raw.toDouble();
    }
    if (raw is String) {
      return double.tryParse(raw);
    }
    return null;
  }

  double _defaultMinForId(String id) {
    if (_isUnitStyleParameter(id)) {
      return 0.0;
    }
    return -30.0;
  }

  double _defaultMaxForId(String id, double defaultValue) {
    if (_isUnitStyleParameter(id)) {
      return 1.0;
    }
    if (defaultValue > 30.0) {
      return defaultValue;
    }
    return 30.0;
  }

  double _defaultValueForId(String id, double min) {
    if (_isUnitStyleParameter(id)) {
      return 1.0;
    }
    return min.abs() < 0.0001 ? min : 0.0;
  }

  bool _isUnitStyleParameter(String id) {
    final lower = id.toLowerCase();
    return lower.contains('open') ||
        lower.contains('smile') ||
        lower.contains('opacity') ||
        lower.contains('alpha') ||
        lower.contains('weight') ||
        lower.contains('eye');
  }
}

class _CdiBundle {
  const _CdiBundle({
    required this.filePath,
    required this.parameterNames,
    required this.parts,
  });

  final String filePath;
  final Map<String, String> parameterNames;
  final List<Model3Part> parts;
}

class _PhysicsBundle {
  const _PhysicsBundle({
    required this.filePath,
    required this.meta,
    required this.settings,
  });

  final String filePath;
  final Model3PhysicsMeta? meta;
  final List<Model3PhysicsSetting> settings;
}

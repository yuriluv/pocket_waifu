import 'dart:convert';
import 'dart:io';

import '../models/model3_data.dart';
import 'live2d_log_service.dart';

class Model3JsonParser {
  static const String _tag = 'Model3JsonParser';

  Future<Model3Data> parseFile(String model3Path) async {
    try {
      final file = File(model3Path);
      if (!await file.exists()) {
        live2dLog.warning(_tag, 'model3.json file not found', details: model3Path);
        return Model3Data.empty;
      }

      final raw = await file.readAsString();
      return parseContent(raw, source: model3Path);
    } catch (e, stack) {
      live2dLog.error(
        _tag,
        'Failed to read model3.json',
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
    // Check multiple locations where parameters might be defined
    final parameterRoot = root['Parameters']
        ?? (root['FileReferences'] is Map<String, dynamic>
            ? (root['FileReferences'] as Map<String, dynamic>)['Parameters']
            : null);

    if (parameterRoot is! List) {
      // Try to find parameter groups (CDI3 format)
      final groups = root['Groups'];
      if (groups is List) {
        final paramGroup = groups.whereType<Map<String, dynamic>>()
            .where((g) => g['Target'] == 'Parameter')
            .toList();
        if (paramGroup.isNotEmpty) {
          live2dLog.debug(_tag, 'Found parameter groups but no parameter definitions', details: source);
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
      final min = _toDouble(item['Min']) ?? 0.0;
      final defaultValue = _toDouble(item['Default']) ?? min;
      final max = _toDouble(item['Max']) ?? defaultValue;

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

  double? _toDouble(Object? raw) {
    if (raw is num) {
      return raw.toDouble();
    }
    if (raw is String) {
      return double.tryParse(raw);
    }
    return null;
  }
}

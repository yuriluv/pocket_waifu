import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/live2d_parameter_preset.dart';

class Live2DSettingsRepository {
  Live2DSettingsRepository._internal();

  static final Live2DSettingsRepository _instance =
      Live2DSettingsRepository._internal();
  factory Live2DSettingsRepository() => _instance;

  static const String _motionEnabledPrefix = 'live2d_motion_enabled_';

  String _modelKey(String modelPath) {
    final normalized = modelPath.replaceAll('\\', '/').toLowerCase();
    return normalized
        .replaceAll(':', '_')
        .replaceAll('/', '_')
        .replaceAll('.', '_');
  }

  String _motionEnabledKey(String modelPath) {
    return '$_motionEnabledPrefix${_modelKey(modelPath)}';
  }

  Future<Map<String, bool>> loadMotionEnabled(String modelPath) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_motionEnabledKey(modelPath));
    if (raw == null || raw.isEmpty) {
      return <String, bool>{};
    }
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      return <String, bool>{};
    }
    return decoded.map(
      (key, value) => MapEntry(key, value == true),
    );
  }

  Future<void> saveMotionEnabled(String modelPath, Map<String, bool> map) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_motionEnabledKey(modelPath), jsonEncode(map));
  }

  Future<List<Live2DParameterPreset>> loadParameterPresets(String modelPath) async {
    final file = await _presetFile(modelPath);
    if (!await file.exists()) {
      return <Live2DParameterPreset>[];
    }
    final raw = await file.readAsString();
    if (raw.isEmpty) {
      return <Live2DParameterPreset>[];
    }
    final decoded = jsonDecode(raw);
    if (decoded is! List) {
      return <Live2DParameterPreset>[];
    }
    return decoded
        .whereType<Map>()
        .map((e) => Live2DParameterPreset.fromJson(Map<String, dynamic>.from(e)))
        .toList(growable: false);
  }

  Future<void> saveParameterPresets(
    String modelPath,
    List<Live2DParameterPreset> presets,
  ) async {
    final file = await _presetFile(modelPath);
    await file.parent.create(recursive: true);
    final encoded = jsonEncode(presets.map((e) => e.toJson()).toList(growable: false));
    await file.writeAsString(encoded);
  }

  Future<String> exportParameterPresets(
    String modelPath,
    List<Live2DParameterPreset> presets,
  ) async {
    final docsDir = await getApplicationDocumentsDirectory();
    final exportDir = Directory('${docsDir.path}/live2d_exports');
    await exportDir.create(recursive: true);
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final model = _modelKey(modelPath);
    final file = File('${exportDir.path}/presets_${model}_$timestamp.json');
    final encoded = jsonEncode(presets.map((e) => e.toJson()).toList(growable: false));
    await file.writeAsString(encoded);
    return file.path;
  }

  Future<List<Live2DParameterPreset>> importParameterPresets(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      return <Live2DParameterPreset>[];
    }
    final raw = await file.readAsString();
    if (raw.isEmpty) {
      return <Live2DParameterPreset>[];
    }
    final decoded = jsonDecode(raw);
    if (decoded is! List) {
      return <Live2DParameterPreset>[];
    }
    return decoded
        .whereType<Map>()
        .map((e) => Live2DParameterPreset.fromJson(Map<String, dynamic>.from(e)))
        .toList(growable: false);
  }

  Future<File> _presetFile(String modelPath) async {
    final docsDir = await getApplicationDocumentsDirectory();
    return File('${docsDir.path}/live2d/presets_${_modelKey(modelPath)}.json');
  }
}

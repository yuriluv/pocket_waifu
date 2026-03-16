import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/interaction_preset.dart';

class InteractionPresetProvider extends ChangeNotifier {
  static const String _presetsKey = 'interaction_presets_v1';

  bool _isLoading = false;
  List<InteractionPreset> _presets = <InteractionPreset>[];

  bool get isLoading => _isLoading;
  List<InteractionPreset> get presets => List.unmodifiable(_presets);

  InteractionPresetProvider() {
    loadPresets();
  }

  Future<void> loadPresets() async {
    _isLoading = true;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_presetsKey);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          _presets = decoded
              .whereType<Map>()
              .map((entry) => InteractionPreset.fromMap(Map<String, dynamic>.from(entry)))
              .toList(growable: true);
        }
      }
    } catch (e) {
      debugPrint('InteractionPresetProvider.loadPresets failed: $e');
      _presets = <InteractionPreset>[];
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> _savePresets() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _presetsKey,
        jsonEncode(_presets.map((preset) => preset.toMap()).toList(growable: false)),
      );
    } catch (e) {
      debugPrint('InteractionPresetProvider._savePresets failed: $e');
    }
  }

  void addPreset(String name, {String html = '', String css = ''}) {
    _presets.add(
      InteractionPreset(
        name: name.trim().isEmpty ? 'Preset ${_presets.length + 1}' : name.trim(),
        html: html,
        css: css,
      ),
    );
    notifyListeners();
    _savePresets();
  }

  void updatePreset(InteractionPreset preset) {
    final index = _presets.indexWhere((item) => item.id == preset.id);
    if (index == -1) {
      return;
    }
    _presets[index] = preset;
    notifyListeners();
    _savePresets();
  }

  void renamePreset(String id, String name) {
    final index = _presets.indexWhere((item) => item.id == id);
    if (index == -1) {
      return;
    }
    _presets[index] = _presets[index].copyWith(
      name: name.trim().isEmpty ? _presets[index].name : name.trim(),
    );
    notifyListeners();
    _savePresets();
  }

  void deletePreset(String id) {
    _presets.removeWhere((item) => item.id == id);
    notifyListeners();
    _savePresets();
  }

  InteractionPreset? getPresetById(String? id) {
    if (id == null) {
      return null;
    }
    for (final preset in _presets) {
      if (preset.id == id) {
        return preset;
      }
    }
    return null;
  }

  Future<(bool, String?)> exportPresetToFile(InteractionPreset preset) async {
    try {
      final fileName = _sanitizeExportFileName('${preset.name}.json');
      final jsonString = jsonEncode(preset.toMap());
      String? filePath;
      try {
        filePath = await FilePicker.platform.saveFile(
          dialogTitle: '상호작용 프리셋 저장',
          fileName: fileName,
          type: FileType.custom,
          allowedExtensions: const ['json'],
          bytes: utf8.encode(jsonString),
        );
      } catch (_) {}

      filePath ??= await _resolveFallbackExportPath(fileName);
      if (filePath == null) {
        return (false, '저장 경로를 찾을 수 없습니다.');
      }
      if (kIsWeb) {
        return (true, '브라우저 다운로드를 확인하세요.');
      }

      final parent = Directory(p.dirname(filePath));
      if (!await parent.exists()) {
        await parent.create(recursive: true);
      }
      await File(filePath).writeAsString(jsonString);
      return (true, '저장 위치: $filePath');
    } catch (e) {
      return (false, '내보내기 실패: $e');
    }
  }

  Future<(bool, String?)> importPresetFromFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['json'],
        withData: true,
      );
      if (result == null || result.files.isEmpty) {
        return (false, '가져오기가 취소되었습니다.');
      }

      final file = result.files.single;
      final rawJson = file.bytes != null
          ? utf8.decode(file.bytes!, allowMalformed: true)
          : await File(file.path!).readAsString();
      final decoded = jsonDecode(rawJson);
      if (decoded is! Map) {
        return (false, '프리셋 JSON 형식이 올바르지 않습니다.');
      }

      final preset = InteractionPreset.fromMap(Map<String, dynamic>.from(decoded));
      _presets.add(
        InteractionPreset(
          name: preset.name,
          html: preset.html,
          css: preset.css,
        ),
      );
      notifyListeners();
      await _savePresets();
      return (true, null);
    } catch (e) {
      return (false, '가져오기 실패: $e');
    }
  }

  Future<String?> _resolveFallbackExportPath(String fileName) async {
    try {
      final docsDir = await getApplicationDocumentsDirectory();
      return p.join(docsDir.path, fileName);
    } catch (_) {
      return null;
    }
  }

  String _sanitizeExportFileName(String fileName) {
    final sanitized = fileName
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (sanitized.isEmpty || sanitized == '.json') {
      return 'interaction_preset.json';
    }
    return sanitized.toLowerCase().endsWith('.json')
        ? sanitized
        : '$sanitized.json';
  }
}

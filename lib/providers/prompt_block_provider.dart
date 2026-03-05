import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../models/prompt_block.dart';
import '../models/prompt_preset.dart';
import '../models/message.dart';
import '../services/prompt_builder.dart';

class PromptBlockProvider extends ChangeNotifier {
  static const String _presetsKey = 'prompt_presets';
  static const String _activePresetKey = 'active_prompt_preset_id';
  static const String _legacyBlocksKey = 'prompt_blocks';
  static const String _legacyPastMessageCountKey = 'past_message_count';

  final PromptBuilder _promptBuilder = PromptBuilder();
  final Uuid _uuid = const Uuid();

  bool _isLoading = false;
  List<PromptPreset> _presets = [];
  String? _activePresetId;
  List<PromptBlock> _workingBlocks = [];
  bool _hasUnsavedChanges = false;

  bool get isLoading => _isLoading;
  List<PromptPreset> get presets => List.unmodifiable(_presets);
  String? get activePresetId => _activePresetId;
  bool get hasUnsavedChanges => _hasUnsavedChanges;
  List<PromptBlock> get blocks => List.unmodifiable(_workingBlocks);

  PromptPreset? get activePreset {
    if (_activePresetId == null) return null;
    try {
      return _presets.firstWhere((p) => p.id == _activePresetId);
    } catch (_) {
      return _presets.isNotEmpty ? _presets.first : null;
    }
  }

  PromptBlockProvider() {
    loadPresets();
  }

  Future<void> loadPresets() async {
    _isLoading = true;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      final String? presetsJson = prefs.getString(_presetsKey);

      if (presetsJson != null) {
        final List<dynamic> presetList = jsonDecode(presetsJson);
        _presets = presetList
            .whereType<Map<String, dynamic>>()
            .map(PromptPreset.fromMap)
            .toList();
        _presets = _presets
            .map(
              (preset) =>
                  preset.copyWith(blocks: _normalizeBlocks(preset.blocks)),
            )
            .toList();
      }

      if (_presets.isEmpty) {
        await _migrateLegacyBlocks(prefs);
      }

      if (_presets.isEmpty) {
        _presets = [_buildDefaultPreset()];
      }

      _activePresetId = prefs.getString(_activePresetKey);
      if (_activePresetId == null ||
          !_presets.any((p) => p.id == _activePresetId)) {
        _activePresetId = _presets.first.id;
      }

      _setWorkingBlocks(_cloneBlocks(activePreset?.blocks ?? []));
    } catch (e) {
      debugPrint('프롬프트 프리셋 불러오기 실패: $e');
      _presets = [_buildDefaultPreset()];
      _activePresetId = _presets.first.id;
      _setWorkingBlocks(_cloneBlocks(_presets.first.blocks));
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> _migrateLegacyBlocks(SharedPreferences prefs) async {
    final legacyJson = prefs.getString(_legacyBlocksKey);
    if (legacyJson == null) return;

    try {
      final List<dynamic> legacyList = jsonDecode(legacyJson);
      if (legacyList.isEmpty) return;

      final int legacyPastCount =
          prefs.getInt(_legacyPastMessageCountKey) ?? 10;

      final legacyBlocks = legacyList
          .whereType<Map<String, dynamic>>()
          .toList();
      legacyBlocks.sort((a, b) {
        final aOrder = a['order'] ?? 0;
        final bOrder = b['order'] ?? 0;
        return aOrder.compareTo(bOrder);
      });

      final migratedBlocks = <PromptBlock>[];
      for (final legacy in legacyBlocks) {
        final legacyType = legacy['type']?.toString() ?? 'custom';
        final legacyName = legacy['name']?.toString() ?? 'Prompt';
        final legacyContent = legacy['content']?.toString() ?? '';
        final legacyEnabled = legacy['isEnabled'] ?? true;

        if (legacyType == 'past_memory') {
          migratedBlocks.add(
            PromptBlock.pastMemory(
              title: legacyName,
              range: legacyPastCount.toString(),
              isActive: legacyEnabled,
            ),
          );
        } else if (legacyType == 'user_input') {
          migratedBlocks.add(
            PromptBlock.input(title: legacyName, isActive: legacyEnabled),
          );
        } else {
          migratedBlocks.add(
            PromptBlock.prompt(
              title: legacyName,
              content: legacyContent,
              isActive: legacyEnabled,
            ),
          );
        }
      }

      final preset = PromptPreset(
        name: 'Migrated Preset',
        blocks: _normalizeBlocks(migratedBlocks),
      );
      _presets = [preset];
      _activePresetId = preset.id;
      await _savePresets();
    } catch (e) {
      debugPrint('레거시 프롬프트 블록 마이그레이션 실패: $e');
    }
  }

  PromptPreset _buildDefaultPreset() {
    final blocks = [
      PromptBlock.prompt(
        title: 'System',
        content: '''당신은 롤플레이 AI입니다.
아래의 캐릭터 정보와 시나리오에 따라 일관되게 행동하세요.
항상 캐릭터로서 응답하며, AI라는 사실을 언급하지 마세요.''',
      ),
      PromptBlock.prompt(
        title: 'Character',
        content: '''[캐릭터 이름]
미카

[캐릭터 설명]
미카는 20대 초반의 밝고 귀여운 여성입니다.
긴 검은 머리에 큰 눈을 가지고 있으며, 항상 웃는 얼굴입니다.

[성격]
- 밝고 긍정적인 성격
- 장난기가 많고 귀여운 말투를 사용
- 이모티콘과 감탄사를 자주 사용

[시나리오]
당신은 미카의 주인이며, 미카는 당신과 함께 사는 AI 동반자입니다.''',
      ),
      PromptBlock.pastMemory(title: 'Past Memory', range: '10'),
      PromptBlock.prompt(
        title: 'Command Block · Lua',
        content: '''[Lua Command Handling]
- Generate command-friendly output that can be post-processed by Lua hooks.
- Keep user-visible dialogue natural, and put machine commands in directive blocks.
- Prefer deterministic command patterns so Lua scripts can reliably transform text.
- If command is not needed, return normal dialogue only.''',
      ),
      PromptBlock.prompt(
        title: 'Command Block · Regex',
        content: '''[Regex Command Handling]
- Keep command tokens stable for regex matching.
- Use explicit key/value style in directives for reliable extraction.
- Avoid ambiguous formatting that can break regex replacement.
- Preserve natural conversation text outside directive blocks.''',
      ),
      PromptBlock.input(title: 'Input'),
    ];

    return PromptPreset(
      name: 'Default Preset',
      blocks: _normalizeBlocks(blocks),
    );
  }

  Future<void> _savePresets() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String presetsJson = jsonEncode(
        _presets.map((p) => p.toMap()).toList(),
      );
      await prefs.setString(_presetsKey, presetsJson);
      if (_activePresetId != null) {
        await prefs.setString(_activePresetKey, _activePresetId!);
      }
    } catch (e) {
      debugPrint('프롬프트 프리셋 저장 실패: $e');
    }
  }

  void _setWorkingBlocks(List<PromptBlock> blocks) {
    _workingBlocks = blocks;
    _hasUnsavedChanges = false;
  }

  List<PromptBlock> _cloneBlocks(List<PromptBlock> blocks) {
    return blocks
        .map((b) => b.copyWith(id: _uuid.v4(), order: b.order))
        .toList();
  }

  List<PromptBlock> _normalizeBlocks(List<PromptBlock> blocks) {
    final usedIds = <String>{};
    final normalized = <PromptBlock>[];

    for (int i = 0; i < blocks.length; i++) {
      var block = blocks[i];
      if (block.id.isEmpty || usedIds.contains(block.id)) {
        block = block.copyWith(id: _uuid.v4());
      }
      usedIds.add(block.id);
      normalized.add(block.copyWith(order: i));
    }

    return normalized;
  }

  void _markDirty() {
    _hasUnsavedChanges = true;
  }

  void setActivePreset(String id) {
    if (!_presets.any((p) => p.id == id)) return;
    _activePresetId = id;
    _setWorkingBlocks(_cloneBlocks(activePreset?.blocks ?? []));
    notifyListeners();
    _savePresets();
  }

  void addPreset(String name) {
    final newPreset = PromptPreset(
      name: name.trim().isEmpty ? 'New Preset' : name.trim(),
      blocks: _normalizeBlocks(_cloneBlocks(_workingBlocks)),
    );
    _presets.add(newPreset);
    _activePresetId = newPreset.id;
    _setWorkingBlocks(_cloneBlocks(newPreset.blocks));
    notifyListeners();
    _savePresets();
  }

  void saveActivePreset() {
    final preset = activePreset;
    if (preset == null) return;

    final index = _presets.indexWhere((p) => p.id == preset.id);
    if (index == -1) return;

    _presets[index] = preset.copyWith(
      blocks: _normalizeBlocks(_cloneBlocks(_workingBlocks)),
    );
    _setWorkingBlocks(_cloneBlocks(_presets[index].blocks));
    notifyListeners();
    _savePresets();
  }

  bool deletePreset(String id) {
    if (_presets.length <= 1) {
      return false;
    }

    _presets.removeWhere((p) => p.id == id);
    if (_activePresetId == id) {
      _activePresetId = _presets.first.id;
      _setWorkingBlocks(_cloneBlocks(_presets.first.blocks));
    }
    notifyListeners();
    _savePresets();
    return true;
  }

  void renamePreset(String id, String name) {
    final index = _presets.indexWhere((p) => p.id == id);
    if (index == -1) return;
    _presets[index] = _presets[index].copyWith(
      name: name.trim().isEmpty ? _presets[index].name : name.trim(),
    );
    notifyListeners();
    _savePresets();
  }

  void addBlock(PromptBlock block) {
    _workingBlocks.add(block.copyWith(id: _uuid.v4()));
    _workingBlocks = _normalizeBlocks(_workingBlocks);
    _markDirty();
    notifyListeners();
  }

  void duplicateBlock(String id) {
    final index = _workingBlocks.indexWhere((b) => b.id == id);
    if (index == -1) return;
    final clone = _workingBlocks[index].clone();
    _workingBlocks.insert(index + 1, clone);
    _workingBlocks = _normalizeBlocks(_workingBlocks);
    _markDirty();
    notifyListeners();
  }

  void removeBlock(String id) {
    _workingBlocks.removeWhere((b) => b.id == id);
    _workingBlocks = _normalizeBlocks(_workingBlocks);
    _markDirty();
    notifyListeners();
  }

  void toggleBlock(String id) {
    final index = _workingBlocks.indexWhere((b) => b.id == id);
    if (index == -1) return;
    _workingBlocks[index] = _workingBlocks[index].copyWith(
      isActive: !_workingBlocks[index].isActive,
    );
    _markDirty();
    notifyListeners();
  }

  void reorderBlocks(int oldIndex, int newIndex) {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final block = _workingBlocks.removeAt(oldIndex);
    _workingBlocks.insert(newIndex, block);
    _workingBlocks = _normalizeBlocks(_workingBlocks);
    _markDirty();
    notifyListeners();
  }

  void updateBlockContent(String id, String content) {
    final index = _workingBlocks.indexWhere((b) => b.id == id);
    if (index == -1) return;
    _workingBlocks[index] = _workingBlocks[index].copyWith(content: content);
    _markDirty();
    notifyListeners();
  }

  void updateBlockTitle(String id, String title) {
    final index = _workingBlocks.indexWhere((b) => b.id == id);
    if (index == -1) return;
    _workingBlocks[index] = _workingBlocks[index].copyWith(title: title);
    _markDirty();
    notifyListeners();
  }

  void updatePastMemoryRange(String id, String range) {
    final index = _workingBlocks.indexWhere((b) => b.id == id);
    if (index == -1) return;
    _workingBlocks[index] = _workingBlocks[index].copyWith(range: range);
    _markDirty();
    notifyListeners();
  }

  void updatePastMemoryHeaders(
    String id,
    String userHeader,
    String charHeader,
  ) {
    final index = _workingBlocks.indexWhere((b) => b.id == id);
    if (index == -1) return;
    _workingBlocks[index] = _workingBlocks[index].copyWith(
      userHeader: userHeader,
      charHeader: charHeader,
    );
    _markDirty();
    notifyListeners();
  }

  String buildFinalPrompt(
    List<Message> pastMessages,
    String currentInput, {
    String? presetId,
  }) {
    final blocks = _resolveBlocksForPreset(presetId);
    return _promptBuilder.buildFinalPrompt(
      blocks: blocks,
      pastMessages: pastMessages,
      currentInput: currentInput,
    );
  }

  List<Map<String, dynamic>> buildMessagesForApi(
    List<Message> pastMessages,
    String currentInput, {
    bool hasFirstSystemPrompt = true,
    bool requiresAlternateRole = true,
    bool skipInputBlock = false,
    String? presetId,
  }) {
    final blocks = _resolveBlocksForPreset(presetId);
    return _promptBuilder.buildMessagesForApi(
      blocks: blocks,
      pastMessages: pastMessages,
      currentInput: currentInput,
      hasFirstSystemPrompt: hasFirstSystemPrompt,
      requiresAlternateRole: requiresAlternateRole,
      skipInputBlock: skipInputBlock,
    );
  }

  List<PromptBlock> _resolveBlocksForPreset(String? presetId) {
    final targetPresetId = presetId ?? _activePresetId;
    if (targetPresetId != null) {
      for (final preset in _presets) {
        if (preset.id == targetPresetId) {
          return preset.blocks;
        }
      }
    }
    return _workingBlocks;
  }

  Future<(bool, String?)> exportPresetToFile(PromptPreset preset) async {
    try {
      final String exportFileName = _sanitizeExportFileName(
        '${preset.name}.json',
      );
      final PromptPreset exportPreset = _buildExportPreset(preset);
      final String jsonString = jsonEncode(exportPreset.toExternalMap());

      String? filePath;
      Object? pickerError;
      try {
        filePath = await FilePicker.platform.saveFile(
          dialogTitle: '프롬프트 프리셋 저장',
          fileName: exportFileName,
          type: FileType.custom,
          allowedExtensions: ['json'],
          bytes: utf8.encode(jsonString),
        );
      } catch (e) {
        pickerError = e;
      }

      if (filePath == null) {
        if (pickerError == null) {
          return (false, '저장이 취소되었습니다.');
        }
        filePath = await _resolveFallbackExportPath(exportFileName);
      }

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

      final file = File(filePath);
      await file.writeAsString(jsonString);
      return (true, '저장 위치: $filePath');
    } catch (e) {
      return (false, '저장 실패: $e');
    }
  }

  PromptPreset _buildExportPreset(PromptPreset preset) {
    final bool isActive = preset.id == _activePresetId;
    final sourceBlocks = isActive ? _workingBlocks : preset.blocks;
    return preset.copyWith(
      blocks: _normalizeBlocks(_cloneBlocks(sourceBlocks)),
    );
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
      return 'prompt_preset.json';
    }

    return sanitized.toLowerCase().endsWith('.json')
        ? sanitized
        : '$sanitized.json';
  }

  bool _parseBool(dynamic value, {required bool defaultValue}) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      if (normalized == 'true' || normalized == '1') {
        return true;
      }
      if (normalized == 'false' || normalized == '0') {
        return false;
      }
    }
    return defaultValue;
  }

  String _parseRange(dynamic value, {required String defaultValue}) {
    if (value == null) return defaultValue;
    final parsed = int.tryParse(value.toString().trim());
    if (parsed == null || parsed < 1) {
      return defaultValue;
    }
    return parsed.toString();
  }

  String _normalizeImportedType(dynamic rawType) {
    final value = rawType?.toString().trim().toLowerCase() ?? '';
    return switch (value) {
      'prompt' => PromptBlock.typePrompt,
      'input' || 'user_input' => PromptBlock.typeInput,
      'pastmemory' ||
      'past_memory' ||
      'past-memory' => PromptBlock.typePastMemory,
      _ => value,
    };
  }

  Future<String> _readPickedFileAsString(PlatformFile file) async {
    if (file.bytes != null) {
      return utf8.decode(file.bytes!, allowMalformed: true);
    }

    if (file.path == null) {
      throw const FormatException('파일을 읽을 수 없습니다.');
    }

    final bytes = await File(file.path!).readAsBytes();
    return utf8.decode(bytes, allowMalformed: true);
  }

  Future<(bool, String?)> importPresetFromFile({String? overrideName}) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        withData: true,
      );
      if (result == null || result.files.isEmpty) {
        return (false, '가져오기가 취소되었습니다.');
      }

      final file = result.files.single;
      final rawJson = await _readPickedFileAsString(file);

      final decoded = jsonDecode(rawJson);
      final (preset, error) = _parseImportedPreset(decoded, overrideName);
      if (preset == null) {
        return (false, error ?? 'JSON 파싱 실패');
      }

      _presets.add(preset);
      _activePresetId = preset.id;
      _setWorkingBlocks(_cloneBlocks(preset.blocks));
      notifyListeners();
      await _savePresets();
      return (true, null);
    } catch (e) {
      return (false, 'JSON 파싱 실패: $e');
    }
  }

  (PromptPreset?, String?) _parseImportedPreset(
    dynamic decoded,
    String? overrideName,
  ) {
    if (decoded is List) {
      final blocks = _parseBlocksFromDynamic(decoded);
      if (blocks.isEmpty) {
        return (null, '프롬프트 블록이 비어있습니다.');
      }
      return (
        PromptPreset(
          name: overrideName?.trim().isNotEmpty == true
              ? overrideName!.trim()
              : 'Imported Preset',
          blocks: _normalizeBlocks(blocks),
        ),
        null,
      );
    }

    if (decoded is Map) {
      final map = Map<String, dynamic>.from(decoded);
      final name = map['name']?.toString() ?? overrideName ?? 'Imported Preset';
      final blocksRaw = map['blocks'];
      if (blocksRaw is! List) {
        return (null, 'blocks 필드가 없습니다.');
      }
      final blocks = _parseBlocksFromDynamic(blocksRaw);
      if (blocks.isEmpty) {
        return (null, '프롬프트 블록이 비어있습니다.');
      }
      return (
        PromptPreset(
          name: name.trim().isEmpty ? 'Imported Preset' : name.trim(),
          blocks: _normalizeBlocks(blocks),
        ),
        null,
      );
    }

    return (null, '지원하지 않는 JSON 형식입니다.');
  }

  List<PromptBlock> _parseBlocksFromDynamic(List<dynamic> rawBlocks) {
    final blocks = <PromptBlock>[];
    for (final raw in rawBlocks) {
      if (raw is! Map) continue;
      final map = Map<String, dynamic>.from(raw);
      final type = _normalizeImportedType(map['type']);
      if (!PromptBlock.isRecognizedType(type)) {
        continue;
      }
      final title =
          map['title']?.toString() ?? map['name']?.toString() ?? 'Prompt';
      final isActive = _parseBool(map['isActive'], defaultValue: true);
      if (type == PromptBlock.typePastMemory) {
        blocks.add(
          PromptBlock.pastMemory(
            title: title,
            range: _parseRange(map['range'], defaultValue: '1'),
            userHeader: map['userHeader']?.toString() ?? 'user',
            charHeader: map['charHeader']?.toString() ?? 'char',
            isActive: isActive,
          ),
        );
      } else if (type == PromptBlock.typeInput) {
        blocks.add(PromptBlock.input(title: title, isActive: isActive));
      } else {
        blocks.add(
          PromptBlock.prompt(
            title: title,
            content: map['content']?.toString() ?? '',
            isActive: isActive,
          ),
        );
      }
    }
    return blocks;
  }
}

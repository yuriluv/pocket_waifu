import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/agent_prompt_preset.dart';
import '../models/prompt_preset_reference.dart';

class AgentPromptPresetProvider extends ChangeNotifier {
  static const String _presetsKey = 'agent_prompt_presets_v1';

  List<AgentPromptPreset> _presets = const [];
  bool _isLoading = false;
  bool _loaded = false;

  List<AgentPromptPreset> get presets => List.unmodifiable(_presets);
  bool get isLoading => _isLoading;

  List<PromptPresetReference> get references {
    return _presets.map((preset) => preset.toReference()).toList();
  }

  AgentPromptPresetProvider() {
    loadPresets();
  }

  AgentPromptPreset? getById(String? id) {
    if (_presets.isEmpty) return null;
    if (id != null) {
      for (final preset in _presets) {
        if (preset.id == id) return preset;
      }
    }
    return _presets.first;
  }

  Future<void> ensureLoaded() async {
    if (_loaded || _isLoading) return;
    await loadPresets();
  }

  Future<void> loadPresets() async {
    if (_isLoading) return;
    _isLoading = true;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_presetsKey);
      if (raw == null || raw.trim().isEmpty) {
        _presets = _defaultPresets();
        await _savePresets(prefs);
      } else {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          _presets = decoded
              .whereType<Map<String, dynamic>>()
              .map(AgentPromptPreset.fromMap)
              .toList();
        }
        if (_presets.isEmpty) {
          _presets = _defaultPresets();
          await _savePresets(prefs);
        }
      }
    } catch (e) {
      debugPrint('AgentPromptPresetProvider load failed: $e');
      _presets = _defaultPresets();
    }

    _loaded = true;
    _isLoading = false;
    notifyListeners();
  }

  Future<void> _savePresets(SharedPreferences prefs) async {
    await prefs.setString(
      _presetsKey,
      jsonEncode(_presets.map((preset) => preset.toMap()).toList()),
    );
  }

  List<AgentPromptPreset> _defaultPresets() {
    return const [
      AgentPromptPreset(
        id: 'agent_default',
        name: 'Agent Default',
        systemPrompt:
            'You are PocketWaifu Agent Mode. Observe conversation context and decide whether to notify the user. '
            'Use Lua calls only for final actions: notify("text") or end(). '
            'Do not expose chain-of-thought.',
        replyPrompt:
            'Evaluate whether a proactive notification is valuable right now. '
            'If yes, output a single Lua call notify("...") (optional options table allowed). '
            'If no, output end(). '
            'If more observation/reasoning steps are needed, output concise analysis text and no notify/end call.',
        regexRules: [
          AgentPromptRegexRule(
            id: 'strip_agent_block',
            name: 'Extract <agent> block',
            pattern: r'<agent\b[^>]*>([\s\S]*?)<\/agent>',
            replacement: r'$1',
            priority: -100,
            dotAll: true,
            multiLine: true,
          ),
          AgentPromptRegexRule(
            id: 'strip_think_block',
            name: 'Remove <think> blocks',
            pattern: r'<think\b[^>]*>[\s\S]*?<\/think>',
            replacement: '',
            priority: -90,
            dotAll: true,
            multiLine: true,
          ),
        ],
        luaScript:
            '-- Agent Lua template\n'
            '-- You can use notify("text", { emotion = "happy", title = "Name" })\n'
            '-- or end() to terminate without notification.\n'
            '-- {{response}} placeholder is replaced with model output before parsing.\n'
            '{{response}}\n',
      ),
    ];
  }
}

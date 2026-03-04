// ============================================================================
// ============================================================================
// ============================================================================

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/api_config.dart';
import '../models/character.dart';
import '../models/settings.dart';
import '../features/image_overlay/data/services/image_overlay_character_sync_service.dart';

class SettingsProvider extends ChangeNotifier {
  static const String _settingsKey = 'app_settings';
  static const String _characterKey = 'character';
  static const String _apiConfigsKey = 'api_configs';
  static const String _activeApiConfigKey = 'active_api_config_id';

  AppSettings _settings = AppSettings();
  Character _character = Character.defaultCharacter();
  bool _isLoading = false;
  String _userName = 'User';

  List<ApiConfig> _apiConfigs = [];
  String? _activeApiConfigId;

  AppSettings get settings => _settings;
  Character get character => _character;
  bool get isLoading => _isLoading;
  String get userName => _userName;

  List<ApiConfig> get apiConfigs => List.unmodifiable(_apiConfigs);
  String? get activeApiConfigId => _activeApiConfigId;

  ApiConfig? get activeApiConfig {
    if (_activeApiConfigId == null || _apiConfigs.isEmpty) return null;
    try {
      return _apiConfigs.firstWhere((c) => c.id == _activeApiConfigId);
    } catch (_) {
      return _apiConfigs.isNotEmpty ? _apiConfigs.first : null;
    }
  }

  SettingsProvider() {
    loadSettings();
  }

  Future<void> loadSettings() async {
    _isLoading = true;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();

      final String? settingsJson = prefs.getString(_settingsKey);
      if (settingsJson != null) {
        final Map<String, dynamic> settingsMap = jsonDecode(settingsJson);
        _settings = AppSettings.fromMap(settingsMap);
      }

      final String? characterJson = prefs.getString(_characterKey);
      if (characterJson != null) {
        final Map<String, dynamic> characterMap = jsonDecode(characterJson);
        _character = Character.fromMap(characterMap);
      }

      _userName = prefs.getString('user_name') ?? 'User';

      final String? apiConfigsJson = prefs.getString(_apiConfigsKey);
      if (apiConfigsJson != null) {
        final List<dynamic> configsList = jsonDecode(apiConfigsJson);
        _apiConfigs = configsList
            .map((json) => ApiConfig.fromMap(json as Map<String, dynamic>))
            .toList();
      }

      _activeApiConfigId = prefs.getString(_activeApiConfigKey);

      if (_apiConfigs.isEmpty) {
        _migrateOldApiSettings();
      }

      if (_activeApiConfigId == null ||
          !_apiConfigs.any((c) => c.id == _activeApiConfigId)) {
        if (_apiConfigs.isNotEmpty) {
          _activeApiConfigId = _apiConfigs.first.id;
        }
      }
    } catch (e) {
      debugPrint('설정 불러오기 실패: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  void _migrateOldApiSettings() {
    if (_settings.openaiApiKey.isNotEmpty) {
      final openaiPreset = ApiConfig.openaiDefault().copyWith(
        apiKey: _settings.openaiApiKey,
        modelName: _settings.openaiModel,
      );
      _apiConfigs.add(openaiPreset);
    }

    if (_settings.anthropicApiKey.isNotEmpty) {
      final anthropicPreset = ApiConfig.anthropicDefault().copyWith(
        apiKey: _settings.anthropicApiKey,
        modelName: _settings.anthropicModel,
      );
      _apiConfigs.add(anthropicPreset);
    }

    if (_settings.copilotApiKey.isNotEmpty) {
      final copilotPreset = ApiConfig.copilotDefault().copyWith(
        apiKey: _settings.copilotApiKey,
        modelName: _settings.copilotModel,
      );
      _apiConfigs.add(copilotPreset);
    }

    if (_apiConfigs.isNotEmpty) {
      _activeApiConfigId = _apiConfigs.first.id;
      debugPrint('기존 API 설정 마이그레이션 완료: ${_apiConfigs.length}개 프리셋');
      saveSettings();
    }
  }

  Future<void> saveSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final String settingsJson = jsonEncode(_settings.toMap());
      await prefs.setString(_settingsKey, settingsJson);

      final String characterJson = jsonEncode(_character.toMap());
      await prefs.setString(_characterKey, characterJson);

      await prefs.setString('user_name', _userName);

      final List<Map<String, dynamic>> configsMaps = _apiConfigs
          .map((c) => c.toMap())
          .toList();
      await prefs.setString(_apiConfigsKey, jsonEncode(configsMaps));

      if (_activeApiConfigId != null) {
        await prefs.setString(_activeApiConfigKey, _activeApiConfigId!);
      }
    } catch (e) {
      debugPrint('설정 저장 실패: $e');
    }
  }

  // ============================================================================
  // ============================================================================

  void addApiConfig(ApiConfig config) {
    _apiConfigs.add(config);
    if (_apiConfigs.length == 1) {
      _activeApiConfigId = config.id;
    }
    notifyListeners();
    saveSettings();
  }

  void updateApiConfig(ApiConfig config) {
    final index = _apiConfigs.indexWhere((c) => c.id == config.id);
    if (index != -1) {
      _apiConfigs[index] = config;
      notifyListeners();
      saveSettings();
    }
  }

  void removeApiConfig(String id) {
    _apiConfigs.removeWhere((c) => c.id == id);
    if (_activeApiConfigId == id) {
      _activeApiConfigId = _apiConfigs.isNotEmpty ? _apiConfigs.first.id : null;
    }
    notifyListeners();
    saveSettings();
  }

  void setActiveApiConfig(String id) {
    if (_apiConfigs.any((c) => c.id == id)) {
      _activeApiConfigId = id;
      notifyListeners();
      saveSettings();
    }
  }

  // ============================================================================
  // ============================================================================

  void updateSettings(AppSettings newSettings) {
    _settings = newSettings;
    notifyListeners();
    saveSettings();
  }

  void updateCharacter(Character newCharacter) {
    _character = newCharacter;
    notifyListeners();
    saveSettings();
  }

  void updateUserName(String name) {
    _userName = name;
    notifyListeners();
    saveSettings();
  }

  void setApiProvider(ApiProvider provider) {
    updateSettings(_settings.copyWith(apiProvider: provider));
  }

  void setOpenAIApiKey(String key) {
    updateSettings(_settings.copyWith(openaiApiKey: key));
  }

  void setAnthropicApiKey(String key) {
    updateSettings(_settings.copyWith(anthropicApiKey: key));
  }

  void setOpenAIModel(String model) {
    updateSettings(_settings.copyWith(openaiModel: model));
  }

  void setAnthropicModel(String model) {
    updateSettings(_settings.copyWith(anthropicModel: model));
  }

  void setTemperature(double value) {
    updateSettings(_settings.copyWith(temperature: value));
  }

  void setTopP(double value) {
    updateSettings(_settings.copyWith(topP: value));
  }

  void setMaxTokens(int value) {
    updateSettings(_settings.copyWith(maxTokens: value));
  }

  void setFrequencyPenalty(double value) {
    updateSettings(_settings.copyWith(frequencyPenalty: value));
  }

  void setPresencePenalty(double value) {
    updateSettings(_settings.copyWith(presencePenalty: value));
  }

  void setSystemPrompt(String prompt) {
    updateSettings(_settings.copyWith(systemPrompt: prompt));
  }

  void setLive2DDirectiveParsingEnabled(bool enabled) {
    updateSettings(_settings.copyWith(live2dDirectiveParsingEnabled: enabled));
  }

  void setLive2DPromptInjectionEnabled(bool enabled) {
    updateSettings(_settings.copyWith(live2dPromptInjectionEnabled: enabled));
  }

  void setLive2DLlmIntegrationEnabled(bool enabled) {
    updateSettings(_settings.copyWith(live2dLlmIntegrationEnabled: enabled));
  }

  void setLive2DLuaExecutionEnabled(bool enabled) {
    updateSettings(_settings.copyWith(live2dLuaExecutionEnabled: enabled));
  }

  void setLive2DShowRawDirectivesInChat(bool enabled) {
    updateSettings(_settings.copyWith(live2dShowRawDirectivesInChat: enabled));
  }

  void setRunRegexBeforeLua(bool enabled) {
    updateSettings(_settings.copyWith(runRegexBeforeLua: enabled));
  }

  void setLive2DSystemPromptTemplate(String template) {
    updateSettings(_settings.copyWith(live2dSystemPromptTemplate: template));
  }

  void setImageOverlaySystemPromptTemplate(String template) {
    updateSettings(
      _settings.copyWith(imageOverlaySystemPromptTemplate: template),
    );
  }

  void setLive2DSystemPromptTokenBudget(int budget) {
    updateSettings(
      _settings.copyWith(
        live2dSystemPromptTokenBudget: budget.clamp(100, 2000).toInt(),
      ),
    );
  }

  void setLlmDirectiveTarget(LlmDirectiveTarget target) {
    updateSettings(_settings.copyWith(llmDirectiveTarget: target));
  }

  void setCharacterName(String name) {
    updateCharacter(_character.copyWith(name: name));
    ImageOverlayCharacterSyncService.instance.syncFromSessionCharacterName(name);
  }

  void setCharacterDescription(String description) {
    updateCharacter(_character.copyWith(description: description));
  }

  void setCharacterPersonality(String personality) {
    updateCharacter(_character.copyWith(personality: personality));
  }

  void setCharacterScenario(String scenario) {
    updateCharacter(_character.copyWith(scenario: scenario));
  }

  void setCharacterFirstMessage(String firstMessage) {
    updateCharacter(_character.copyWith(firstMessage: firstMessage));
  }

  void setCharacterExampleDialogue(String exampleDialogue) {
    updateCharacter(_character.copyWith(exampleDialogue: exampleDialogue));
  }

  void resetCharacter() {
    updateCharacter(Character.defaultCharacter());
  }
}

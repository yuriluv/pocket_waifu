import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/notification_settings.dart';
import '../models/proactive_response_settings.dart';
import '../models/agent_mode_settings.dart';
import '../models/prompt_preset_reference.dart';
import '../models/api_config.dart';
import '../services/proactive_config_parser.dart';

class NotificationSettingsProvider extends ChangeNotifier {
  static const String _notificationKey = 'notification_settings';
  static const String _proactiveKey = 'proactive_settings';
  static const String _agentModeEnabledKey = 'agent_mode_enabled';
  static const String _agentPromptPresetIdKey = 'agent_prompt_preset_id';
  static const String _agentApiPresetIdKey = 'agent_api_preset_id';
  static const String _agentTriggerIntervalMinutesKey =
      'agent_trigger_interval_minutes';
  static const String _agentMaxIterationsKey = 'agent_max_iterations';
  static const String _agentLoopTimeoutSecondsKey =
      'agent_loop_timeout_seconds';

  NotificationSettings _notificationSettings = const NotificationSettings();
  ProactiveResponseSettings _proactiveSettings =
      const ProactiveResponseSettings();
  AgentModeSettings _agentModeSettings = const AgentModeSettings();

  bool _isLoading = false;

  NotificationSettings get notificationSettings => _notificationSettings;
  ProactiveResponseSettings get proactiveSettings => _proactiveSettings;
  AgentModeSettings get agentModeSettings => _agentModeSettings;
  bool get isLoading => _isLoading;

  NotificationSettingsProvider() {
    _load();
  }

  Future<void> _load() async {
    _isLoading = true;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      final notificationJson = prefs.getString(_notificationKey);
      if (notificationJson != null) {
        _notificationSettings = NotificationSettings.fromMap(
          jsonDecode(notificationJson),
        );
      }
      final proactiveJson = prefs.getString(_proactiveKey);
      if (proactiveJson != null) {
        _proactiveSettings = ProactiveResponseSettings.fromMap(
          jsonDecode(proactiveJson),
        );
      }

      _agentModeSettings = AgentModeSettings(
        enabled: prefs.getBool(_agentModeEnabledKey) ?? false,
        promptPresetId: prefs.getString(_agentPromptPresetIdKey),
        apiPresetId: prefs.getString(_agentApiPresetIdKey),
        triggerIntervalMinutes:
            (prefs.getInt(_agentTriggerIntervalMinutesKey) ?? 15)
                .clamp(1, 1440)
                .toInt(),
        maxIterations:
            (prefs.getInt(_agentMaxIterationsKey) ?? 5).clamp(1, 30).toInt(),
        loopTimeoutSeconds:
            (prefs.getInt(_agentLoopTimeoutSecondsKey) ?? 120)
                .clamp(10, 900)
                .toInt(),
      );
    } catch (e) {
      debugPrint('NotificationSettingsProvider load failed: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _notificationKey,
        jsonEncode(_notificationSettings.toMap()),
      );
      await prefs.setString(
        _proactiveKey,
        jsonEncode(_proactiveSettings.toMap()),
      );

      await prefs.setBool(_agentModeEnabledKey, _agentModeSettings.enabled);

      if (_agentModeSettings.promptPresetId != null) {
        await prefs.setString(
          _agentPromptPresetIdKey,
          _agentModeSettings.promptPresetId!,
        );
      } else {
        await prefs.remove(_agentPromptPresetIdKey);
      }

      if (_agentModeSettings.apiPresetId != null) {
        await prefs.setString(
          _agentApiPresetIdKey,
          _agentModeSettings.apiPresetId!,
        );
      } else {
        await prefs.remove(_agentApiPresetIdKey);
      }

      await prefs.setInt(
        _agentTriggerIntervalMinutesKey,
        _agentModeSettings.triggerIntervalMinutes,
      );
      await prefs.setInt(_agentMaxIterationsKey, _agentModeSettings.maxIterations);
      await prefs.setInt(
        _agentLoopTimeoutSecondsKey,
        _agentModeSettings.loopTimeoutSeconds,
      );
    } catch (e) {
      debugPrint('NotificationSettingsProvider save failed: $e');
    }
  }

  Future<void> _notifyAndSaveAsync() async {
    notifyListeners();
    await _save();
  }

  void _notifyAndSave() {
    notifyListeners();
    _save();
  }

  void _updateNotificationSettings(
    NotificationSettings Function(NotificationSettings current) updater,
  ) {
    _notificationSettings = updater(_notificationSettings);
    _notifyAndSave();
  }

  void _updateProactiveSettings(
    ProactiveResponseSettings Function(ProactiveResponseSettings current) updater,
  ) {
    _proactiveSettings = updater(_proactiveSettings);
    _notifyAndSave();
  }

  void _updateAgentModeSettings(
    AgentModeSettings Function(AgentModeSettings current) updater,
  ) {
    _agentModeSettings = updater(_agentModeSettings);
    _notifyAndSave();
  }

  Future<bool> ensureNotificationPermission() async {
    final status = await Permission.notification.status;
    if (status.isGranted) return true;
    final result = await Permission.notification.request();
    return result.isGranted;
  }

  Future<bool> setNotificationsEnabled(bool enabled) async {
    if (enabled) {
      final granted = await ensureNotificationPermission();
      if (!granted) {
        _notificationSettings = _notificationSettings.copyWith(
          notificationsEnabled: false,
        );
        await _notifyAndSaveAsync();
        return false;
      }
    }
    _notificationSettings = _notificationSettings.copyWith(
      notificationsEnabled: enabled,
    );
    await _notifyAndSaveAsync();
    return true;
  }

  void setOutputAsNewNotification(bool enabled) {
    _updateNotificationSettings(
      (current) => current.copyWith(outputAsNewNotification: enabled),
    );
  }

  void setNotificationPromptPreset(String? id) {
    _updateNotificationSettings((current) => current.copyWith(promptPresetId: id));
  }

  void setNotificationApiPreset(String? id) {
    _updateNotificationSettings((current) => current.copyWith(apiPresetId: id));
  }

  void setProactiveEnabled(bool enabled) {
    _updateProactiveSettings((current) => current.copyWith(enabled: enabled));
  }

  void setProactivePromptPreset(String? id) {
    _updateProactiveSettings((current) => current.copyWith(promptPresetId: id));
  }

  void setProactiveApiPreset(String? id) {
    _updateProactiveSettings((current) => current.copyWith(apiPresetId: id));
  }

  void setAgentModeEnabled(bool enabled) {
    _updateAgentModeSettings((current) => current.copyWith(enabled: enabled));
  }

  void setAgentPromptPreset(String? id) {
    _updateAgentModeSettings((current) => current.copyWith(promptPresetId: id));
  }

  void setAgentApiPreset(String? id) {
    _updateAgentModeSettings((current) => current.copyWith(apiPresetId: id));
  }

  void setAgentTriggerIntervalMinutes(int minutes) {
    _updateAgentModeSettings(
      (current) => current.copyWith(
        triggerIntervalMinutes: minutes.clamp(1, 1440).toInt(),
      ),
    );
  }

  void setAgentMaxIterations(int count) {
    _updateAgentModeSettings(
      (current) => current.copyWith(maxIterations: count.clamp(1, 30).toInt()),
    );
  }

  void setAgentLoopTimeoutSeconds(int seconds) {
    _updateAgentModeSettings(
      (current) => current.copyWith(
        loopTimeoutSeconds: seconds.clamp(10, 900).toInt(),
      ),
    );
  }

  void updateProactiveSchedule(String scheduleText) {
    _updateProactiveSettings(
      (current) => current.copyWith(scheduleText: scheduleText),
    );
  }

  void validateProactiveSchedule(String scheduleText) {
    ProactiveConfigParser.parse(scheduleText);
  }

  void rebindPromptPresets(List<PromptPresetReference> presets) {
    if (presets.isEmpty) return;
    final presetIds = presets.map((p) => p.id).toSet();
    bool changed = false;
    if (_notificationSettings.promptPresetId != null &&
        !presetIds.contains(_notificationSettings.promptPresetId)) {
      _notificationSettings = _notificationSettings.copyWith(
        promptPresetId: presets.first.id,
      );
      changed = true;
    }
    if (_proactiveSettings.promptPresetId != null &&
        !presetIds.contains(_proactiveSettings.promptPresetId)) {
      _proactiveSettings = _proactiveSettings.copyWith(
        promptPresetId: presets.first.id,
      );
      changed = true;
    }
    if (changed) {
      _notifyAndSave();
    }
  }

  void rebindAgentPromptPresets(List<PromptPresetReference> presets) {
    if (presets.isEmpty) return;
    final presetIds = presets.map((p) => p.id).toSet();
    if (_agentModeSettings.promptPresetId != null &&
        !presetIds.contains(_agentModeSettings.promptPresetId)) {
      _agentModeSettings = _agentModeSettings.copyWith(
        promptPresetId: presets.first.id,
      );
      _notifyAndSave();
    }
  }

  void rebindApiPresets(List<ApiConfig> configs) {
    if (configs.isEmpty) return;
    final ids = configs.map((c) => c.id).toSet();
    bool changed = false;
    if (_notificationSettings.apiPresetId != null &&
        !ids.contains(_notificationSettings.apiPresetId)) {
      _notificationSettings = _notificationSettings.copyWith(
        apiPresetId: configs.first.id,
      );
      changed = true;
    }
    if (_proactiveSettings.apiPresetId != null &&
        !ids.contains(_proactiveSettings.apiPresetId)) {
      _proactiveSettings = _proactiveSettings.copyWith(
        apiPresetId: configs.first.id,
      );
      changed = true;
    }
    if (_agentModeSettings.apiPresetId != null &&
        !ids.contains(_agentModeSettings.apiPresetId)) {
      _agentModeSettings = _agentModeSettings.copyWith(
        apiPresetId: configs.first.id,
      );
      changed = true;
    }
    if (changed) {
      _notifyAndSave();
    }
  }
}

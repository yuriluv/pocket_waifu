import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/notification_settings.dart';
import '../models/proactive_response_settings.dart';
import '../models/prompt_preset_reference.dart';
import '../models/api_config.dart';
import '../services/proactive_config_parser.dart';

class NotificationSettingsProvider extends ChangeNotifier {
  static const String _notificationKey = 'notification_settings';
  static const String _proactiveKey = 'proactive_settings';

  NotificationSettings _notificationSettings = const NotificationSettings();
  ProactiveResponseSettings _proactiveSettings =
      const ProactiveResponseSettings();

  bool _isLoading = false;

  NotificationSettings get notificationSettings => _notificationSettings;
  ProactiveResponseSettings get proactiveSettings => _proactiveSettings;
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
    } catch (e) {
      debugPrint('NotificationSettingsProvider save failed: $e');
    }
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
        notifyListeners();
        await _save();
        return false;
      }
    }
    _notificationSettings = _notificationSettings.copyWith(
      notificationsEnabled: enabled,
    );
    notifyListeners();
    await _save();
    return true;
  }

  void setOutputAsNewNotification(bool enabled) {
    _notificationSettings = _notificationSettings.copyWith(
      outputAsNewNotification: enabled,
    );
    notifyListeners();
    _save();
  }

  void setNotificationPromptPreset(String? id) {
    _notificationSettings = _notificationSettings.copyWith(promptPresetId: id);
    notifyListeners();
    _save();
  }

  void setNotificationApiPreset(String? id) {
    _notificationSettings = _notificationSettings.copyWith(apiPresetId: id);
    notifyListeners();
    _save();
  }

  void setProactiveEnabled(bool enabled) {
    _proactiveSettings = _proactiveSettings.copyWith(enabled: enabled);
    notifyListeners();
    _save();
  }

  void setProactivePromptPreset(String? id) {
    _proactiveSettings = _proactiveSettings.copyWith(promptPresetId: id);
    notifyListeners();
    _save();
  }

  void setProactiveApiPreset(String? id) {
    _proactiveSettings = _proactiveSettings.copyWith(apiPresetId: id);
    notifyListeners();
    _save();
  }

  void updateProactiveSchedule(String scheduleText) {
    _proactiveSettings = _proactiveSettings.copyWith(
      scheduleText: scheduleText,
    );
    notifyListeners();
    _save();
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
      notifyListeners();
      _save();
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
    if (changed) {
      notifyListeners();
      _save();
    }
  }
}

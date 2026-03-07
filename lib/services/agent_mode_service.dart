import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/agent_prompt_preset.dart';
import '../models/api_config.dart';
import '../models/message.dart';
import '../providers/agent_prompt_preset_provider.dart';
import '../providers/chat_session_provider.dart';
import '../providers/global_runtime_provider.dart';
import '../providers/notification_settings_provider.dart';
import '../providers/settings_provider.dart';
import '../services/global_runtime_registry.dart';
import '../services/notification_coordinator.dart';

class AgentModeService implements GlobalRuntimeListener {
  AgentModeService(this._notificationCoordinator);

  final NotificationCoordinator _notificationCoordinator;

  Timer? _timer;
  bool _inFlight = false;
  bool _registered = false;
  int? _activeIntervalMinutes;

  NotificationSettingsProvider? _notificationSettingsProvider;
  SettingsProvider? _settingsProvider;
  GlobalRuntimeProvider? _globalRuntimeProvider;
  AgentPromptPresetProvider? _agentPromptPresetProvider;
  ChatSessionProvider? _chatSessionProvider;

  VoidCallback? _settingsListener;
  VoidCallback? _agentPresetListener;
  VoidCallback? _chatSessionListener;
  VoidCallback? _userReplyListener;
  String? _lastUserMessageSignature;

  void attach({
    required NotificationSettingsProvider notificationSettingsProvider,
    required SettingsProvider settingsProvider,
    required GlobalRuntimeProvider globalRuntimeProvider,
    required AgentPromptPresetProvider agentPromptPresetProvider,
    required ChatSessionProvider chatSessionProvider,
  }) {
    if (!identical(_notificationSettingsProvider, notificationSettingsProvider)) {
      if (_settingsListener != null) {
        _notificationSettingsProvider?.removeListener(_settingsListener!);
      }
      _settingsListener = _handleSettingsChanged;
      notificationSettingsProvider.addListener(_settingsListener!);
    }

    if (!identical(_agentPromptPresetProvider, agentPromptPresetProvider)) {
      if (_agentPresetListener != null) {
        _agentPromptPresetProvider?.removeListener(_agentPresetListener!);
      }
      _agentPresetListener = _handleSettingsChanged;
      agentPromptPresetProvider.addListener(_agentPresetListener!);
    }

    if (!identical(_chatSessionProvider, chatSessionProvider)) {
      if (_chatSessionListener != null) {
        _chatSessionProvider?.removeListener(_chatSessionListener!);
      }
      _chatSessionListener = _handleChatSessionChanged;
      chatSessionProvider.addListener(_chatSessionListener!);
    }

    _notificationSettingsProvider = notificationSettingsProvider;
    _settingsProvider = settingsProvider;
    _globalRuntimeProvider = globalRuntimeProvider;
    _agentPromptPresetProvider = agentPromptPresetProvider;
    _chatSessionProvider = chatSessionProvider;
    _lastUserMessageSignature = _latestUserMessageSignature(chatSessionProvider);

    if (!_registered) {
      GlobalRuntimeRegistry.instance.register(this);
      _registered = true;
    }

    _userReplyListener ??= cancelInFlightDueToUserReply;
    _notificationCoordinator.addOnUserReplyListener(_userReplyListener!);
    _maybeStart();
  }

  void _handleChatSessionChanged() {
    final sessionProvider = _chatSessionProvider;
    if (sessionProvider == null) return;
    final latestSignature = _latestUserMessageSignature(sessionProvider);
    if (latestSignature == _lastUserMessageSignature) {
      return;
    }

    _lastUserMessageSignature = latestSignature;
    if (_inFlight) {
      _notificationCoordinator.cancelAgentInFlight();
      _inFlight = false;
      _maybeStart();
    }
  }

  String? _latestUserMessageSignature(ChatSessionProvider provider) {
    final sessionId = provider.activeSessionId;
    if (sessionId == null) return null;
    final messages = provider.getMessagesForSession(sessionId);
    for (var i = messages.length - 1; i >= 0; i--) {
      if (messages[i].role == MessageRole.user) {
        return '$sessionId:${messages[i].id}';
      }
    }
    return null;
  }

  void _handleSettingsChanged() {
    _maybeStart();
  }

  void cancelInFlightDueToUserReply() {
    if (_inFlight) {
      _notificationCoordinator.cancelAgentInFlight();
      _inFlight = false;
      _maybeStart();
    }
  }

  void _maybeStart() {
    final modeSettings = _notificationSettingsProvider?.agentModeSettings;
    final notificationSettings = _notificationSettingsProvider?.notificationSettings;
    if (modeSettings == null || notificationSettings == null) return;

    if (!notificationSettings.notificationsEnabled || !modeSettings.enabled) {
      stop();
      return;
    }

    if (!(_globalRuntimeProvider?.isEnabled ?? true)) {
      stop();
      return;
    }

    final minutes = modeSettings.triggerIntervalMinutes.clamp(1, 1440).toInt();
    if (_timer != null && _activeIntervalMinutes == minutes) {
      return;
    }

    stop();
    _activeIntervalMinutes = minutes;
    _timer = Timer.periodic(Duration(minutes: minutes), (_) {
      _trigger();
    });
  }

  Future<void> _trigger() async {
    if (_inFlight) return;

    final modeSettings = _notificationSettingsProvider?.agentModeSettings;
    final notificationSettings = _notificationSettingsProvider?.notificationSettings;
    final presetProvider = _agentPromptPresetProvider;
    if (modeSettings == null ||
        notificationSettings == null ||
        presetProvider == null ||
        !notificationSettings.notificationsEnabled ||
        !modeSettings.enabled) {
      stop();
      return;
    }

    if (!(_globalRuntimeProvider?.isEnabled ?? true)) {
      stop();
      return;
    }

    final resolvedSessionId = _notificationCoordinator.activeSessionId;
    if (resolvedSessionId == null) return;

    await presetProvider.ensureLoaded();
    final AgentPromptPreset? preset =
        presetProvider.getById(modeSettings.promptPresetId);
    if (preset == null) return;

    _inFlight = true;
    try {
      final apiConfig = _resolveApiConfig(modeSettings.apiPresetId);
      await _notificationCoordinator.triggerAgentModeLoop(
        sessionId: resolvedSessionId,
        apiConfig: apiConfig,
        promptPreset: preset,
        maxIterations: modeSettings.maxIterations,
        timeout: Duration(seconds: modeSettings.loopTimeoutSeconds),
      );
    } finally {
      _inFlight = false;
    }
  }

  ApiConfig? _resolveApiConfig(String? presetId) {
    final settingsProvider = _settingsProvider;
    if (settingsProvider == null) return null;
    if (presetId != null) {
      final match = settingsProvider.apiConfigs
          .where((config) => config.id == presetId)
          .toList();
      if (match.isNotEmpty) return match.first;
    }
    return settingsProvider.activeApiConfig;
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    _activeIntervalMinutes = null;
  }

  @override
  void onGlobalDisabled() {
    stop();
    _notificationCoordinator.cancelAgentInFlight();
    _inFlight = false;
  }

  @override
  void onGlobalEnabled() {
    _maybeStart();
  }
}

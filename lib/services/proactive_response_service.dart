import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../models/api_config.dart';
import '../providers/global_runtime_provider.dart';
import '../providers/notification_settings_provider.dart';
import '../providers/settings_provider.dart';
import '../services/global_runtime_registry.dart';
import '../services/notification_coordinator.dart';
import '../services/pre_response_timer.dart';
import '../services/proactive_config_parser.dart';

class ProactiveResponseService implements GlobalRuntimeListener {
  ProactiveResponseService(this._notificationCoordinator) {
    _timer = PreResponseTimer(onTimerFired: _trigger);
  }

  final NotificationCoordinator _notificationCoordinator;
  final Random _random = Random();
  late PreResponseTimer _timer;

  bool _inFlight = false;
  bool _registered = false;
  VoidCallback? _notificationSettingsListener;
  VoidCallback? _userReplyListener;

  GlobalRuntimeProvider? _globalRuntimeProvider;
  NotificationSettingsProvider? _notificationSettingsProvider;
  SettingsProvider? _settingsProvider;

  bool _overlayOn = false;
  bool _screenLandscape = false;
  bool _screenOff = false;
  bool _wasScreenOff = false;

  void attach({
    required GlobalRuntimeProvider globalRuntimeProvider,
    required NotificationSettingsProvider notificationSettingsProvider,
    required SettingsProvider settingsProvider,
  }) {
    if (!identical(_notificationSettingsProvider, notificationSettingsProvider)) {
      if (_notificationSettingsListener != null) {
        _notificationSettingsProvider?.removeListener(_notificationSettingsListener!);
      }
      _notificationSettingsListener = _handleNotificationSettingsChanged;
      notificationSettingsProvider.addListener(_notificationSettingsListener!);
    }

    _globalRuntimeProvider = globalRuntimeProvider;
    _notificationSettingsProvider = notificationSettingsProvider;
    _settingsProvider = settingsProvider;

    if (!_registered) {
      GlobalRuntimeRegistry.instance.register(this);
      _registered = true;
    }

    _userReplyListener ??= cancelInFlightDueToUserReply;
    _notificationCoordinator.addOnUserReplyListener(_userReplyListener!);
    _maybeStart();
  }

  void _handleNotificationSettingsChanged() {
    _maybeStart();
  }

  void updateEnvironment({
    bool? overlayOn,
    bool? screenLandscape,
    bool? screenOff,
  }) {
    if (overlayOn != null) _overlayOn = overlayOn;
    if (screenLandscape != null) _screenLandscape = screenLandscape;
    if (screenOff != null) _screenOff = screenOff;

    if (_screenOff != _wasScreenOff) {
      if (_screenOff) {
        _timer.pause();
      } else {
        _timer.resume();
      }
      _wasScreenOff = _screenOff;
    }

    _timer.recalculate(_currentEnvironmentState());
  }

  void cancelInFlightDueToUserReply() {
    if (_inFlight) {
      _notificationCoordinator.cancelProactiveInFlight();
      _inFlight = false;
      _maybeStart();
    }
  }

  void _maybeStart() {
    final notificationSettings = _notificationSettingsProvider?.notificationSettings;
    final settings = _notificationSettingsProvider?.proactiveSettings;
    if (settings == null || notificationSettings == null) return;
    if (!notificationSettings.notificationsEnabled) {
      _notificationCoordinator.cancelProactiveInFlight();
      _inFlight = false;
      stop();
      return;
    }
    if (!settings.enabled) {
      stop();
      return;
    }
    if (!(_globalRuntimeProvider?.isEnabled ?? true)) {
      stop();
      return;
    }

    final parsed = _parseConfig(settings.scheduleText);
    if (parsed == null) {
      stop();
      return;
    }

    final timerConfig = _toTimerConfig(parsed);
    if (timerConfig != null) {
      _timer.start(
        config: timerConfig,
        environment: _currentEnvironmentState(),
      );
      if (_screenOff) {
        _timer.pause();
      }
      return;
    }

    final fallbackInterval = _pickInterval(parsed);
    if (fallbackInterval == null) {
      stop();
      return;
    }

    _timer.start(
      config: PreResponseTimerConfig(
        baseInterval: fallbackInterval,
        deviationPercent: 0,
        overlayBonus: Duration.zero,
        overlayOffBonus: Duration.zero,
        landscapeBonus: Duration.zero,
      ),
      environment: _currentEnvironmentState(),
    );
    if (_screenOff) {
      _timer.pause();
    }
  }

  ProactiveConfig? _parseConfig(String scheduleText) {
    try {
      return ProactiveConfigParser.parse(scheduleText);
    } catch (e) {
      debugPrint('Proactive schedule parse error: $e');
      return null;
    }
  }

  PreResponseTimerConfig? _toTimerConfig(ProactiveConfig config) {
    final base = config.baseInterval;
    if (base == null || base <= Duration.zero) {
      return null;
    }

    final adjustments = config.additiveAdjustments;
    final overlayBonus = adjustments['overlayon'] ?? Duration.zero;
    final overlayOffBonus = adjustments['overlayoff'] ?? Duration.zero;
    final landscapeBonus = adjustments['screenlandscape'] ?? Duration.zero;

    return PreResponseTimerConfig(
      baseInterval: base,
      deviationPercent: config.deviationPercent,
      overlayBonus: overlayBonus,
      overlayOffBonus: overlayOffBonus,
      landscapeBonus: landscapeBonus,
    );
  }

  TimerEnvironmentState _currentEnvironmentState() {
    return TimerEnvironmentState(
      overlayVisible: _overlayOn,
      isLandscape: _screenLandscape,
      screenOn: !_screenOff,
    );
  }

  Duration? _pickInterval(ProactiveConfig config) {
    if (config.isAdditive) {
      final timerConfig = _toTimerConfig(config);
      if (timerConfig == null) return null;
      var totalMs = timerConfig.baseInterval.inMilliseconds;
      totalMs += _overlayOn
          ? timerConfig.overlayBonus.inMilliseconds
          : timerConfig.overlayOffBonus.inMilliseconds;
      if (_screenLandscape) {
        totalMs += timerConfig.landscapeBonus.inMilliseconds;
      }
      if (totalMs <= 0) return null;
      return Duration(milliseconds: totalMs);
    }

    final range = _selectRange(config);
    if (range == null) return null;
    return range.pick(_random);
  }

  ProactiveDurationRange? _selectRange(ProactiveConfig config) {
    if (_screenOff && config.ranges.containsKey('screenoff')) {
      return config.ranges['screenoff'];
    }
    if (_screenLandscape && config.ranges.containsKey('screenlandscape')) {
      return config.ranges['screenlandscape'];
    }
    if (_overlayOn && config.ranges.containsKey('overlayon')) {
      return config.ranges['overlayon'];
    }
    if (!_overlayOn && config.ranges.containsKey('overlayoff')) {
      return config.ranges['overlayoff'];
    }
    return null;
  }

  Future<void> _trigger() async {
    if (_inFlight) return;
    final settings = _notificationSettingsProvider?.proactiveSettings;
    final notificationSettings =
        _notificationSettingsProvider?.notificationSettings;
    if (settings == null ||
        notificationSettings == null ||
        !settings.enabled ||
        !notificationSettings.notificationsEnabled) {
      stop();
      return;
    }
    if (!(_globalRuntimeProvider?.isEnabled ?? true)) {
      stop();
      return;
    }

    final resolvedSessionId = _notificationCoordinator.activeSessionId;
    if (resolvedSessionId == null) return;

    _inFlight = true;
    debugPrint(
      'ProactiveResponseService -> NotificationCoordinator: trigger session=$resolvedSessionId',
    );
    try {
      final apiConfig = _resolveApiConfig(settings.apiPresetId);
      final result = await _notificationCoordinator.triggerProactiveResponse(
        sessionId: resolvedSessionId,
        skipInputBlock: true,
        apiConfig: apiConfig,
      );
      debugPrint(
        'ProactiveResponseService <- NotificationCoordinator: result=$result session=$resolvedSessionId',
      );
      if (result == NotificationRequestResult.cancelled) {
        _maybeStart();
      }
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
    _timer.cancel();
  }

  @override
  void onGlobalDisabled() {
    stop();
    _notificationCoordinator.cancelProactiveInFlight();
    _inFlight = false;
  }

  @override
  void onGlobalEnabled() {
    _maybeStart();
  }
}

import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../models/api_config.dart';
import '../models/proactive_debug_models.dart';
import '../providers/global_runtime_provider.dart';
import '../providers/notification_settings_provider.dart';
import '../providers/settings_provider.dart';
import '../services/global_runtime_registry.dart';
import '../services/notification_coordinator.dart';
import '../services/pre_response_timer.dart';
import '../services/proactive_config_parser.dart';
import '../utils/api_preset_resolver.dart';

class ProactiveResponseService implements GlobalRuntimeListener {
  ProactiveResponseService(this._notificationCoordinator) {
    _timer = PreResponseTimer(onTimerFired: _trigger);
    _logEvent('service_initialized');
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

  static const int _maxDebugLogEntries = 200;
  final ValueNotifier<ProactiveDebugSnapshot> _debugSnapshot =
      ValueNotifier<ProactiveDebugSnapshot>(
        const ProactiveDebugSnapshot.initial(),
      );
  final List<ProactiveDebugLogEntry> _debugLogs = <ProactiveDebugLogEntry>[];

  ValueListenable<ProactiveDebugSnapshot> get debugSnapshot => _debugSnapshot;
  List<ProactiveDebugLogEntry> get debugLogs =>
      List<ProactiveDebugLogEntry>.unmodifiable(_debugLogs);

  void clearDebugLogs() {
    _debugLogs.clear();
    _publishDebugSnapshot(status: 'logs_cleared');
  }

  void _appendDebugLog(String event, {String detail = ''}) {
    _debugLogs.add(
      ProactiveDebugLogEntry(
        timestamp: DateTime.now(),
        event: event,
        detail: detail,
      ),
    );
    if (_debugLogs.length > _maxDebugLogEntries) {
      _debugLogs.removeRange(0, _debugLogs.length - _maxDebugLogEntries);
    }
  }

  void _publishDebugSnapshot({String? status}) {
    final notificationSettings = _notificationSettingsProvider?.notificationSettings;
    final proactiveSettings = _notificationSettingsProvider?.proactiveSettings;
    _debugSnapshot.value = ProactiveDebugSnapshot(
      running: _timer.isRunning,
      paused: _timer.isPaused,
      inFlight: _inFlight,
      notificationsEnabled: notificationSettings?.notificationsEnabled ?? false,
      proactiveEnabled: proactiveSettings?.enabled ?? false,
      globalEnabled: _globalRuntimeProvider?.isEnabled ?? true,
      overlayOn: _overlayOn,
      screenLandscape: _screenLandscape,
      screenOff: _screenOff,
      cycleStartedAt: _timer.cycleStartedAt,
      nextTriggerAt: _timer.nextTriggerAt,
      scheduledDuration: _timer.scheduledDuration,
      remainingDuration: _timer.remainingDuration,
      status: status ?? _debugSnapshot.value.status,
      logCount: _debugLogs.length,
    );
  }

  void _logEvent(String event, {String detail = ''}) {
    _appendDebugLog(event, detail: detail);
    _publishDebugSnapshot(status: event);
  }

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
    _logEvent('attached');
    _maybeStart();
  }

  void _handleNotificationSettingsChanged() {
    _publishDebugSnapshot(status: 'settings_changed');
    _maybeStart();
  }

  void updateEnvironment({
    bool? overlayOn,
    bool? screenLandscape,
    bool? screenOff,
  }) {
    var changed = false;
    if (overlayOn != null && _overlayOn != overlayOn) {
      _overlayOn = overlayOn;
      changed = true;
    }
    if (screenLandscape != null && _screenLandscape != screenLandscape) {
      _screenLandscape = screenLandscape;
      changed = true;
    }
    if (screenOff != null && _screenOff != screenOff) {
      _screenOff = screenOff;
      changed = true;
    }

    if (_screenOff != _wasScreenOff) {
      if (_screenOff) {
        _timer.pause();
        _appendDebugLog('timer_paused', detail: 'screen_off');
      } else {
        _timer.resume();
        _appendDebugLog('timer_resumed', detail: 'screen_on');
      }
      _wasScreenOff = _screenOff;
      changed = true;
    }

    _timer.recalculate(_currentEnvironmentState());
    if (changed) {
      _logEvent(
        'environment_updated',
        detail:
            'overlay=$_overlayOn, landscape=$_screenLandscape, screenOff=$_screenOff',
      );
      return;
    }
    _publishDebugSnapshot(status: 'environment_checked');
  }

  void cancelInFlightDueToUserReply() {
    if (_inFlight) {
      _notificationCoordinator.cancelProactiveInFlight();
      _inFlight = false;
      _logEvent('cancelled_by_user_reply');
      _maybeStart();
      return;
    }
    _publishDebugSnapshot(status: 'user_reply_noop');
  }

  void _maybeStart() {
    final notificationSettings = _notificationSettingsProvider?.notificationSettings;
    final settings = _notificationSettingsProvider?.proactiveSettings;
    if (settings == null || notificationSettings == null) {
      _publishDebugSnapshot(status: 'waiting_for_settings');
      return;
    }
    if (!notificationSettings.notificationsEnabled) {
      _notificationCoordinator.cancelProactiveInFlight();
      _inFlight = false;
      stop(reason: 'notifications_disabled');
      return;
    }
    if (!settings.enabled) {
      stop(reason: 'proactive_disabled');
      return;
    }
    if (!(_globalRuntimeProvider?.isEnabled ?? true)) {
      stop(reason: 'global_disabled');
      return;
    }

    final parsed = _parseConfig(settings.scheduleText);
    if (parsed == null) {
      stop(reason: 'schedule_parse_failed');
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
      _logEvent(
        'timer_started',
        detail:
            'base=${timerConfig.baseInterval.inSeconds}s, deviation=${timerConfig.deviationPercent}%',
      );
      return;
    }

    final fallbackInterval = _pickInterval(parsed);
    if (fallbackInterval == null) {
      stop(reason: 'fallback_interval_unavailable');
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
    _logEvent(
      'timer_started_fallback',
      detail: 'interval=${fallbackInterval.inSeconds}s',
    );
  }

  ProactiveConfig? _parseConfig(String scheduleText) {
    try {
      return ProactiveConfigParser.parse(scheduleText);
    } catch (e) {
      debugPrint('Proactive schedule parse error: $e');
      _appendDebugLog('schedule_parse_error', detail: e.toString());
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
    if (_inFlight) {
      _publishDebugSnapshot(status: 'trigger_skipped_in_flight');
      return;
    }
    final settings = _notificationSettingsProvider?.proactiveSettings;
    final notificationSettings =
        _notificationSettingsProvider?.notificationSettings;
    if (settings == null ||
        notificationSettings == null ||
        !settings.enabled ||
        !notificationSettings.notificationsEnabled) {
      stop(reason: 'trigger_blocked_by_settings');
      return;
    }
    if (!(_globalRuntimeProvider?.isEnabled ?? true)) {
      stop(reason: 'trigger_blocked_by_global_disabled');
      return;
    }

    final resolvedSessionId = _notificationCoordinator.activeSessionId;
    if (resolvedSessionId == null) {
      _logEvent('trigger_skipped_no_active_session');
      return;
    }

    _inFlight = true;
    _logEvent('trigger_started', detail: 'session=$resolvedSessionId');
    try {
      final apiConfig = _resolveApiConfig(settings.apiPresetId);
      final result = await _notificationCoordinator.triggerProactiveResponse(
        sessionId: resolvedSessionId,
        skipInputBlock: true,
        apiConfig: apiConfig,
      );
      _logEvent(
        'trigger_result',
        detail: 'result=$result session=$resolvedSessionId',
      );
      if (result == NotificationRequestResult.cancelled) {
        _maybeStart();
      }
    } finally {
      _inFlight = false;
      _publishDebugSnapshot(status: 'trigger_idle');
    }
  }

  ApiConfig? _resolveApiConfig(String? presetId) {
    final settingsProvider = _settingsProvider;
    if (settingsProvider == null) return null;
    return resolveApiConfigByPreset(
      apiConfigs: settingsProvider.apiConfigs,
      activeApiConfig: settingsProvider.activeApiConfig,
      presetId: presetId,
    );
  }

  void stop({String reason = 'stopped'}) {
    final wasActive = _timer.isRunning || _timer.isPaused;
    _timer.cancel();
    if (wasActive) {
      _appendDebugLog('timer_stopped', detail: reason);
    }
    _publishDebugSnapshot(status: reason);
  }

  @override
  void onGlobalDisabled() {
    stop(reason: 'global_disabled');
    _notificationCoordinator.cancelProactiveInFlight();
    _inFlight = false;
    _logEvent('global_disabled');
  }

  @override
  void onGlobalEnabled() {
    _logEvent('global_enabled');
    _maybeStart();
  }
}

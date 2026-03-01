import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';

import '../models/api_config.dart';
import '../providers/global_runtime_provider.dart';
import '../providers/notification_settings_provider.dart';
import '../providers/settings_provider.dart';
import '../services/global_runtime_registry.dart';
import '../services/proactive_config_parser.dart';
import '../services/notification_coordinator.dart';

class ProactiveResponseService implements GlobalRuntimeListener {
  ProactiveResponseService(this._notificationCoordinator);

  final NotificationCoordinator _notificationCoordinator;

  final Random _random = Random();
  Timer? _timer;
  Duration? _currentInterval;

  bool _inFlight = false;
  bool _registered = false;

  GlobalRuntimeProvider? _globalRuntimeProvider;
  NotificationSettingsProvider? _notificationSettingsProvider;
  SettingsProvider? _settingsProvider;

  bool _overlayOn = false;
  bool _screenLandscape = false;
  bool _screenOff = false;

  void attach({
    required GlobalRuntimeProvider globalRuntimeProvider,
    required NotificationSettingsProvider notificationSettingsProvider,
    required SettingsProvider settingsProvider,
  }) {
    _globalRuntimeProvider = globalRuntimeProvider;
    _notificationSettingsProvider = notificationSettingsProvider;
    _settingsProvider = settingsProvider;
    if (!_registered) {
      GlobalRuntimeRegistry.instance.register(this);
      _registered = true;
    }
    _notificationCoordinator.setOnUserReplyHandler(
      cancelInFlightDueToUserReply,
    );
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
    _maybeReschedule();
  }

  void cancelInFlightDueToUserReply() {
    if (_inFlight) {
      _notificationCoordinator.cancelProactiveInFlight();
      _inFlight = false;
      _reschedule(useSameInterval: true);
    }
  }

  void _maybeStart() {
    final settings = _notificationSettingsProvider?.proactiveSettings;
    if (settings == null) return;
    if (!settings.enabled) {
      stop();
      return;
    }
    if (!(_globalRuntimeProvider?.isEnabled ?? true)) {
      stop();
      return;
    }
    _reschedule();
  }

  void _maybeReschedule() {
    if (_timer == null) {
      _maybeStart();
      return;
    }
    _reschedule();
  }

  void _reschedule({bool useSameInterval = false}) {
    _timer?.cancel();
    final settings = _notificationSettingsProvider?.proactiveSettings;
    if (settings == null || !settings.enabled) return;

    ProactiveConfig config;
    try {
      config = ProactiveConfigParser.parse(settings.scheduleText);
    } catch (e) {
      debugPrint('Proactive schedule parse error: $e');
      return;
    }

    final nextInterval = useSameInterval && _currentInterval != null
        ? _currentInterval
        : _pickInterval(config);

    _currentInterval = nextInterval;

    if (_currentInterval == null) return;
    _timer = Timer(_currentInterval!, _trigger);
  }

  Duration? _pickInterval(ProactiveConfig config) {
    if (config.isAdditive) {
      return _selectAdditiveInterval(config);
    }

    final range = _selectRange(config);
    if (range == null) return null;
    return range.pick(_random);
  }

  Duration? _selectAdditiveInterval(ProactiveConfig config) {
    final base = config.baseInterval;
    if (base == null) return null;

    var totalMs = base.inMilliseconds;
    final adjustments = config.additiveAdjustments;

    if (_screenOff && adjustments.containsKey('screenoff')) {
      final value = adjustments['screenoff'];
      if (value == null) return null;
      totalMs += value.inMilliseconds;
    }

    if (_screenLandscape && adjustments.containsKey('screenlandscape')) {
      final value = adjustments['screenlandscape'];
      if (value == null) return null;
      totalMs += value.inMilliseconds;
    }

    if (_overlayOn && adjustments.containsKey('overlayon')) {
      final value = adjustments['overlayon'];
      if (value == null) return null;
      totalMs += value.inMilliseconds;
    }

    if (!_overlayOn && adjustments.containsKey('overlayoff')) {
      final value = adjustments['overlayoff'];
      if (value == null) return null;
      totalMs += value.inMilliseconds;
    }

    if (totalMs <= 0) {
      debugPrint('Proactive additive schedule produced non-positive interval');
      return null;
    }

    final deviation = config.deviationPercent.clamp(0, 100);
    if (deviation > 0) {
      final delta = (totalMs * deviation / 100).round();
      if (delta > 0) {
        final offset = _random.nextInt(delta * 2 + 1) - delta;
        totalMs += offset;
      }
    }

    if (totalMs <= 0) {
      debugPrint(
        'Proactive additive schedule variance produced non-positive interval',
      );
      return null;
    }

    return Duration(milliseconds: totalMs);
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
    try {
      final apiConfig = _resolveApiConfig(settings.apiPresetId);
      final result = await _notificationCoordinator.triggerProactiveResponse(
        sessionId: resolvedSessionId,
        skipInputBlock: true,
        apiConfig: apiConfig,
      );
      if (result == NotificationRequestResult.cancelled) {
        _reschedule(useSameInterval: true);
      } else {
        _reschedule();
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
    _timer?.cancel();
    _timer = null;
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

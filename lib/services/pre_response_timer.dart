import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

class TimerEnvironmentState {
  final bool overlayVisible;
  final bool isLandscape;
  final bool screenOn;

  const TimerEnvironmentState({
    required this.overlayVisible,
    required this.isLandscape,
    required this.screenOn,
  });

  static const initial = TimerEnvironmentState(
    overlayVisible: false,
    isLandscape: false,
    screenOn: true,
  );
}

class PreResponseTimerConfig {
  final Duration baseInterval;
  final int deviationPercent;
  final Duration overlayBonus;
  final Duration overlayOffBonus;
  final Duration landscapeBonus;

  const PreResponseTimerConfig({
    required this.baseInterval,
    required this.deviationPercent,
    required this.overlayBonus,
    this.overlayOffBonus = Duration.zero,
    required this.landscapeBonus,
  });
}

class PreResponseTimer {
  PreResponseTimer({required FutureOr<void> Function() onTimerFired})
    : _onTimerFired = onTimerFired;

  final FutureOr<void> Function() _onTimerFired;
  final Random _random = Random();

  Timer? _timer;
  PreResponseTimerConfig? _config;
  TimerEnvironmentState _environment = TimerEnvironmentState.initial;

  DateTime? _cycleStartedAt;
  Duration? _scheduledDuration;
  int? _cycleDeviationMs;

  bool _paused = false;
  DateTime? _pausedAt;
  Duration? _remainingAtPause;
  bool _inCallback = false;

  bool get isRunning => _timer != null;
  bool get isPaused => _paused;

  void start({
    required PreResponseTimerConfig config,
    required TimerEnvironmentState environment,
  }) {
    _config = config;
    _environment = environment;
    _paused = false;
    _pausedAt = null;
    _remainingAtPause = null;
    _startNewCycle();
  }

  void cancel() {
    _timer?.cancel();
    _timer = null;
    _cycleStartedAt = null;
    _scheduledDuration = null;
    _cycleDeviationMs = null;
    _paused = false;
    _pausedAt = null;
    _remainingAtPause = null;
  }

  void pause() {
    if (_paused) return;
    if (_timer == null || _cycleStartedAt == null || _scheduledDuration == null) {
      _paused = true;
      _pausedAt = DateTime.now();
      _remainingAtPause = null;
      return;
    }

    final elapsed = DateTime.now().difference(_cycleStartedAt!);
    final remaining = _scheduledDuration! - elapsed;
    _remainingAtPause = remaining.isNegative ? Duration.zero : remaining;
    _pausedAt = DateTime.now();
    _paused = true;
    _timer?.cancel();
    _timer = null;
    debugPrint('PreResponseTimer paused: ${_remainingAtPause!.inSeconds}s remaining');
  }

  void resume() {
    if (!_paused) return;
    _paused = false;

    final pausedAt = _pausedAt;
    final remainingAtPause = _remainingAtPause;
    _pausedAt = null;
    _remainingAtPause = null;

    if (pausedAt == null || remainingAtPause == null) {
      _startNewCycle();
      return;
    }

    final slept = DateTime.now().difference(pausedAt);
    final remaining = remainingAtPause - slept;
    if (remaining <= Duration.zero) {
      debugPrint('PreResponseTimer resumed: overdue during screen-off, firing now');
      _fireAndStartNextCycle();
      return;
    }

    _schedule(remaining, keepDeviation: true);
    debugPrint('PreResponseTimer resumed: ${remaining.inSeconds}s remaining');
  }

  void recalculate(TimerEnvironmentState environment) {
    _environment = environment;
    if (_paused) return;
    if (_timer == null || _config == null || _cycleStartedAt == null) return;

    final oldRemaining = _remainingFromNow();
    final newTotal = _computeTotalDuration(keepCycleDeviation: true);
    if (newTotal == null) {
      debugPrint('PreResponseTimer recalculation skipped: non-positive interval');
      _scheduleFallbackCycle();
      return;
    }

    final elapsed = DateTime.now().difference(_cycleStartedAt!);
    final newRemaining = newTotal - elapsed;
    if (newRemaining.inSeconds == oldRemaining.inSeconds) {
      return;
    }
    if (newRemaining <= Duration.zero) {
      debugPrint(
        'Timer recalculated: was ${oldRemaining.inMinutes}m remaining, now overdue. Firing now '
        '(overlay: ${environment.overlayVisible}, landscape: ${environment.isLandscape})',
      );
      _fireAndStartNextCycle();
      return;
    }

    _timer?.cancel();
    _schedule(newRemaining, keepDeviation: true);
    debugPrint(
      'Timer recalculated: was ${oldRemaining.inMinutes}m remaining, now ${newRemaining.inMinutes}m '
      '(overlay: ${environment.overlayVisible}, landscape: ${environment.isLandscape})',
    );
  }

  void _startNewCycle() {
    if (_config == null) return;
    _cycleDeviationMs = null;
    final total = _computeTotalDuration(keepCycleDeviation: false);
    if (total == null || total <= Duration.zero) {
      debugPrint('Computed non-positive interval, scheduling fallback cycle');
      _scheduleFallbackCycle();
      return;
    }
    _schedule(total, keepDeviation: true);
  }

  void _scheduleFallbackCycle() {
    final base = _config?.baseInterval ?? const Duration(minutes: 1);
    final fallback = base > Duration.zero ? base : const Duration(minutes: 1);
    _cycleDeviationMs = 0;
    _schedule(fallback, keepDeviation: true);
  }

  Duration _remainingFromNow() {
    if (_cycleStartedAt == null || _scheduledDuration == null) {
      return Duration.zero;
    }
    final elapsed = DateTime.now().difference(_cycleStartedAt!);
    final remaining = _scheduledDuration! - elapsed;
    return remaining.isNegative ? Duration.zero : remaining;
  }

  Duration? _computeTotalDuration({required bool keepCycleDeviation}) {
    final config = _config;
    if (config == null) return null;

    final baseMs = config.baseInterval.inMilliseconds;
    if (baseMs <= 0) return null;

    if (!keepCycleDeviation || _cycleDeviationMs == null) {
      final deviationPercent = config.deviationPercent.clamp(0, 100);
      if (deviationPercent == 0) {
        _cycleDeviationMs = 0;
      } else {
        final delta = (baseMs * deviationPercent / 100).round();
        _cycleDeviationMs = _random.nextInt(delta * 2 + 1) - delta;
      }
    }

    var totalMs = baseMs + (_cycleDeviationMs ?? 0);
    if (_environment.overlayVisible) {
      totalMs += config.overlayBonus.inMilliseconds;
    } else {
      totalMs += config.overlayOffBonus.inMilliseconds;
    }
    if (_environment.isLandscape) {
      totalMs += config.landscapeBonus.inMilliseconds;
    }

    if (totalMs <= 0) {
      return null;
    }
    return Duration(milliseconds: totalMs);
  }

  void _schedule(Duration duration, {required bool keepDeviation}) {
    _timer?.cancel();
    _cycleStartedAt = DateTime.now();
    _scheduledDuration = duration;
    if (!keepDeviation) {
      _cycleDeviationMs = null;
    }
    _timer = Timer(duration, _fireAndStartNextCycle);
  }

  Future<void> _fireAndStartNextCycle() async {
    _timer?.cancel();
    _timer = null;

    if (_inCallback) return;
    _inCallback = true;
    try {
      await Future<void>.sync(_onTimerFired);
    } finally {
      _inCallback = false;
    }

    if (!_paused) {
      _startNewCycle();
    }
  }
}

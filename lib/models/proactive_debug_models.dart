class ProactiveDebugLogEntry {
  const ProactiveDebugLogEntry({
    required this.timestamp,
    required this.event,
    required this.detail,
  });

  final DateTime timestamp;
  final String event;
  final String detail;
}

class ProactiveDebugSnapshot {
  const ProactiveDebugSnapshot({
    required this.running,
    required this.paused,
    required this.inFlight,
    required this.notificationsEnabled,
    required this.proactiveEnabled,
    required this.globalEnabled,
    required this.overlayOn,
    required this.screenLandscape,
    required this.screenOff,
    required this.cycleStartedAt,
    required this.nextTriggerAt,
    required this.scheduledDuration,
    required this.remainingDuration,
    required this.status,
    required this.logCount,
  });

  const ProactiveDebugSnapshot.initial()
    : running = false,
      paused = false,
      inFlight = false,
      notificationsEnabled = false,
      proactiveEnabled = false,
      globalEnabled = true,
      overlayOn = false,
      screenLandscape = false,
      screenOff = false,
      cycleStartedAt = null,
      nextTriggerAt = null,
      scheduledDuration = null,
      remainingDuration = null,
      status = 'idle',
      logCount = 0;

  final bool running;
  final bool paused;
  final bool inFlight;
  final bool notificationsEnabled;
  final bool proactiveEnabled;
  final bool globalEnabled;
  final bool overlayOn;
  final bool screenLandscape;
  final bool screenOff;
  final DateTime? cycleStartedAt;
  final DateTime? nextTriggerAt;
  final Duration? scheduledDuration;
  final Duration? remainingDuration;
  final String status;
  final int logCount;
}

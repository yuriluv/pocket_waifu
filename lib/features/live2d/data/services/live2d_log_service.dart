// ============================================================================
// ============================================================================
// ============================================================================

import 'dart:collection';
import 'package:flutter/foundation.dart';

enum Live2DLogLevel {
  debug,
  info,
  warning,
  error,
}

enum Live2DLogSource {
  flutter,
  native,
}

class Live2DLogEntry {
  final DateTime timestamp;
  final Live2DLogLevel level;
  final String tag;
  final String message;
  final String? details;
  final Object? error;
  final StackTrace? stackTrace;
  final Live2DLogSource source;

  const Live2DLogEntry({
    required this.timestamp,
    required this.level,
    required this.tag,
    required this.message,
    this.details,
    this.error,
    this.stackTrace,
    this.source = Live2DLogSource.flutter,
  });

  String get levelIcon {
    switch (level) {
      case Live2DLogLevel.debug:
        return '🔍';
      case Live2DLogLevel.info:
        return 'ℹ️';
      case Live2DLogLevel.warning:
        return '⚠️';
      case Live2DLogLevel.error:
        return '❌';
    }
  }
  
  String get sourceIcon {
    switch (source) {
      case Live2DLogSource.flutter:
        return '🐦';
      case Live2DLogSource.native:
        return '🤖';
    }
  }

  String get formattedTime {
    final h = timestamp.hour.toString().padLeft(2, '0');
    final m = timestamp.minute.toString().padLeft(2, '0');
    final s = timestamp.second.toString().padLeft(2, '0');
    final ms = timestamp.millisecond.toString().padLeft(3, '0');
    return '$h:$m:$s.$ms';
  }

  @override
  String toString() {
    final buffer = StringBuffer();
    buffer.write('[$formattedTime] $sourceIcon $levelIcon [$tag] $message');
    if (details != null) {
      buffer.write('\n  → $details');
    }
    if (error != null) {
      buffer.write('\n  Error: $error');
    }
    return buffer.toString();
  }
  
  factory Live2DLogEntry.fromNativeLog(Map<String, dynamic> map) {
    final levelStr = (map['level'] as String?) ?? 'debug';
    final level = Live2DLogLevel.values.firstWhere(
      (e) => e.name == levelStr,
      orElse: () => Live2DLogLevel.debug,
    );
    
    return Live2DLogEntry(
      timestamp: DateTime.fromMillisecondsSinceEpoch(
        (map['timestamp'] as int?) ?? DateTime.now().millisecondsSinceEpoch,
      ),
      level: level,
      tag: (map['tag'] as String?) ?? 'Native',
      message: (map['message'] as String?) ?? '',
      details: map['details'] as String?,
      error: map['error'],
      stackTrace: map['stackTrace'] != null 
          ? StackTrace.fromString(map['stackTrace'] as String)
          : null,
      source: Live2DLogSource.native,
    );
  }
}

class Live2DLogService extends ChangeNotifier {
  static final Live2DLogService _instance = Live2DLogService._internal();
  factory Live2DLogService() => _instance;
  Live2DLogService._internal();

  static const int maxLogEntries = 500;
  Live2DLogLevel _minLevel = Live2DLogLevel.debug;

  final Queue<Live2DLogEntry> _logs = Queue<Live2DLogEntry>();
  bool _isEnabled = true;

  // === Getter ===
  List<Live2DLogEntry> get logs => _logs.toList();
  List<Live2DLogEntry> get errorLogs => 
      _logs.where((e) => e.level == Live2DLogLevel.error).toList();
  List<Live2DLogEntry> get warningLogs =>
      _logs.where((e) => e.level == Live2DLogLevel.warning).toList();
  bool get hasErrors => _logs.any((e) => e.level == Live2DLogLevel.error);
  bool get isEnabled => _isEnabled;
  int get logCount => _logs.length;

  void setEnabled(bool enabled) {
    _isEnabled = enabled;
  }

  void setMinLevel(Live2DLogLevel level) {
    _minLevel = level;
  }

  void _addLog(Live2DLogEntry entry) {
    if (!_isEnabled) return;
    if (entry.level.index < _minLevel.index) return;

    _logs.addLast(entry);

    while (_logs.length > maxLogEntries) {
      _logs.removeFirst();
    }

    debugPrint(entry.toString());

    notifyListeners();
  }

  void debug(String tag, String message, {String? details}) {
    _addLog(Live2DLogEntry(
      timestamp: DateTime.now(),
      level: Live2DLogLevel.debug,
      tag: tag,
      message: message,
      details: details,
    ));
  }

  void info(String tag, String message, {String? details}) {
    _addLog(Live2DLogEntry(
      timestamp: DateTime.now(),
      level: Live2DLogLevel.info,
      tag: tag,
      message: message,
      details: details,
    ));
  }

  void warning(String tag, String message, {String? details, Object? error}) {
    _addLog(Live2DLogEntry(
      timestamp: DateTime.now(),
      level: Live2DLogLevel.warning,
      tag: tag,
      message: message,
      details: details,
      error: error,
    ));
  }

  void error(
    String tag,
    String message, {
    String? details,
    Object? error,
    StackTrace? stackTrace,
  }) {
    _addLog(Live2DLogEntry(
      timestamp: DateTime.now(),
      level: Live2DLogLevel.error,
      tag: tag,
      message: message,
      details: details,
      error: error,
      stackTrace: stackTrace,
    ));
  }

  void clear() {
    _logs.clear();
    notifyListeners();
  }

  List<Live2DLogEntry> getLogsAboveLevel(Live2DLogLevel level) {
    return _logs.where((e) => e.level.index >= level.index).toList();
  }

  List<Live2DLogEntry> getLogsByTag(String tag) {
    return _logs.where((e) => e.tag == tag).toList();
  }

  String exportLogs() {
    final buffer = StringBuffer();
    buffer.writeln('=== Live2D 로그 내보내기 ===');
    buffer.writeln('시간: ${DateTime.now().toIso8601String()}');
    buffer.writeln('총 로그 수: ${_logs.length}');
    buffer.writeln('에러 수: ${errorLogs.length}');
    buffer.writeln('경고 수: ${warningLogs.length}');
    buffer.writeln('');
    buffer.writeln('=== 로그 내용 ===');
    
    for (final log in _logs) {
      buffer.writeln(log.toString());
    }
    
    return buffer.toString();
  }
  
  // ============================================================================
  // ============================================================================
  
  void addNativeLog(Map<String, dynamic> logData) {
    final entry = Live2DLogEntry.fromNativeLog(logData);
    _addLog(entry);
  }
  
  List<Live2DLogEntry> getLogsBySource(Live2DLogSource source) {
    return _logs.where((e) => e.source == source).toList();
  }
  
  List<Live2DLogEntry> get flutterLogs => getLogsBySource(Live2DLogSource.flutter);
  
  List<Live2DLogEntry> get nativeLogs => getLogsBySource(Live2DLogSource.native);
  
  Map<String, int> getStatistics() {
    return {
      'total': _logs.length,
      'flutter': flutterLogs.length,
      'native': nativeLogs.length,
      'debug': _logs.where((e) => e.level == Live2DLogLevel.debug).length,
      'info': _logs.where((e) => e.level == Live2DLogLevel.info).length,
      'warning': warningLogs.length,
      'error': errorLogs.length,
    };
  }
}

Live2DLogService get live2dLog => Live2DLogService();

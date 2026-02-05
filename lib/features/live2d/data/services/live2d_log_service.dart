// ============================================================================
// Live2D 로그 서비스 (Live2D Log Service)
// ============================================================================
// Live2D 관련 로그를 수집하고 표시하는 서비스입니다.
// 모델 로드 오류, 서버 오류 등을 추적할 수 있습니다.
// Native 측 로그도 수신하여 통합 관리합니다.
// ============================================================================

import 'dart:collection';
import 'package:flutter/foundation.dart';

/// 로그 레벨
enum Live2DLogLevel {
  debug,
  info,
  warning,
  error,
}

/// 로그 소스 (Flutter 또는 Native)
enum Live2DLogSource {
  flutter,
  native,
}

/// 로그 항목
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
  
  /// Native 로그 Map에서 생성
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

/// Live2D 로그 서비스 (싱글톤)
class Live2DLogService extends ChangeNotifier {
  // === 싱글톤 패턴 ===
  static final Live2DLogService _instance = Live2DLogService._internal();
  factory Live2DLogService() => _instance;
  Live2DLogService._internal();

  // === 설정 ===
  static const int maxLogEntries = 500;
  Live2DLogLevel _minLevel = Live2DLogLevel.debug;

  // === 상태 ===
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

  /// 로깅 활성화/비활성화
  void setEnabled(bool enabled) {
    _isEnabled = enabled;
  }

  /// 최소 로그 레벨 설정
  void setMinLevel(Live2DLogLevel level) {
    _minLevel = level;
  }

  /// 로그 추가
  void _addLog(Live2DLogEntry entry) {
    if (!_isEnabled) return;
    if (entry.level.index < _minLevel.index) return;

    _logs.addLast(entry);

    // 최대 개수 초과 시 오래된 로그 삭제
    while (_logs.length > maxLogEntries) {
      _logs.removeFirst();
    }

    // 콘솔에도 출력
    debugPrint(entry.toString());

    notifyListeners();
  }

  /// 디버그 로그
  void debug(String tag, String message, {String? details}) {
    _addLog(Live2DLogEntry(
      timestamp: DateTime.now(),
      level: Live2DLogLevel.debug,
      tag: tag,
      message: message,
      details: details,
    ));
  }

  /// 정보 로그
  void info(String tag, String message, {String? details}) {
    _addLog(Live2DLogEntry(
      timestamp: DateTime.now(),
      level: Live2DLogLevel.info,
      tag: tag,
      message: message,
      details: details,
    ));
  }

  /// 경고 로그
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

  /// 에러 로그
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

  /// 로그 클리어
  void clear() {
    _logs.clear();
    notifyListeners();
  }

  /// 특정 레벨 이상의 로그만 가져오기
  List<Live2DLogEntry> getLogsAboveLevel(Live2DLogLevel level) {
    return _logs.where((e) => e.level.index >= level.index).toList();
  }

  /// 특정 태그의 로그만 가져오기
  List<Live2DLogEntry> getLogsByTag(String tag) {
    return _logs.where((e) => e.tag == tag).toList();
  }

  /// 전체 로그를 문자열로 내보내기
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
  // Native 로그 수신
  // ============================================================================
  
  /// Native에서 수신한 로그 추가
  void addNativeLog(Map<String, dynamic> logData) {
    final entry = Live2DLogEntry.fromNativeLog(logData);
    _addLog(entry);
  }
  
  /// 특정 소스의 로그만 가져오기
  List<Live2DLogEntry> getLogsBySource(Live2DLogSource source) {
    return _logs.where((e) => e.source == source).toList();
  }
  
  /// Flutter 로그만 가져오기
  List<Live2DLogEntry> get flutterLogs => getLogsBySource(Live2DLogSource.flutter);
  
  /// Native 로그만 가져오기
  List<Live2DLogEntry> get nativeLogs => getLogsBySource(Live2DLogSource.native);
  
  /// 로그 통계
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

/// 로그 서비스 글로벌 접근자
Live2DLogService get live2dLog => Live2DLogService();

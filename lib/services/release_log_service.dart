import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

enum ReleaseLogLevel { info, warning, error }

class ReleaseLogEvent {
  ReleaseLogEvent({
    required this.id,
    required this.timestamp,
    required this.level,
    required this.category,
    required this.message,
    required this.payload,
    this.retryCount = 0,
    DateTime? nextRetryAt,
  }) : nextRetryAt = nextRetryAt ?? timestamp;

  final String id;
  final DateTime timestamp;
  final ReleaseLogLevel level;
  final String category;
  final String message;
  final Map<String, String> payload;
  final int retryCount;
  final DateTime nextRetryAt;

  ReleaseLogEvent withRetry({required int retryCount, required DateTime nextRetryAt}) {
    return ReleaseLogEvent(
      id: id,
      timestamp: timestamp,
      level: level,
      category: category,
      message: message,
      payload: payload,
      retryCount: retryCount,
      nextRetryAt: nextRetryAt,
    );
  }

  Map<String, dynamic> toStorageJson() {
    return {
      'id': id,
      'timestamp': timestamp.toIso8601String(),
      'level': level.name,
      'category': category,
      'message': message,
      'payload': payload,
      'retryCount': retryCount,
      'nextRetryAt': nextRetryAt.toIso8601String(),
    };
  }

  Map<String, dynamic> toTransportJson() {
    return {
      'id': id,
      'timestamp': timestamp.toIso8601String(),
      'level': level.name,
      'category': category,
      'message': message,
      'payload': payload,
    };
  }

  factory ReleaseLogEvent.fromStorageJson(Map<String, dynamic> json) {
    final levelName = json['level'] as String? ?? ReleaseLogLevel.info.name;
    final parsedLevel = ReleaseLogLevel.values.firstWhere(
      (entry) => entry.name == levelName,
      orElse: () => ReleaseLogLevel.info,
    );

    final rawPayload = json['payload'];
    final payload = <String, String>{};
    if (rawPayload is Map) {
      for (final entry in rawPayload.entries) {
        payload[entry.key.toString()] = entry.value.toString();
      }
    }

    return ReleaseLogEvent(
      id: json['id'] as String,
      timestamp: DateTime.tryParse(json['timestamp'] as String? ?? '') ?? DateTime.now(),
      level: parsedLevel,
      category: json['category'] as String? ?? 'unknown',
      message: json['message'] as String? ?? '',
      payload: payload,
      retryCount: json['retryCount'] as int? ?? 0,
      nextRetryAt:
          DateTime.tryParse(json['nextRetryAt'] as String? ?? '') ?? DateTime.now(),
    );
  }
}

class ReleaseLogPolicy {
  static const bool uploadEnabled = bool.fromEnvironment(
    'LOG_UPLOAD_ENABLED',
    defaultValue: false,
  );
  static const String endpoint = String.fromEnvironment('LOG_ENDPOINT');
  static const String authToken = String.fromEnvironment('LOG_AUTH_TOKEN');

  static const Set<String> _payloadWhitelist = {
    'event',
    'reason',
    'httpStatus',
    'provider',
    'endpointHost',
    'errorType',
    'attempt',
    'network',
    'buildType',
  };

  static String sanitizeMessage(String input) {
    final compact = input.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (compact.length <= 200) {
      return compact;
    }
    return compact.substring(0, 200);
  }

  static Map<String, String> sanitizePayload(Map<String, String> raw) {
    final sanitized = <String, String>{};
    for (final entry in raw.entries) {
      if (_payloadWhitelist.contains(entry.key)) {
        sanitized[entry.key] = sanitizeMessage(entry.value);
      }
    }
    return sanitized;
  }
}

class ReleaseLogService {
  ReleaseLogService._();

  static final ReleaseLogService instance = ReleaseLogService._();

  static const _queueStorageKey = 'release_log_queue_v1';
  static const _maxQueueSize = 1000;
  static const _uploadBatchSize = 25;
  static const _baseRetrySeconds = 10;
  static const _maxRetryDelaySeconds = 1800;

  final Queue<ReleaseLogEvent> _queue = Queue<ReleaseLogEvent>();
  final Uuid _uuid = const Uuid();
  final String _sessionId = const Uuid().v4();

  SharedPreferences? _prefs;
  http.Client _httpClient = http.Client();
  Timer? _flushTimer;

  bool _initialized = false;
  bool _isFlushing = false;

  @visibleForTesting
  set httpClient(http.Client client) {
    _httpClient = client;
  }

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    _prefs = await SharedPreferences.getInstance();
    _restoreQueue();
    _initialized = true;

    if (!ReleaseLogPolicy.uploadEnabled || ReleaseLogPolicy.endpoint.isEmpty) {
      return;
    }

    _flushTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      unawaited(flush());
    });

    await flush();
  }

  Future<void> dispose() async {
    _flushTimer?.cancel();
    _httpClient.close();
  }

  Future<void> info(String category, String message, {Map<String, String> payload = const {}}) {
    return _enqueue(
      ReleaseLogLevel.info,
      category,
      message,
      payload,
    );
  }

  Future<void> warning(
    String category,
    String message, {
    Map<String, String> payload = const {},
  }) {
    return _enqueue(
      ReleaseLogLevel.warning,
      category,
      message,
      payload,
    );
  }

  Future<void> error(String category, String message, {Map<String, String> payload = const {}}) {
    return _enqueue(
      ReleaseLogLevel.error,
      category,
      message,
      payload,
    );
  }

  Future<void> _enqueue(
    ReleaseLogLevel level,
    String category,
    String message,
    Map<String, String> payload,
  ) async {
    if (!_initialized) {
      await initialize();
    }

    final event = ReleaseLogEvent(
      id: _uuid.v4(),
      timestamp: DateTime.now().toUtc(),
      level: level,
      category: ReleaseLogPolicy.sanitizeMessage(category),
      message: ReleaseLogPolicy.sanitizeMessage(message),
      payload: ReleaseLogPolicy.sanitizePayload(payload),
    );

    _queue.addLast(event);
    while (_queue.length > _maxQueueSize) {
      _queue.removeFirst();
    }
    await _persistQueue();

    if (ReleaseLogPolicy.uploadEnabled && ReleaseLogPolicy.endpoint.isNotEmpty) {
      unawaited(flush());
    }
  }

  Future<void> flush() async {
    if (_isFlushing || !ReleaseLogPolicy.uploadEnabled || ReleaseLogPolicy.endpoint.isEmpty) {
      return;
    }
    if (_queue.isEmpty) {
      return;
    }

    _isFlushing = true;

    try {
      final now = DateTime.now().toUtc();
      final readyEvents = _queue
          .where((entry) => !entry.nextRetryAt.isAfter(now))
          .take(_uploadBatchSize)
          .toList(growable: false);

      if (readyEvents.isEmpty) {
        return;
      }

      final response = await _httpClient.post(
        Uri.parse(ReleaseLogPolicy.endpoint),
        headers: _buildHeaders(),
        body: jsonEncode({
          'sessionId': _sessionId,
          'sentAt': DateTime.now().toUtc().toIso8601String(),
          'events': readyEvents.map((entry) => entry.toTransportJson()).toList(),
        }),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        for (final event in readyEvents) {
          _queue.remove(event);
        }
      } else {
        _scheduleRetry(
          readyEvents,
          reason: 'http_${response.statusCode}',
        );
      }

      await _persistQueue();
    } catch (_) {
      final now = DateTime.now().toUtc();
      final readyEvents = _queue
          .where((entry) => !entry.nextRetryAt.isAfter(now))
          .take(_uploadBatchSize)
          .toList(growable: false);
      _scheduleRetry(readyEvents, reason: 'network_error');
      await _persistQueue();
    } finally {
      _isFlushing = false;
    }
  }

  Map<String, String> _buildHeaders() {
    final headers = <String, String>{
      'Content-Type': 'application/json',
    };
    if (ReleaseLogPolicy.authToken.isNotEmpty) {
      headers['Authorization'] = 'Bearer ${ReleaseLogPolicy.authToken}';
    }
    return headers;
  }

  void _scheduleRetry(List<ReleaseLogEvent> entries, {required String reason}) {
    for (final entry in entries) {
      final nextCount = entry.retryCount + 1;
      final retryDelaySeconds = min(
        _maxRetryDelaySeconds,
        _baseRetrySeconds * pow(2, nextCount - 1).toInt(),
      );
      final replacement = entry.withRetry(
        retryCount: nextCount,
        nextRetryAt: DateTime.now().toUtc().add(Duration(seconds: retryDelaySeconds)),
      );

      if (_queue.remove(entry)) {
        _queue.addLast(replacement);
      }
    }

    if (kDebugMode) {
      debugPrint('ReleaseLogService retry scheduled: $reason');
    }
  }

  void _restoreQueue() {
    final raw = _prefs?.getString(_queueStorageKey);
    if (raw == null || raw.isEmpty) {
      return;
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return;
      }

      for (final item in decoded) {
        if (item is Map<String, dynamic>) {
          _queue.addLast(ReleaseLogEvent.fromStorageJson(item));
        } else if (item is Map) {
          _queue.addLast(
            ReleaseLogEvent.fromStorageJson(item.cast<String, dynamic>()),
          );
        }
      }
    } catch (_) {
      if (kDebugMode) {
        debugPrint('ReleaseLogService queue restore failed: invalid payload');
      }
    }
  }

  Future<void> _persistQueue() async {
    final payload = _queue.map((event) => event.toStorageJson()).toList(growable: false);
    await _prefs?.setString(_queueStorageKey, jsonEncode(payload));
  }
}

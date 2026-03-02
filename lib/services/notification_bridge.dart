import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class NotificationAction {
  final String type;
  final String? message;
  final String? sessionId;

  const NotificationAction({
    required this.type,
    this.message,
    this.sessionId,
  });
}

class NotificationBridge {
  NotificationBridge._internal();

  static final NotificationBridge instance = NotificationBridge._internal();

  static const MethodChannel _channel =
      MethodChannel('com.example.flutter_application_1/notifications');

  final StreamController<NotificationAction> _actions =
      StreamController.broadcast();

  Stream<NotificationAction> get actions => _actions.stream;

  Future<void> initialize() async {
    // Notification pipeline diagnostics: bridge initialized.
    // Used to trace ProactiveResponseService -> NotificationCoordinator -> NotificationBridge.
    // Android native logs are emitted in MainActivity / NotificationHelper.
    _channel.setMethodCallHandler(_handleMethodCall);
    debugPrint('NotificationBridge: method channel handler registered');
    final pending = await _channel.invokeMethod<List<dynamic>>(
      'drainPendingActions',
    );
    debugPrint('NotificationBridge: drained pending actions count=${pending?.length ?? 0}');
    if (pending != null) {
      for (final item in pending) {
        if (item is Map) {
          debugPrint('NotificationBridge: enqueue drained action type=${item['type']}');
          _actions.add(_mapToAction(item));
        }
      }
    }
  }

  Future<void> initializeChannels() async {
    await _channel.invokeMethod('initializeChannels');
  }

  Future<void> showPreResponseNotification({
    required String title,
    required String message,
    bool isError = false,
    String? sessionId,
  }) async {
    // Notification pipeline diagnostics: last Dart-side stage before Android native dispatch.
    await _channel.invokeMethod('showPreResponseNotification', {
      'title': title,
      'message': message,
      'isError': isError,
      'sessionId': sessionId,
    });
  }

  Future<void> clearAll() async {
    await _channel.invokeMethod('clearAllNotifications');
  }

  Future<void> setNotificationsEnabled(bool enabled) async {
    await _channel.invokeMethod('setNotificationsEnabled', {
      'enabled': enabled,
    });
  }

  Future<void> _handleMethodCall(MethodCall call) async {
    if (call.method == 'notificationAction') {
      debugPrint('NotificationBridge: notificationAction method received');
      if (call.arguments is Map) {
        final args = call.arguments as Map;
        debugPrint('NotificationBridge: stream action type=${args['type']}');
        _actions.add(_mapToAction(call.arguments as Map));
      }
    }
  }

  NotificationAction _mapToAction(Map data) {
    return NotificationAction(
      type: data['type'] as String? ?? 'unknown',
      message: data['message'] as String?,
      sessionId: data['sessionId'] as String?,
    );
  }
}

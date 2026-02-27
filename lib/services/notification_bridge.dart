import 'dart:async';
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
    _channel.setMethodCallHandler(_handleMethodCall);
    final pending = await _channel.invokeMethod<List<dynamic>>(
      'drainPendingActions',
    );
    if (pending != null) {
      for (final item in pending) {
        if (item is Map) {
          _actions.add(_mapToAction(item));
        }
      }
    }
  }

  Future<void> initializeChannels() async {
    await _channel.invokeMethod('initializeChannels');
  }

  Future<void> startForegroundService({
    required String title,
    required String message,
    required bool ongoing,
    String? sessionId,
  }) async {
    await _channel.invokeMethod('startForegroundService', {
      'title': title,
      'message': message,
      'ongoing': ongoing,
      'sessionId': sessionId,
    });
  }

  Future<void> stopForegroundService() async {
    await _channel.invokeMethod('stopForegroundService');
  }

  Future<void> updatePersistentNotification({
    required String title,
    required String message,
    bool isLoading = false,
    bool isError = false,
    bool ongoing = true,
    String? sessionId,
  }) async {
    await _channel.invokeMethod('updatePersistentNotification', {
      'title': title,
      'message': message,
      'isLoading': isLoading,
      'isError': isError,
      'ongoing': ongoing,
      'sessionId': sessionId,
    });
  }

  Future<void> showHeadsUpNotification({
    required String title,
    required String message,
    String? sessionId,
  }) async {
    await _channel.invokeMethod('showHeadsUpNotification', {
      'title': title,
      'message': message,
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
      if (call.arguments is Map) {
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

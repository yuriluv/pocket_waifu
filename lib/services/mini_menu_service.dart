import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

typedef MiniMenuGetActiveSessionId = String? Function();
typedef MiniMenuGetMessages = Future<List<Map<String, dynamic>>> Function(
  String? sessionId,
);
typedef MiniMenuSendMessage = Future<Map<String, dynamic>> Function(
  String message,
  String? sessionId,
);
typedef MiniMenuCaptureAndSend = Future<Map<String, dynamic>> Function(
  String? sessionId,
  String text,
);
typedef MiniMenuGetNotificationsEnabled = bool Function();
typedef MiniMenuSetNotificationsEnabled = Future<void> Function(bool enabled);
typedef MiniMenuToggleTouchThrough = Future<bool> Function();
typedef MiniMenuGetTouchThroughEnabled = Future<bool> Function();

class MiniMenuService {
  MiniMenuService._internal() {
    _channel.setMethodCallHandler(_handleMethodCall);
    debugPrint('MiniMenuService: method handler registered eagerly');
  }

  static final MiniMenuService instance = MiniMenuService._internal();

  static const MethodChannel _channel =
      MethodChannel('com.example.flutter_application_1/mini_menu');

  final StreamController<Map<String, dynamic>> _events =
      StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get events => _events.stream;

  MiniMenuGetActiveSessionId? _getActiveSessionId;
  MiniMenuGetMessages? _getMessages;
  MiniMenuSendMessage? _sendMessage;
  MiniMenuCaptureAndSend? _captureAndSend;
  MiniMenuGetNotificationsEnabled? _getNotificationsEnabled;
  MiniMenuSetNotificationsEnabled? _setNotificationsEnabled;
  MiniMenuToggleTouchThrough? _toggleTouchThrough;
  MiniMenuGetTouchThroughEnabled? _getTouchThroughEnabled;
  bool _isMiniMenuOpen = false;
  String? _lastSessionId;

  bool get isMiniMenuOpen => _isMiniMenuOpen;
  String? get lastSessionId => _lastSessionId;

  void configure({
    required MiniMenuGetActiveSessionId getActiveSessionId,
    required MiniMenuGetMessages getMessages,
    required MiniMenuSendMessage sendMessage,
    required MiniMenuCaptureAndSend captureAndSend,
    required MiniMenuGetNotificationsEnabled getNotificationsEnabled,
    required MiniMenuSetNotificationsEnabled setNotificationsEnabled,
    required MiniMenuToggleTouchThrough toggleTouchThrough,
    required MiniMenuGetTouchThroughEnabled getTouchThroughEnabled,
  }) {
    debugPrint('MiniMenuService: configure() called');
    _getActiveSessionId = getActiveSessionId;
    _getMessages = getMessages;
    _sendMessage = sendMessage;
    _captureAndSend = captureAndSend;
    _getNotificationsEnabled = getNotificationsEnabled;
    _setNotificationsEnabled = setNotificationsEnabled;
    _toggleTouchThrough = toggleTouchThrough;
    _getTouchThroughEnabled = getTouchThroughEnabled;
  }

  Future<void> openMiniMenu({String? sessionId}) async {
    try {
      await _channel.invokeMethod('openMiniMenu', {'sessionId': sessionId});
      _isMiniMenuOpen = true;
      _lastSessionId = sessionId ?? _lastSessionId;
    } on MissingPluginException {
      debugPrint('MiniMenuService: native mini menu channel unavailable');
    }
  }

  Future<void> closeMiniMenu() async {
    try {
      await _channel.invokeMethod('closeMiniMenu');
      _isMiniMenuOpen = false;
    } on MissingPluginException {
      debugPrint('MiniMenuService: native mini menu channel unavailable');
    }
  }

  Future<dynamic> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'miniMenuGetActiveSessionId':
        return _getActiveSessionId?.call();
      case 'miniMenuGetMessages':
        final sessionId = (call.arguments as Map?)?['sessionId'] as String?;
        return await _getMessages?.call(sessionId) ?? const <Map<String, dynamic>>[];
      case 'miniMenuSendMessage':
        final args = Map<String, dynamic>.from(call.arguments as Map? ?? const {});
        final message = (args['message'] as String? ?? '').trim();
        final sessionId = args['sessionId'] as String?;
        if (message.isEmpty) {
          return {'ok': false, 'error': 'empty_message'};
        }
        return await _sendMessage?.call(message, sessionId) ??
            {'ok': false, 'error': 'handler_unavailable'};
      case 'miniMenuCaptureAndSendScreenshot':
        final args = Map<String, dynamic>.from(call.arguments as Map? ?? const {});
        final sessionId = args['sessionId'] as String?;
        final text = (args['text'] as String? ?? '').trim();
        return await _captureAndSend?.call(sessionId, text) ??
            {'ok': false, 'error': 'handler_unavailable'};
      case 'miniMenuGetNotificationEnabled':
        return _getNotificationsEnabled?.call() ?? false;
      case 'miniMenuSetNotificationEnabled':
        final enabled =
            (Map<String, dynamic>.from(call.arguments as Map? ?? const {}))['enabled']
                    as bool? ??
                false;
        await _setNotificationsEnabled?.call(enabled);
        return true;
      case 'miniMenuToggleTouchThrough':
        return await _toggleTouchThrough?.call() ?? false;
      case 'miniMenuGetTouchThroughEnabled':
        return await _getTouchThroughEnabled?.call() ?? false;
      case 'miniMenuEvent':
        final event =
            Map<String, dynamic>.from(call.arguments as Map? ?? const <String, dynamic>{});
        _events.add(event);
        return true;
      default:
        return null;
    }
  }
}

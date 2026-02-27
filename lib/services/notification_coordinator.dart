import 'dart:async';
import 'package:flutter/foundation.dart';

import '../models/api_config.dart';
import '../models/message.dart';
import '../providers/chat_session_provider.dart';
import '../providers/global_runtime_provider.dart';
import '../providers/notification_settings_provider.dart';
import '../providers/prompt_block_provider.dart';
import '../providers/settings_provider.dart';
import '../services/api_service.dart';
import '../services/global_runtime_registry.dart';
import '../services/live2d_quick_toggle_service.dart';
import '../services/notification_bridge.dart';

enum NotificationRequestOrigin { reply, proactive }
enum NotificationRequestResult { completed, cancelled, failed }

class NotificationCoordinator implements GlobalRuntimeListener {
  NotificationCoordinator({
    required NotificationBridge bridge,
  }) : _bridge = bridge;

  final NotificationBridge _bridge;
  final ApiService _apiService = ApiService();

  SettingsProvider? _settingsProvider;
  PromptBlockProvider? _promptBlockProvider;
  ChatSessionProvider? _sessionProvider;
  NotificationSettingsProvider? _notificationSettingsProvider;
  GlobalRuntimeProvider? _globalRuntimeProvider;

  StreamSubscription<NotificationAction>? _subscription;

  bool _initialized = false;
  ApiRequestHandle? _activeRequest;
  NotificationRequestOrigin? _activeOrigin;
  VoidCallback? _onUserReply;

  void attach({
    required SettingsProvider settingsProvider,
    required PromptBlockProvider promptBlockProvider,
    required ChatSessionProvider sessionProvider,
    required NotificationSettingsProvider notificationSettingsProvider,
    required GlobalRuntimeProvider globalRuntimeProvider,
  }) {
    _settingsProvider = settingsProvider;
    _promptBlockProvider = promptBlockProvider;
    _sessionProvider = sessionProvider;
    _notificationSettingsProvider = notificationSettingsProvider;
    _globalRuntimeProvider = globalRuntimeProvider;

    if (!_initialized) {
      _initialized = true;
      _initialize();
    } else {
      _syncPersistentNotification();
    }
  }

  void setOnUserReplyHandler(VoidCallback? handler) {
    _onUserReply = handler;
  }

  Future<void> _initialize() async {
    await _bridge.initialize();
    await _bridge.initializeChannels();
    _subscription = _bridge.actions.listen(_handleAction);
    GlobalRuntimeRegistry.instance.register(this);
    _syncPersistentNotification();
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    _subscription = null;
    GlobalRuntimeRegistry.instance.unregister(this);
  }

  Future<void> _handleAction(NotificationAction action) async {
    switch (action.type) {
      case 'reply':
        if (action.message != null) {
          await handleNotificationReply(
            action.message!,
            sessionId: action.sessionId,
          );
        }
        break;
      case 'touchThrough':
        await Live2DQuickToggleService.instance.toggleTouchThrough();
        break;
      case 'cancelReply':
        await _syncPersistentNotification();
        break;
    }
  }

  Future<void> _syncPersistentNotification() async {
    final settings = _notificationSettingsProvider?.notificationSettings;
    final globalEnabled = _globalRuntimeProvider?.isEnabled ?? true;
    if (settings == null || !globalEnabled) return;

    if (settings.notificationsEnabled && settings.persistentEnabled) {
      final title = _settingsProvider!.character.name;
      await _bridge.startForegroundService(
        title: title,
        message: '대기 중',
        ongoing: true,
        sessionId: _sessionProvider?.activeSessionId,
      );
    } else if (settings.notificationsEnabled && !settings.persistentEnabled) {
      final title = _settingsProvider!.character.name;
      await _bridge.stopForegroundService();
      await _bridge.updatePersistentNotification(
        title: title,
        message: '대기 중',
        ongoing: false,
        sessionId: _sessionProvider?.activeSessionId,
      );
    } else {
      await _bridge.clearAll();
      await _bridge.stopForegroundService();
    }
  }

  Future<void> handleNotificationReply(
    String message, {
    String? sessionId,
  }) async {
    cancelProactiveInFlight();
    _onUserReply?.call();
    final sessionProvider = _sessionProvider;
    final settingsProvider = _settingsProvider;
    final promptProvider = _promptBlockProvider;
    final notificationSettings = _notificationSettingsProvider?.notificationSettings;

    if (sessionProvider == null ||
        settingsProvider == null ||
        promptProvider == null ||
        notificationSettings == null) {
      return;
    }

    final resolvedSessionId = sessionId ?? sessionProvider.activeSessionId;
    if (resolvedSessionId == null) return;

    final title = settingsProvider.character.name;
    await _bridge.updatePersistentNotification(
      title: title,
      message: 'Responding...',
      isLoading: true,
      ongoing: notificationSettings.persistentEnabled,
      sessionId: resolvedSessionId,
    );

    await sessionProvider.runSerialized(() async {
      sessionProvider.addMessageToSession(
        resolvedSessionId,
        Message(role: MessageRole.user, content: message),
      );

      final apiConfig = _resolveApiConfig(notificationSettings.apiPresetId);

      final requestHandle = _apiService.createRequestHandle();
      _activeRequest = requestHandle;
      _activeOrigin = NotificationRequestOrigin.reply;
      final cancelListener =
          GlobalRuntimeRegistry.instance.registerCancelable(requestHandle.cancel);

      try {
        final response = await _sendWithPromptBlocks(
          promptProvider: promptProvider,
          sessionProvider: sessionProvider,
          sessionId: resolvedSessionId,
          currentInput: message,
          apiConfig: apiConfig,
          requestHandle: requestHandle,
        );

        sessionProvider.addMessageToSession(
          resolvedSessionId,
          Message(role: MessageRole.assistant, content: response),
        );

        await _bridge.updatePersistentNotification(
          title: title,
          message: response,
          ongoing: notificationSettings.persistentEnabled,
          sessionId: resolvedSessionId,
        );

        if (notificationSettings.outputAsNewNotification) {
          await _bridge.showHeadsUpNotification(
            title: title,
            message: response,
            sessionId: resolvedSessionId,
          );
        }
      } catch (e) {
        if (e is ApiCancelledException) {
          debugPrint('Notification reply cancelled');
        } else {
          await _bridge.updatePersistentNotification(
            title: title,
            message: '오류: ${e.toString().replaceFirst('Exception: ', '')}',
            isError: true,
            ongoing: notificationSettings.persistentEnabled,
            sessionId: resolvedSessionId,
          );
        }
      } finally {
        _activeRequest = null;
        _activeOrigin = null;
        GlobalRuntimeRegistry.instance.unregister(cancelListener);
      }
    });
  }

  Future<NotificationRequestResult> triggerProactiveResponse({
    required String sessionId,
    required bool skipInputBlock,
    required ApiConfig? apiConfig,
  }) async {
    final sessionProvider = _sessionProvider;
    final settingsProvider = _settingsProvider;
    final promptProvider = _promptBlockProvider;
    final notificationSettings = _notificationSettingsProvider?.notificationSettings;

    if (sessionProvider == null ||
        settingsProvider == null ||
        promptProvider == null ||
        notificationSettings == null) {
      return NotificationRequestResult.failed;
    }

    final title = settingsProvider.character.name;

    return sessionProvider.runSerialized(() async {
      final requestHandle = _apiService.createRequestHandle();
      _activeRequest = requestHandle;
      _activeOrigin = NotificationRequestOrigin.proactive;
      final cancelListener =
          GlobalRuntimeRegistry.instance.registerCancelable(requestHandle.cancel);

      try {
        final response = await _sendWithPromptBlocks(
          promptProvider: promptProvider,
          sessionProvider: sessionProvider,
          sessionId: sessionId,
          currentInput: '',
          apiConfig: apiConfig,
          requestHandle: requestHandle,
          skipInputBlock: skipInputBlock,
        );

        sessionProvider.addMessageToSession(
          sessionId,
          Message(role: MessageRole.assistant, content: response),
        );

        await _bridge.updatePersistentNotification(
          title: title,
          message: response,
          ongoing: notificationSettings.persistentEnabled,
          sessionId: sessionId,
        );

        if (notificationSettings.outputAsNewNotification) {
          await _bridge.showHeadsUpNotification(
            title: title,
            message: response,
            sessionId: sessionId,
          );
        }
        return NotificationRequestResult.completed;
      } catch (e) {
        if (e is ApiCancelledException) {
          debugPrint('Proactive response cancelled');
          return NotificationRequestResult.cancelled;
        } else {
          await _bridge.updatePersistentNotification(
            title: title,
            message: '오류: ${e.toString().replaceFirst('Exception: ', '')}',
            isError: true,
            ongoing: notificationSettings.persistentEnabled,
            sessionId: sessionId,
          );
          return NotificationRequestResult.failed;
        }
      } finally {
        _activeRequest = null;
        _activeOrigin = null;
        GlobalRuntimeRegistry.instance.unregister(cancelListener);
      }
    });
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

  Future<String> _sendWithPromptBlocks({
    required PromptBlockProvider promptProvider,
    required ChatSessionProvider sessionProvider,
    required String sessionId,
    required String currentInput,
    required ApiConfig? apiConfig,
    required ApiRequestHandle requestHandle,
    bool skipInputBlock = false,
  }) async {
    final messages = sessionProvider.getMessagesForSession(sessionId);
    final resolvedConfig =
        apiConfig ?? _settingsProvider?.activeApiConfig;
    if (resolvedConfig == null) {
      throw Exception('API 프리셋을 설정해주세요.');
    }
    final formattedMessages = promptProvider.buildMessagesForApi(
      messages,
      currentInput,
      hasFirstSystemPrompt: resolvedConfig.hasFirstSystemPrompt,
      requiresAlternateRole: resolvedConfig.requiresAlternateRole,
      skipInputBlock: skipInputBlock,
    );

    return _apiService.sendMessageWithConfig(
      apiConfig: resolvedConfig,
      messages: formattedMessages,
      settings: _settingsProvider!.settings,
      requestHandle: requestHandle,
    );
  }

  @override
  void onGlobalDisabled() {
    _activeRequest?.cancel();
    _activeRequest = null;
    _activeOrigin = null;
    _bridge.clearAll();
    _bridge.stopForegroundService();
  }

  @override
  void onGlobalEnabled() {
    _syncPersistentNotification();
  }

  void cancelProactiveInFlight() {
    if (_activeOrigin == NotificationRequestOrigin.proactive) {
      _activeRequest?.cancel();
      _activeRequest = null;
      _activeOrigin = null;
    }
  }

  String? get activeSessionId => _sessionProvider?.activeSessionId;
}

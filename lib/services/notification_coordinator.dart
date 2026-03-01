import 'dart:async';
import 'package:flutter/foundation.dart';

import '../models/api_config.dart';
import '../models/message.dart';
import '../models/settings.dart';
import '../features/live2d_llm/services/live2d_directive_service.dart';
import '../features/lua/services/lua_scripting_service.dart';
import '../features/regex/services/regex_pipeline_service.dart';
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
  NotificationCoordinator({required NotificationBridge bridge})
    : _bridge = bridge;

  final NotificationBridge _bridge;
  final ApiService _apiService = ApiService();
  final RegexPipelineService _regexPipeline = RegexPipelineService.instance;
  final LuaScriptingService _luaScriptingService = LuaScriptingService.instance;
  final Live2DDirectiveService _directiveService =
      Live2DDirectiveService.instance;

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
        await _bridge.clearAll();
        await _syncPersistentNotification();
        break;
    }
  }

  Future<void> _syncPersistentNotification() async {
    final settings = _notificationSettingsProvider?.notificationSettings;
    final globalEnabled = _globalRuntimeProvider?.isEnabled ?? true;
    if (settings == null) return;

    if (!globalEnabled || !settings.notificationsEnabled) {
      await _bridge.clearAll();
      await _bridge.stopForegroundService();
      return;
    }

    // Persistent notification mode is removed.
    await _bridge.stopForegroundService();
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
    final notificationSettings =
        _notificationSettingsProvider?.notificationSettings;

    if (sessionProvider == null ||
        settingsProvider == null ||
        promptProvider == null ||
        notificationSettings == null) {
      return;
    }

    final resolvedSessionId = sessionId ?? sessionProvider.activeSessionId;
    if (resolvedSessionId == null) {
      await _bridge.updatePersistentNotification(
        title: settingsProvider.character.name,
        message: '활성 세션이 없습니다. 앱에서 채팅 세션을 생성하세요.',
        isError: true,
        ongoing: false,
      );
      return;
    }

    final title = settingsProvider.character.name;
    await _bridge.updatePersistentNotification(
      title: title,
      message: 'Responding...',
      isLoading: true,
      ongoing: false,
      sessionId: resolvedSessionId,
    );

    await sessionProvider.runSerialized(() async {
      final preparedInput = await _prepareUserInput(
        message,
        settings: settingsProvider.settings,
        sessionId: resolvedSessionId,
        characterId: settingsProvider.character.id,
        characterName: settingsProvider.character.name,
        userName: settingsProvider.userName,
      );

      sessionProvider.addMessageToSession(
        resolvedSessionId,
        Message(role: MessageRole.user, content: preparedInput),
      );

      final proactiveSettings =
          _notificationSettingsProvider?.proactiveSettings;
      final apiConfig = _resolveApiConfig(
        proactiveSettings?.apiPresetId ?? notificationSettings.apiPresetId,
      );

      final requestHandle = _apiService.createRequestHandle();
      _activeRequest = requestHandle;
      _activeOrigin = NotificationRequestOrigin.reply;
      final cancelListener = GlobalRuntimeRegistry.instance.registerCancelable(
        requestHandle.cancel,
      );

      try {
        final response = await _sendWithPromptBlocks(
          promptProvider: promptProvider,
          sessionProvider: sessionProvider,
          sessionId: resolvedSessionId,
          currentInput: preparedInput,
          apiConfig: apiConfig,
          requestHandle: requestHandle,
        );

        final processedResponse = await _prepareAssistantOutput(
          response,
          settings: settingsProvider.settings,
          sessionId: resolvedSessionId,
          characterId: settingsProvider.character.id,
          characterName: settingsProvider.character.name,
          userName: settingsProvider.userName,
        );

        sessionProvider.addMessageToSession(
          resolvedSessionId,
          Message(role: MessageRole.assistant, content: processedResponse),
        );

        await _bridge.updatePersistentNotification(
          title: title,
          message: processedResponse,
          ongoing: false,
          sessionId: resolvedSessionId,
        );

        if (notificationSettings.outputAsNewNotification) {
          await _bridge.showHeadsUpNotification(
            title: title,
            message: processedResponse,
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
            ongoing: false,
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
    final notificationSettings =
        _notificationSettingsProvider?.notificationSettings;

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
      final cancelListener = GlobalRuntimeRegistry.instance.registerCancelable(
        requestHandle.cancel,
      );

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

        final processedResponse = await _prepareAssistantOutput(
          response,
          settings: settingsProvider.settings,
          sessionId: sessionId,
          characterId: settingsProvider.character.id,
          characterName: settingsProvider.character.name,
          userName: settingsProvider.userName,
        );

        sessionProvider.addMessageToSession(
          sessionId,
          Message(role: MessageRole.assistant, content: processedResponse),
        );

        await _bridge.updatePersistentNotification(
          title: title,
          message: processedResponse,
          ongoing: false,
          sessionId: sessionId,
        );

        if (notificationSettings.outputAsNewNotification) {
          await _bridge.showHeadsUpNotification(
            title: title,
            message: processedResponse,
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
            ongoing: false,
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

  Future<String> _prepareUserInput(
    String text, {
    required AppSettings settings,
    required String sessionId,
    required String characterId,
    required String characterName,
    required String userName,
  }) async {
    var output = text;
    if (settings.runRegexBeforeLua) {
      output = await _regexPipeline.applyUserInput(
        output,
        characterId: characterId,
        sessionId: sessionId,
      );
      output = await _luaScriptingService.onUserMessage(
        output,
        LuaHookContext(
          characterId: characterId,
          characterName: characterName,
          userName: userName,
        ),
      );
    } else {
      output = await _luaScriptingService.onUserMessage(
        output,
        LuaHookContext(
          characterId: characterId,
          characterName: characterName,
          userName: userName,
        ),
      );
      output = await _regexPipeline.applyUserInput(
        output,
        characterId: characterId,
        sessionId: sessionId,
      );
    }
    return output;
  }

  Future<String> _prepareAssistantOutput(
    String text, {
    required AppSettings settings,
    required String sessionId,
    required String characterId,
    required String characterName,
    required String userName,
  }) async {
    var output = text;
    if (settings.runRegexBeforeLua) {
      output = await _regexPipeline.applyAiOutput(
        output,
        characterId: characterId,
        sessionId: sessionId,
      );
      output = await _luaScriptingService.onAssistantMessage(
        output,
        LuaHookContext(
          characterId: characterId,
          characterName: characterName,
          userName: userName,
        ),
      );
    } else {
      output = await _luaScriptingService.onAssistantMessage(
        output,
        LuaHookContext(
          characterId: characterId,
          characterName: characterName,
          userName: userName,
        ),
      );
      output = await _regexPipeline.applyAiOutput(
        output,
        characterId: characterId,
        sessionId: sessionId,
      );
    }

    final directiveResult = await _directiveService.processAssistantOutput(
      output,
      parsingEnabled: settings.live2dDirectiveParsingEnabled,
    );
    output = directiveResult.cleanedText;

    if (settings.runRegexBeforeLua) {
      output = await _regexPipeline.applyDisplayOnly(
        output,
        characterId: characterId,
        sessionId: sessionId,
      );
      output = await _luaScriptingService.onDisplayRender(
        output,
        LuaHookContext(
          characterId: characterId,
          characterName: characterName,
          userName: userName,
        ),
      );
    } else {
      output = await _luaScriptingService.onDisplayRender(
        output,
        LuaHookContext(
          characterId: characterId,
          characterName: characterName,
          userName: userName,
        ),
      );
      output = await _regexPipeline.applyDisplayOnly(
        output,
        characterId: characterId,
        sessionId: sessionId,
      );
    }

    return output;
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
    final resolvedConfig = apiConfig ?? _settingsProvider?.activeApiConfig;
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

import 'dart:async';
import 'package:flutter/foundation.dart';

import '../models/api_config.dart';
import '../models/agent_prompt_preset.dart';
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
import '../services/image_cache_manager.dart';
import '../services/live2d_quick_toggle_service.dart';
import '../services/mini_menu_service.dart';
import '../services/notification_bridge.dart';
import '../services/prompt_builder.dart';

enum NotificationRequestOrigin { reply, proactive, agent }

enum NotificationRequestResult { completed, cancelled, failed }

class _AgentLoopLuaResult {
  const _AgentLoopLuaResult({
    required this.transformedOutput,
    this.notifyText,
    this.notifyOptions = const <String, String>{},
    this.shouldEnd = false,
  });

  final String transformedOutput;
  final String? notifyText;
  final Map<String, String> notifyOptions;
  final bool shouldEnd;
}

class _ParsedAgentAction {
  const _ParsedAgentAction({
    this.notifyText,
    this.notifyOptions = const <String, String>{},
    this.shouldEnd = false,
  });

  final String? notifyText;
  final Map<String, String> notifyOptions;
  final bool shouldEnd;
}

class NotificationCoordinator implements GlobalRuntimeListener {
  NotificationCoordinator({required NotificationBridge bridge})
    : _bridge = bridge;

  final NotificationBridge _bridge;
  final ApiService _apiService = ApiService();
  final PromptBuilder _promptBuilder = PromptBuilder();
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
  final Set<VoidCallback> _onUserReplyListeners = <VoidCallback>{};

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
      _syncNotificationState();
    }
  }

  void setOnUserReplyHandler(VoidCallback? handler) {
    _onUserReplyListeners.clear();
    if (handler != null) {
      _onUserReplyListeners.add(handler);
    }
  }

  void addOnUserReplyListener(VoidCallback listener) {
    _onUserReplyListeners.add(listener);
  }

  void removeOnUserReplyListener(VoidCallback listener) {
    _onUserReplyListeners.remove(listener);
  }

  Future<void> _initialize() async {
    await _bridge.initialize();
    await _bridge.initializeChannels();
    _subscription = _bridge.actions.listen(_handleAction);
    GlobalRuntimeRegistry.instance.register(this);
    _syncNotificationState();
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    _subscription = null;
    GlobalRuntimeRegistry.instance.unregister(this);
  }

  Future<void> _handleAction(NotificationAction action) async {
    switch (action.type) {
      case 'reply':
        debugPrint('NotificationCoordinator: action=reply session=${action.sessionId}');
        if (action.message != null) {
          await handleNotificationReply(
            action.message!,
            sessionId: action.sessionId,
          );
        }
        break;
      case 'menu':
        debugPrint('NotificationCoordinator: action=menu session=${action.sessionId}');
        await MiniMenuService.instance.openMiniMenu(sessionId: action.sessionId);
        break;
      case 'touchThrough':
        debugPrint('NotificationCoordinator: action=touchThrough session=${action.sessionId}');
        await Live2DQuickToggleService.instance.toggleTouchThrough();
        break;
      case 'cancelReply':
        debugPrint('NotificationCoordinator: action=cancelReply session=${action.sessionId}');
        await _bridge.clearAll();
        await _syncNotificationState();
        break;
    }
  }

  Future<void> _syncNotificationState() async {
    final settings = _notificationSettingsProvider?.notificationSettings;
    final globalEnabled = _globalRuntimeProvider?.isEnabled ?? true;
    if (settings == null) return;

    if (!globalEnabled || !settings.notificationsEnabled) {
      await _bridge.clearAll();
      return;
    }
  }

  Future<void> handleNotificationReply(
    String message, {
    String? sessionId,
  }) async {
    await _handleNotificationReplyInternal(
      message: message,
      sessionId: sessionId,
      images: const <ImageAttachment>[],
    );
  }

  Future<Map<String, dynamic>> handleMiniMenuReply(
    String message, {
    String? sessionId,
  }) async {
    final response = await _handleNotificationReplyInternal(
      message: message,
      sessionId: sessionId,
      images: const <ImageAttachment>[],
    );
    return {
      'ok': response != null,
      'response': response,
    };
  }

  Future<Map<String, dynamic>> handleMiniMenuReplyWithImages({
    required String message,
    required List<ImageAttachment> images,
    String? sessionId,
  }) async {
    final response = await _handleNotificationReplyInternal(
      message: message,
      sessionId: sessionId,
      images: images,
    );
    return {
      'ok': response != null,
      'response': response,
    };
  }

  Future<String?> _handleNotificationReplyInternal({
    required String message,
    String? sessionId,
    required List<ImageAttachment> images,
  }) async {
    if (!(_globalRuntimeProvider?.isEnabled ?? true)) {
      debugPrint('NotificationCoordinator: Master OFF, reply ignored');
      return null;
    }

    cancelProactiveInFlight();
    cancelAgentInFlight();
    for (final listener in List<VoidCallback>.from(_onUserReplyListeners)) {
      try {
        listener();
      } catch (e) {
        debugPrint('NotificationCoordinator user-reply listener error: $e');
      }
    }
    final sessionProvider = _sessionProvider;
    final settingsProvider = _settingsProvider;
    final promptProvider = _promptBlockProvider;
    final notificationSettings =
        _notificationSettingsProvider?.notificationSettings;

    if (sessionProvider == null ||
        settingsProvider == null ||
        promptProvider == null ||
        notificationSettings == null) {
      return null;
    }

    final resolvedSessionId = sessionId ?? sessionProvider.activeSessionId;
    if (resolvedSessionId == null) {
      await _bridge.showPreResponseNotification(
        title: settingsProvider.character.name,
        message: '활성 세션이 없습니다. 앱에서 채팅 세션을 생성하세요.',
        isError: true,
      );
      return null;
    }

    final title = settingsProvider.character.name;
    await _bridge.showPreResponseNotification(
      title: title,
      message: 'Responding...',
      sessionId: resolvedSessionId,
    );

    String? assistantResponse;
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
        Message(
          role: MessageRole.user,
          content: preparedInput,
          images: images,
        ),
      );

      final apiConfig = _resolveApiConfig(notificationSettings.apiPresetId);

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
          currentImages: images,
          apiConfig: apiConfig,
          promptPresetId: notificationSettings.promptPresetId,
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

        await _bridge.showPreResponseNotification(
          title: title,
          message: processedResponse,
          sessionId: resolvedSessionId,
        );
        assistantResponse = processedResponse;
      } catch (e) {
        if (e is ApiCancelledException) {
          debugPrint('Notification reply cancelled');
        } else {
          await _bridge.showPreResponseNotification(
            title: title,
            message: '오류: ${e.toString().replaceFirst('Exception: ', '')}',
            isError: true,
            sessionId: resolvedSessionId,
          );
        }
      } finally {
        _activeRequest = null;
        _activeOrigin = null;
        GlobalRuntimeRegistry.instance.unregister(cancelListener);
      }
    });
    return assistantResponse;
  }

  Future<NotificationRequestResult> triggerProactiveResponse({
    required String sessionId,
    required bool skipInputBlock,
    required ApiConfig? apiConfig,
  }) async {
    if (!(_globalRuntimeProvider?.isEnabled ?? true)) {
      debugPrint('NotificationCoordinator: Master OFF, proactive ignored');
      return NotificationRequestResult.cancelled;
    }

    final sessionProvider = _sessionProvider;
    final settingsProvider = _settingsProvider;
    final promptProvider = _promptBlockProvider;
    final notificationSettings =
        _notificationSettingsProvider?.notificationSettings;
    final proactiveSettings = _notificationSettingsProvider?.proactiveSettings;

    if (sessionProvider == null ||
        settingsProvider == null ||
        promptProvider == null ||
        notificationSettings == null) {
      return NotificationRequestResult.failed;
    }

    final title = settingsProvider.character.name;
    debugPrint(
      'NotificationCoordinator: proactive request queued session=$sessionId',
    );

    return sessionProvider.runSerialized(() async {
      cancelAgentInFlight();
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
          currentImages: const <ImageAttachment>[],
          apiConfig: apiConfig,
          promptPresetId: proactiveSettings?.promptPresetId,
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

        await _bridge.showPreResponseNotification(
          title: title,
          message: processedResponse,
          sessionId: sessionId,
        );
        debugPrint(
          'NotificationCoordinator -> NotificationBridge: dispatched pre-response notification session=$sessionId',
        );
        return NotificationRequestResult.completed;
      } catch (e) {
        if (e is ApiCancelledException) {
          debugPrint('Proactive response cancelled');
          return NotificationRequestResult.cancelled;
        } else {
          await _bridge.showPreResponseNotification(
            title: title,
            message: '오류: ${e.toString().replaceFirst('Exception: ', '')}',
            isError: true,
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

  Future<NotificationRequestResult> triggerAgentModeLoop({
    required String sessionId,
    required ApiConfig? apiConfig,
    required AgentPromptPreset promptPreset,
    required int maxIterations,
    required Duration timeout,
  }) async {
    if (!(_globalRuntimeProvider?.isEnabled ?? true)) {
      debugPrint('NotificationCoordinator: Master OFF, agent mode ignored');
      return NotificationRequestResult.cancelled;
    }

    final sessionProvider = _sessionProvider;
    final settingsProvider = _settingsProvider;
    final notificationSettings =
        _notificationSettingsProvider?.notificationSettings;
    if (sessionProvider == null ||
        settingsProvider == null ||
        notificationSettings == null ||
        !notificationSettings.notificationsEnabled) {
      return NotificationRequestResult.failed;
    }

    final resolvedConfig = apiConfig ?? _settingsProvider?.activeApiConfig;
    if (resolvedConfig == null) {
      return NotificationRequestResult.failed;
    }

    final title = settingsProvider.character.name;
    final boundedMaxIterations = maxIterations.clamp(1, 30).toInt();
    final boundedTimeoutSeconds = timeout.inSeconds.clamp(10, 900).toInt();

    cancelProactiveInFlight();
    final requestHandle = _apiService.createRequestHandle();
    _activeRequest = requestHandle;
    _activeOrigin = NotificationRequestOrigin.agent;
    final cancelListener = GlobalRuntimeRegistry.instance.registerCancelable(
      requestHandle.cancel,
    );

    final stopwatch = Stopwatch()..start();
    final stepHistory = <String>[];

    try {
      for (var step = 0; step < boundedMaxIterations; step++) {
        debugPrint('Agent mode loop iteration ${step + 1}/$boundedMaxIterations');

        if (requestHandle.isCancelled) {
          return NotificationRequestResult.cancelled;
        }

        final remaining =
            Duration(seconds: boundedTimeoutSeconds) - stopwatch.elapsed;
        if (remaining <= Duration.zero) {
          debugPrint('Agent mode loop timeout reached');
          requestHandle.cancel();
          return NotificationRequestResult.cancelled;
        }

        final response = await _sendAgentLoopStep(
          sessionProvider: sessionProvider,
          sessionId: sessionId,
          promptPreset: promptPreset,
          stepHistory: stepHistory,
          apiConfig: resolvedConfig,
          settings: settingsProvider.settings,
          requestHandle: requestHandle,
        ).timeout(remaining, onTimeout: () {
          requestHandle.cancel();
          throw TimeoutException('Agent loop step timed out');
        });

        final luaResult = await _processAgentLoopResponse(
          response: response,
          promptPreset: promptPreset,
          settings: settingsProvider.settings,
          characterId: settingsProvider.character.id,
          characterName: settingsProvider.character.name,
          userName: settingsProvider.userName,
        );

        if (luaResult.notifyText != null && luaResult.notifyText!.isNotEmpty) {
          final emotion = luaResult.notifyOptions['emotion'];
          if (emotion != null && emotion.isNotEmpty) {
            await _directiveService.processAssistantOutput(
              '<live2d><emotion name="$emotion"/></live2d>',
              parsingEnabled:
                  settingsProvider.settings.live2dLlmIntegrationEnabled &&
                  settingsProvider.settings.live2dDirectiveParsingEnabled,
            );
          }

          await _bridge.showPreResponseNotification(
            title: luaResult.notifyOptions['title'] ?? title,
            message: luaResult.notifyText!,
            sessionId: sessionId,
          );
          return NotificationRequestResult.completed;
        }

        if (luaResult.shouldEnd) {
          return NotificationRequestResult.cancelled;
        }

        stepHistory.add(
          _buildAgentStepHistoryEntry(
            stepIndex: step + 1,
            response: response,
            processedOutput: luaResult.transformedOutput,
          ),
        );
      }

      return NotificationRequestResult.cancelled;
    } catch (e) {
      if (e is ApiCancelledException || e is TimeoutException) {
        debugPrint('Agent mode loop cancelled: $e');
        return NotificationRequestResult.cancelled;
      }
      debugPrint('Agent mode loop failed: $e');
      return NotificationRequestResult.failed;
    } finally {
      stopwatch.stop();
      _activeRequest = null;
      _activeOrigin = null;
      GlobalRuntimeRegistry.instance.unregister(cancelListener);
    }
  }

  Future<String> _sendAgentLoopStep({
    required ChatSessionProvider sessionProvider,
    required String sessionId,
    required AgentPromptPreset promptPreset,
    required List<String> stepHistory,
    required ApiConfig apiConfig,
    required AppSettings settings,
    required ApiRequestHandle requestHandle,
  }) async {
    final sessionMessages = sessionProvider.getMessagesForSession(sessionId);
    final contextWindow = sessionMessages.length > 24
        ? sessionMessages.sublist(sessionMessages.length - 24)
        : sessionMessages;

    final messages = <Map<String, dynamic>>[
      {'role': 'system', 'content': promptPreset.systemPrompt},
      ...contextWindow.map(
        (message) => {
          'role': message.roleString,
          'content': message.content,
        },
      ),
      {
        'role': 'user',
        'content': _buildAgentTriggerPrompt(
          replyPrompt: promptPreset.replyPrompt,
          stepHistory: stepHistory,
        ),
      },
    ];

    return _apiService.sendMessageWithConfig(
      apiConfig: apiConfig,
      messages: messages,
      settings: settings,
      requestHandle: requestHandle,
    );
  }

  String _buildAgentTriggerPrompt({
    required String replyPrompt,
    required List<String> stepHistory,
  }) {
    final buffer = StringBuffer();
    if (replyPrompt.trim().isNotEmpty) {
      buffer.writeln(replyPrompt.trim());
      buffer.writeln();
    }

    buffer.writeln('[Trigger Event]');
    buffer.writeln(
      'Periodic trigger fired at ${DateTime.now().toIso8601String()}.',
    );

    if (stepHistory.isNotEmpty) {
      buffer.writeln();
      buffer.writeln('[Loop History]');
      for (final entry in stepHistory) {
        buffer.writeln(entry);
      }
    }

    return buffer.toString();
  }

  String _buildAgentStepHistoryEntry({
    required int stepIndex,
    required String response,
    required String processedOutput,
  }) {
    final rawSummary = response.length > 240
        ? '${response.substring(0, 240)}...'
        : response;
    final processedSummary = processedOutput.length > 240
        ? '${processedOutput.substring(0, 240)}...'
        : processedOutput;

    return '[Step $stepIndex]\nassistant=$rawSummary\nprocessed=$processedSummary';
  }

  Future<_AgentLoopLuaResult> _processAgentLoopResponse({
    required String response,
    required AgentPromptPreset promptPreset,
    required AppSettings settings,
    required String characterId,
    required String characterName,
    required String userName,
  }) async {
    final context = LuaHookContext(
      characterId: characterId,
      characterName: characterName,
      userName: userName,
    );

    if (settings.runRegexBeforeLua) {
      final regexApplied = _applyAgentRegexRules(response, promptPreset.regexRules);
      return _runAgentLuaStage(
        regexApplied,
        promptPreset,
        context,
        luaEnabled: settings.live2dLuaExecutionEnabled,
      );
    }

    final luaApplied = await _runAgentLuaStage(
      response,
      promptPreset,
      context,
      luaEnabled: settings.live2dLuaExecutionEnabled,
    );
    final regexApplied = _applyAgentRegexRules(
      luaApplied.transformedOutput,
      promptPreset.regexRules,
    );

    return _AgentLoopLuaResult(
      transformedOutput: regexApplied,
      notifyText: luaApplied.notifyText,
      notifyOptions: luaApplied.notifyOptions,
      shouldEnd: luaApplied.shouldEnd,
    );
  }

  String _applyAgentRegexRules(
    String input,
    List<AgentPromptRegexRule> rules,
  ) {
    var output = input;
    final applicable = rules.where((rule) {
      return rule.isEnabled && rule.pattern.trim().isNotEmpty;
    }).toList()..sort((a, b) => a.priority.compareTo(b.priority));

    for (final rule in applicable) {
      try {
        final regex = RegExp(
          rule.pattern,
          multiLine: rule.multiLine,
          dotAll: rule.dotAll,
          caseSensitive: rule.caseSensitive,
        );
        output = output.replaceAllMapped(regex, (match) {
          return _expandRegexReplacement(rule.replacement, match);
        });
      } catch (e) {
        debugPrint('Agent regex rule failed (${rule.name}): $e');
      }
    }

    return output;
  }

  String _expandRegexReplacement(String replacement, Match match) {
    var out = replacement.replaceAll(r'$$', '\u0000');
    for (var index = match.groupCount; index >= 0; index--) {
      out = out.replaceAll('\$$index', match.group(index) ?? '');
    }
    return out.replaceAll('\u0000', r'$');
  }

  Future<_AgentLoopLuaResult> _runAgentLuaStage(
    String input,
    AgentPromptPreset promptPreset,
    LuaHookContext context,
    {required bool luaEnabled}
  ) async {
    var output = input;
    if (luaEnabled) {
      output = await _luaScriptingService.onAssistantMessage(output, context);
      output = await _luaScriptingService.onDisplayRender(output, context);
    }

    final actionSource = _buildAgentActionSource(
      output: output,
      luaScript: promptPreset.luaScript,
    );
    final parsed = _parseAgentLuaAction(actionSource) ?? _parseAgentLuaAction(output);
    if (parsed == null) {
      return _AgentLoopLuaResult(transformedOutput: output);
    }

    return _AgentLoopLuaResult(
      transformedOutput: output,
      notifyText: parsed.notifyText,
      notifyOptions: parsed.notifyOptions,
      shouldEnd: parsed.shouldEnd,
    );
  }

  String _buildAgentActionSource({
    required String output,
    required String luaScript,
  }) {
    final source = luaScript.contains('{{response}}')
        ? luaScript.replaceAll('{{response}}', output)
        : output;
    final lines = source.split('\n');
    final nonCommentLines = lines.where((line) {
      return !line.trimLeft().startsWith('--');
    });
    return nonCommentLines.join('\n');
  }

  _ParsedAgentAction? _parseAgentLuaAction(String input) {
    final notifyPattern = RegExp(
      r'''notify\s*\(\s*(["'])([\s\S]*?)\1(?:\s*,\s*\{([\s\S]*?)\}\s*)?\)''',
      multiLine: true,
    );
    final endPattern = RegExp(r'\bend\s*\(\s*\)', multiLine: true);

    final notifyMatch = notifyPattern.firstMatch(input);
    final endMatch = endPattern.firstMatch(input);
    if (notifyMatch == null && endMatch == null) {
      return null;
    }

    if (notifyMatch != null &&
        (endMatch == null || notifyMatch.start < endMatch.start)) {
      final notifyText = notifyMatch.group(2)?.trim();
      if (notifyText != null && notifyText.isNotEmpty) {
        final optionsRaw = notifyMatch.group(3) ?? '';
        final options = _parseNotifyOptions(optionsRaw);
        return _ParsedAgentAction(
          notifyText: notifyText,
          notifyOptions: options,
        );
      }
    }

    if (endMatch != null) {
      return const _ParsedAgentAction(shouldEnd: true);
    }

    return null;
  }

  Map<String, String> _parseNotifyOptions(String optionsRaw) {
    final options = <String, String>{};
    if (optionsRaw.trim().isEmpty) return options;

    final plainKeyPattern = RegExp(
      r'''([A-Za-z_][A-Za-z0-9_]*)\s*[:=]\s*(["'])([\s\S]*?)\2''',
      multiLine: true,
    );
    for (final match in plainKeyPattern.allMatches(optionsRaw)) {
      final key = match.group(1)?.trim();
      final value = match.group(3)?.trim();
      if (key != null && key.isNotEmpty && value != null) {
        options[key] = value;
      }
    }

    final quotedKeyPattern = RegExp(
      r'''(["'])([A-Za-z_][A-Za-z0-9_]*)\1\s*:\s*(["'])([\s\S]*?)\3''',
      multiLine: true,
    );
    for (final match in quotedKeyPattern.allMatches(optionsRaw)) {
      final key = match.group(2)?.trim();
      final value = match.group(4)?.trim();
      if (key != null && key.isNotEmpty && value != null) {
        options[key] = value;
      }
    }

    return options;
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
    final luaEnabled = settings.live2dLuaExecutionEnabled;
    if (settings.runRegexBeforeLua) {
      output = await _regexPipeline.applyUserInput(
        output,
        characterId: characterId,
        sessionId: sessionId,
      );
      if (luaEnabled) {
        output = await _luaScriptingService.onUserMessage(
          output,
          LuaHookContext(
            characterId: characterId,
            characterName: characterName,
            userName: userName,
          ),
        );
      }
    } else {
      if (luaEnabled) {
        output = await _luaScriptingService.onUserMessage(
          output,
          LuaHookContext(
            characterId: characterId,
            characterName: characterName,
            userName: userName,
          ),
        );
      }
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
    final luaEnabled = settings.live2dLuaExecutionEnabled;
    if (settings.runRegexBeforeLua) {
      output = await _regexPipeline.applyAiOutput(
        output,
        characterId: characterId,
        sessionId: sessionId,
      );
      if (luaEnabled) {
        output = await _luaScriptingService.onAssistantMessage(
          output,
          LuaHookContext(
            characterId: characterId,
            characterName: characterName,
            userName: userName,
          ),
        );
      }
    } else {
      if (luaEnabled) {
        output = await _luaScriptingService.onAssistantMessage(
          output,
          LuaHookContext(
            characterId: characterId,
            characterName: characterName,
            userName: userName,
          ),
        );
      }
      output = await _regexPipeline.applyAiOutput(
        output,
        characterId: characterId,
        sessionId: sessionId,
      );
    }

    final directiveResult = await _directiveService.processAssistantOutput(
      output,
      parsingEnabled: settings.live2dLlmIntegrationEnabled &&
          settings.live2dDirectiveParsingEnabled,
    );
    output = directiveResult.cleanedText;

    if (settings.runRegexBeforeLua) {
      output = await _regexPipeline.applyDisplayOnly(
        output,
        characterId: characterId,
        sessionId: sessionId,
      );
      if (luaEnabled) {
        output = await _luaScriptingService.onDisplayRender(
          output,
          LuaHookContext(
            characterId: characterId,
            characterName: characterName,
            userName: userName,
          ),
        );
      }
    } else {
      if (luaEnabled) {
        output = await _luaScriptingService.onDisplayRender(
          output,
          LuaHookContext(
            characterId: characterId,
            characterName: characterName,
            userName: userName,
          ),
        );
      }
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
    required List<ImageAttachment> currentImages,
    required ApiConfig? apiConfig,
    required String? promptPresetId,
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
      presetId: promptPresetId,
    );

    if (currentInput.trim().isNotEmpty || currentImages.isNotEmpty) {
      final hydratedImages = <ImageAttachment>[];
      for (final image in currentImages) {
        if (image.base64Data.isNotEmpty) {
          hydratedImages.add(image);
          continue;
        }
        final filePath = image.thumbnailPath;
        if (filePath != null && filePath.isNotEmpty) {
          final base64 = await ImageCacheManager.instance.loadBase64(filePath);
          if (base64 != null && base64.isNotEmpty) {
            hydratedImages.add(image.copyWith(base64Data: base64));
            continue;
          }
        }
        hydratedImages.add(image);
      }

      final dynamic userContent = hydratedImages.isEmpty
          ? currentInput
          : _promptBuilder.buildMultimodalContent(currentInput, hydratedImages);
      formattedMessages.add({'role': 'user', 'content': userContent});
    }

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
  }

  @override
  void onGlobalEnabled() {
    _syncNotificationState();
  }

  void cancelProactiveInFlight() {
    if (_activeOrigin == NotificationRequestOrigin.proactive) {
      _activeRequest?.cancel();
      _activeRequest = null;
      _activeOrigin = null;
    }
  }

  void cancelAgentInFlight() {
    if (_activeOrigin == NotificationRequestOrigin.agent) {
      _activeRequest?.cancel();
      _activeRequest = null;
      _activeOrigin = null;
    }
  }

  String? get activeSessionId => _sessionProvider?.activeSessionId;
}

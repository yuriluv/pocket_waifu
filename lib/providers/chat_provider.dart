import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../models/api_config.dart';
import '../models/character.dart';
import '../models/message.dart';
import '../models/settings.dart';
import '../features/live2d/data/services/live2d_native_bridge.dart';
import '../features/live2d_llm/services/live2d_directive_service.dart';
import '../features/lua/services/lua_scripting_service.dart';
import '../features/regex/services/regex_pipeline_service.dart';
import '../services/api_service.dart';
import '../services/global_runtime_registry.dart';
import '../services/prompt_builder.dart';
import 'chat_session_provider.dart';

/// Manages chat request state and delegates message persistence to
/// [ChatSessionProvider].
class ChatProvider extends ChangeNotifier {
  final ApiService _apiService = ApiService();
  final PromptBuilder _promptBuilder = PromptBuilder();
  final Uuid _uuid = const Uuid();
  final RegexPipelineService _regexPipeline = RegexPipelineService.instance;
  final LuaScriptingService _luaScriptingService = LuaScriptingService.instance;
  final Live2DDirectiveService _directiveService =
      Live2DDirectiveService.instance;
  final Live2DNativeBridge _live2dBridge = Live2DNativeBridge();

  ChatSessionProvider? _sessionProvider;

  bool _isLoading = false;
  String? _errorMessage;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String? get currentChatId => _sessionProvider?.activeSessionId;
  List<Message> get messages => _sessionProvider?.currentMessages ?? [];

  void setSessionProvider(ChatSessionProvider provider) {
    _sessionProvider = provider;
    debugPrint('ChatProvider connected to ChatSessionProvider');
  }

  List<Message> getMessagesFor(String sessionId) {
    return _sessionProvider?.getMessagesForSession(sessionId) ?? [];
  }

  void initializeChat({
    required Character character,
    required String userName,
    String? targetSessionId,
  }) {
    final sessionId = _resolveSessionId(targetSessionId: targetSessionId);
    if (sessionId == null) return;

    final firstMessage = _promptBuilder.getFirstMessage(
      character: character,
      userName: userName,
    );

    _sessionProvider!.clearSession(sessionId);
    _sessionProvider!.addMessageToSession(
      sessionId,
      _createMessage(
        sessionId: sessionId,
        role: MessageRole.assistant,
        content: firstMessage,
      ),
    );

    _errorMessage = null;
    notifyListeners();
  }

  Future<void> sendMessage({
    required String userMessage,
    required Character character,
    required AppSettings settings,
    required String userName,
    List<ImageAttachment> images = const [],
    ApiConfig? apiConfig,
    String? targetSessionId,
  }) async {
    if ((userMessage.trim().isEmpty && images.isEmpty) || _isLoading) return;

    final sessionProvider = _sessionProvider;
    if (sessionProvider == null) {
      _setError('SessionProvider is not connected.');
      return;
    }

    final sessionId = targetSessionId ?? sessionProvider.activeSessionId;
    if (sessionId == null) {
      _setError('No active session found.');
      return;
    }

    final trimmedInput = userMessage.trim();
    final preparedInput = trimmedInput.isEmpty
        ? ''
        : await _prepareUserInput(
            trimmedInput,
            settings: settings,
            sessionId: sessionId,
            characterId: character.id,
            characterName: character.name,
            userName: userName,
          );

    await sessionProvider.runSerialized(() async {
      _errorMessage = null;
      sessionProvider.addMessageToSession(
        sessionId,
        _createMessage(
          sessionId: sessionId,
          role: MessageRole.user,
          content: preparedInput,
          images: images,
        ),
      );
      notifyListeners();

      _setLoading(true);
      _directiveService.resetStreamBuffer();

      final requestHandle = _apiService.createRequestHandle();
      final cancelListener = GlobalRuntimeRegistry.instance.registerCancelable(
        requestHandle.cancel,
      );

      try {
        final response = await _requestAssistantResponse(
          sessionId: sessionId,
          character: character,
          settings: settings,
          userName: userName,
          apiConfig: apiConfig,
          requestHandle: requestHandle,
        );

        final processedResponse = await _prepareAssistantOutput(
          response,
          settings: settings,
          sessionId: sessionId,
          characterId: character.id,
          characterName: character.name,
          userName: userName,
        );

        sessionProvider.addMessageToSession(
          sessionId,
          _createMessage(
            sessionId: sessionId,
            role: MessageRole.assistant,
            content: processedResponse,
          ),
        );
      } catch (e) {
        if (e is ApiCancelledException) {
          debugPrint('sendMessage cancelled');
        } else {
          _errorMessage = e.toString().replaceFirst('Exception: ', '');
          debugPrint('sendMessage failed: $e');
        }
      } finally {
        GlobalRuntimeRegistry.instance.unregister(cancelListener);
        _setLoading(false);
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

  Future<String> _requestAssistantResponse({
    required String sessionId,
    required Character character,
    required AppSettings settings,
    required String userName,
    required ApiConfig? apiConfig,
    ApiRequestHandle? requestHandle,
  }) async {
    final sessionProvider = _sessionProvider!;
    final chatHistory = sessionProvider.getMessagesForSession(sessionId);

    var apiMessages = _promptBuilder.buildMessages(
      character: character,
      settings: settings,
      chatHistory: chatHistory,
      userName: userName,
    );

    apiMessages = await _injectLive2DCapabilities(apiMessages, settings);

    if (apiConfig == null) {
      return _apiService.sendMessage(
        messages: apiMessages,
        settings: settings,
        requestHandle: requestHandle,
      );
    }

    final formattedMessages = apiMessages.map(_messageToApiPayload).toList();

    return _apiService.sendMessageWithConfig(
      apiConfig: apiConfig,
      messages: formattedMessages,
      settings: settings,
      requestHandle: requestHandle,
    );
  }

  Future<List<Message>> _injectLive2DCapabilities(
    List<Message> messages,
    AppSettings settings,
  ) async {
    if (!settings.live2dPromptInjectionEnabled) {
      return messages;
    }

    final modelInfo = await _live2dBridge.getModelInfo();
    final params = (modelInfo['parameters'] as List<dynamic>? ?? const [])
        .map((item) => item.toString())
        .toList();
    final expressions = (modelInfo['expressions'] as List<dynamic>? ?? const [])
        .map((item) => item.toString())
        .toList();

    final motions = <String>[];
    final motionGroups = await _live2dBridge.getMotionGroups();
    for (final group in motionGroups) {
      final names = await _live2dBridge.getMotionNames(group);
      if (names.isEmpty) {
        final count = await _live2dBridge.getMotionCount(group);
        for (var i = 0; i < count; i++) {
          motions.add('$group[$i]');
        }
      } else {
        for (var i = 0; i < names.length; i++) {
          motions.add('$group[$i]:${names[i]}');
        }
      }
    }

    final capability = [
      '[Live2D Capability]',
      'Parameters: ${params.isEmpty ? '(none)' : params.join(', ')}',
      'Motions: ${motions.isEmpty ? '(none)' : motions.join(', ')}',
      'Expressions: ${expressions.isEmpty ? '(none)' : expressions.join(', ')}',
      'Use <live2d> blocks only for visible animation cues.',
    ].join('\n');

    final index = messages.indexWhere(
      (message) => message.role == MessageRole.system,
    );
    if (index == -1) {
      return [
        Message(role: MessageRole.system, content: capability),
        ...messages,
      ];
    }

    final system = messages[index];
    final updated = List<Message>.from(messages);
    updated[index] = system.copyWith(
      content: '${system.content}\n\n$capability',
    );
    return updated;
  }

  void deleteMessage(String messageId, {String? targetSessionId}) {
    final sessionId = _resolveSessionId(targetSessionId: targetSessionId);
    if (sessionId == null) return;

    _sessionProvider!.deleteMessageFromSession(sessionId, messageId);
    notifyListeners();
  }

  void deleteLastMessage({String? targetSessionId}) {
    final sessionId = _resolveSessionId(targetSessionId: targetSessionId);
    if (sessionId == null) return;

    _sessionProvider!.deleteLastMessageFromSession(sessionId);
    notifyListeners();
  }

  Future<void> regenerateLastResponse({
    required Character character,
    required AppSettings settings,
    required String userName,
    ApiConfig? apiConfig,
    String? targetSessionId,
  }) async {
    final sessionId = _resolveSessionId(targetSessionId: targetSessionId);
    if (sessionId == null) return;

    final currentMessages = getMessagesFor(sessionId);
    if (currentMessages.isNotEmpty &&
        currentMessages.last.role == MessageRole.assistant) {
      deleteLastMessage(targetSessionId: sessionId);
    }

    final lastUserMessage = _findLastUserMessage(getMessagesFor(sessionId));
    if (lastUserMessage == null) return;

    deleteMessage(lastUserMessage.id, targetSessionId: sessionId);
    await sendMessage(
      userMessage: lastUserMessage.content,
      character: character,
      settings: settings,
      userName: userName,
      images: lastUserMessage.images,
      apiConfig: apiConfig,
      targetSessionId: sessionId,
    );
  }

  void clearMessages({String? targetSessionId}) {
    final sessionId = _resolveSessionId(targetSessionId: targetSessionId);
    if (sessionId != null) {
      _sessionProvider!.clearSession(sessionId);
    }

    _errorMessage = null;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  void editMessage(
    String messageId,
    String newContent, {
    String? targetSessionId,
  }) {
    final sessionId = _resolveSessionId(targetSessionId: targetSessionId);
    if (sessionId == null) return;

    _sessionProvider!.editMessageInSession(sessionId, messageId, newContent);
    notifyListeners();
  }

  void addMessageWithoutApi(Message message, {String? targetSessionId}) {
    final sessionId = _resolveSessionId(targetSessionId: targetSessionId);
    if (sessionId == null) return;

    final messageWithId = message.id.isEmpty
        ? message.copyWith(id: _uuid.v4(), chatId: sessionId)
        : message.copyWith(chatId: sessionId);

    _sessionProvider!.addMessageToSession(sessionId, messageWithId);
    notifyListeners();
  }

  Message? _findLastUserMessage(List<Message> messages) {
    for (var i = messages.length - 1; i >= 0; i--) {
      if (messages[i].role == MessageRole.user) {
        return messages[i];
      }
    }
    return null;
  }

  Message _createMessage({
    required String sessionId,
    required MessageRole role,
    required String content,
    List<ImageAttachment> images = const [],
  }) {
    return Message(
      id: _uuid.v4(),
      chatId: sessionId,
      role: role,
      content: content,
      images: images,
    );
  }

  Map<String, dynamic> _messageToApiPayload(Message msg) {
    if (msg.images.isEmpty) {
      return {'role': msg.roleString, 'content': msg.content};
    }

    return {
      'role': msg.roleString,
      'content': _promptBuilder.buildMultimodalContent(msg.content, msg.images),
    };
  }

  String? _resolveSessionId({String? targetSessionId}) {
    final sessionProvider = _sessionProvider;
    if (sessionProvider == null) {
      debugPrint('ChatProvider is missing ChatSessionProvider');
      return null;
    }

    final sessionId = targetSessionId ?? sessionProvider.activeSessionId;
    if (sessionId == null) {
      debugPrint('No active session available');
      return null;
    }

    return sessionId;
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setError(String message) {
    _errorMessage = message;
    notifyListeners();
  }

  @override
  void dispose() {
    _luaScriptingService.onUnload(const LuaHookContext());
    super.dispose();
  }
}

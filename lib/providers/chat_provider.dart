import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../models/api_config.dart';
import '../models/character.dart';
import '../models/message.dart';
import '../models/settings.dart';
import '../features/image_overlay/services/image_overlay_directive_service.dart';
import '../features/live2d_llm/services/live2d_directive_service.dart';
import '../features/lua/services/lua_scripting_service.dart';
import '../features/regex/services/regex_pipeline_service.dart';
import '../services/api_service.dart';
import '../services/global_runtime_registry.dart';
import '../services/image_cache_manager.dart';
import '../services/prompt_builder.dart';
import 'chat_session_provider.dart';
import 'prompt_block_provider.dart';

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
  final ImageOverlayDirectiveService _imageDirectiveService =
      ImageOverlayDirectiveService.instance;

  ChatSessionProvider? _sessionProvider;
  PromptBlockProvider? _promptBlockProvider;

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

  void setPromptBlockProvider(PromptBlockProvider provider) {
    _promptBlockProvider = provider;
    debugPrint('ChatProvider connected to PromptBlockProvider');
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
          settings: settings,
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

    if (settings.live2dLlmIntegrationEnabled &&
        settings.live2dDirectiveParsingEnabled) {
      if (settings.llmDirectiveTarget == LlmDirectiveTarget.live2d) {
        final directiveResult = await _directiveService.processAssistantOutput(
          output,
          parsingEnabled: true,
          exposeRawDirectives: settings.live2dShowRawDirectivesInChat,
        );
        output = directiveResult.cleanedText;
      } else {
        final directiveResult = await _imageDirectiveService
            .processAssistantOutput(output);
        output = directiveResult.cleanedText;
      }
    }

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

  Future<String> _requestAssistantResponse({
    required String sessionId,
    required AppSettings settings,
    required ApiConfig? apiConfig,
    ApiRequestHandle? requestHandle,
  }) async {
    final sessionProvider = _sessionProvider!;
    final chatHistory = sessionProvider.getMessagesForSession(sessionId);
    final promptProvider = _promptBlockProvider;
    if (promptProvider == null) {
      throw Exception('PromptBlockProvider is not connected.');
    }

    final latestUserMessage = _findLastUserMessage(chatHistory);
    final currentInput = latestUserMessage?.content ?? '';
    final promptHistory = List<Message>.from(chatHistory);
    if (latestUserMessage != null &&
        promptHistory.isNotEmpty &&
        promptHistory.last.id == latestUserMessage.id) {
      promptHistory.removeLast();
    }

    final effectivePresetId = promptProvider.activePresetId;

    if (apiConfig == null) {
      final blocks =
          promptProvider.activePreset?.blocks ?? promptProvider.blocks;
      if (blocks.isEmpty) {
        throw Exception('프롬프트 블록 프리셋이 비어 있습니다.');
      }

      if (latestUserMessage == null || latestUserMessage.images.isEmpty) {
        return _apiService.sendMessageWithBlocks(
          apiConfig: null,
          blocks: blocks,
          pastMessages: promptHistory,
          currentInput: currentInput,
          settings: settings,
          requestHandle: requestHandle,
        );
      }

      final promptMessages = promptProvider.buildMessagesForApi(
        promptHistory,
        currentInput,
        hasFirstSystemPrompt: true,
        requiresAlternateRole: false,
        presetId: effectivePresetId,
      );
      if (promptMessages.isEmpty) {
        throw Exception('프롬프트 블록 프리셋이 비어 있습니다.');
      }

      final legacyMessages = <Message>[];
      for (final payload in promptMessages) {
        final role = _parseRole(payload['role']?.toString());
        final content = payload['content'];
        if (role == null || content is! String || content.trim().isEmpty) {
          continue;
        }
        legacyMessages.add(Message(role: role, content: content));
      }
      legacyMessages.add(
        Message(
          role: MessageRole.user,
          content: currentInput,
          images: latestUserMessage.images,
        ),
      );
      return _apiService.sendMessage(
        messages: legacyMessages,
        settings: settings,
        requestHandle: requestHandle,
      );
    }

    final formattedMessages = promptProvider.buildMessagesForApi(
      promptHistory,
      currentInput,
      hasFirstSystemPrompt: apiConfig.hasFirstSystemPrompt,
      requiresAlternateRole: apiConfig.requiresAlternateRole,
      presetId: effectivePresetId,
    );
    if (formattedMessages.isEmpty) {
      throw Exception('프롬프트 블록 프리셋이 비어 있습니다.');
    }

    if (latestUserMessage != null && latestUserMessage.images.isNotEmpty) {
      final payload = await _messageToApiPayload(
        Message(
          role: MessageRole.user,
          content: currentInput,
          images: latestUserMessage.images,
        ),
      );
      formattedMessages.add(payload);
    }

    return _apiService.sendMessageWithConfig(
      apiConfig: apiConfig,
      messages: formattedMessages,
      settings: settings,
      requestHandle: requestHandle,
    );
  }

  MessageRole? _parseRole(String? raw) {
    return switch (raw) {
      'system' => MessageRole.system,
      'user' => MessageRole.user,
      'assistant' => MessageRole.assistant,
      _ => null,
    };
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

  void removeImageFromMessage(
    String messageId,
    String imageId, {
    String? targetSessionId,
  }) {
    final sessionId = _resolveSessionId(targetSessionId: targetSessionId);
    if (sessionId == null) return;

    _sessionProvider!.removeImageFromMessageInSession(
      sessionId,
      messageId,
      imageId,
    );
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

  Future<Map<String, dynamic>> _messageToApiPayload(Message msg) async {
    if (msg.images.isEmpty) {
      return {'role': msg.roleString, 'content': msg.content};
    }

    final hydratedImages = <ImageAttachment>[];
    for (final image in msg.images) {
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

    return {
      'role': msg.roleString,
      'content': _promptBuilder.buildMultimodalContent(
        msg.content,
        hydratedImages,
      ),
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

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../models/api_config.dart';
import '../models/character.dart';
import '../models/message.dart';
import '../models/settings.dart';
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
    ApiConfig? apiConfig,
    String? targetSessionId,
  }) async {
    if (userMessage.trim().isEmpty || _isLoading) return;

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

    await sessionProvider.runSerialized(() async {
      _errorMessage = null;
      sessionProvider.addMessageToSession(
        sessionId,
        _createMessage(
          sessionId: sessionId,
          role: MessageRole.user,
          content: userMessage.trim(),
        ),
      );
      notifyListeners();

      _setLoading(true);

      final requestHandle = _apiService.createRequestHandle();
      final cancelListener =
          GlobalRuntimeRegistry.instance.registerCancelable(requestHandle.cancel);

      try {
        final response = await _requestAssistantResponse(
          sessionId: sessionId,
          character: character,
          settings: settings,
          userName: userName,
          apiConfig: apiConfig,
          requestHandle: requestHandle,
        );

        sessionProvider.addMessageToSession(
          sessionId,
          _createMessage(
            sessionId: sessionId,
            role: MessageRole.assistant,
            content: response,
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

    final apiMessages = _promptBuilder.buildMessages(
      character: character,
      settings: settings,
      chatHistory: chatHistory,
      userName: userName,
    );

    if (apiConfig == null) {
      return _apiService.sendMessage(
        messages: apiMessages,
        settings: settings,
        requestHandle: requestHandle,
      );
    }

    final formattedMessages = apiMessages
        .map((msg) => {'role': msg.roleString, 'content': msg.content})
        .toList();

    return _apiService.sendMessageWithConfig(
      apiConfig: apiConfig,
      messages: formattedMessages,
      settings: settings,
      requestHandle: requestHandle,
    );
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
  }) {
    return Message(
      id: _uuid.v4(),
      chatId: sessionId,
      role: role,
      content: content,
    );
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
}

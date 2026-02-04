// ============================================================================
// 채팅 Provider (Chat Provider) - v2.0.5
// ============================================================================
// API 호출 및 로딩/에러 상태만 관리합니다.
// 메시지 저장/로드는 ChatSessionProvider에 위임합니다.
// v2.0.5: 세션 ID 캡처 패턴 - API 호출 중 세션 전환해도 올바른 세션에 저장
// ============================================================================

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../models/api_config.dart';
import '../models/message.dart';
import '../models/character.dart';
import '../models/settings.dart';
import '../services/api_service.dart';
import '../services/prompt_builder.dart';
import 'chat_session_provider.dart';

/// 채팅 상태를 관리하는 Provider 클래스
/// v2.0.5: 세션 ID 캡처로 채팅 전환 중에도 올바른 세션에 메시지 저장
class ChatProvider extends ChangeNotifier {
  // === 서비스 인스턴스 ===
  final ApiService _apiService = ApiService();
  final PromptBuilder _promptBuilder = PromptBuilder();
  final Uuid _uuid = const Uuid();

  // === ChatSessionProvider 참조 ===
  ChatSessionProvider? _sessionProvider;

  // === 상태 변수 ===
  bool _isLoading = false;
  String? _errorMessage;

  // === Getter ===
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  /// 현재 활성 채팅 ID (UI 표시용)
  String? get currentChatId => _sessionProvider?.activeSessionId;

  /// 현재 활성 세션의 메시지 목록 (UI 표시용)
  List<Message> get messages => _sessionProvider?.currentMessages ?? [];

  /// ChatSessionProvider 연결
  void setSessionProvider(ChatSessionProvider provider) {
    _sessionProvider = provider;
    debugPrint('>>> v2.0.5: ChatProvider - SessionProvider 연결됨');
  }

  /// 특정 세션의 메시지 가져오기
  List<Message> getMessagesFor(String sessionId) {
    return _sessionProvider?.getMessagesForSession(sessionId) ?? [];
  }

  /// 대화를 초기화합니다 (캐릭터의 첫 인사말로 시작)
  /// [targetSessionId]: 초기화할 세션 ID (없으면 현재 활성 세션)
  void initializeChat({
    required Character character,
    required String userName,
    String? targetSessionId,
  }) {
    if (_sessionProvider == null) {
      debugPrint('>>> 경고: SessionProvider 없음, initializeChat 실패');
      return;
    }

    // 🔒 세션 ID 캡처
    final sessionId = targetSessionId ?? _sessionProvider!.activeSessionId;
    if (sessionId == null) {
      debugPrint('>>> 경고: 세션 ID 없음, initializeChat 실패');
      return;
    }

    // 첫 인사말 가져오기
    final String firstMessage = _promptBuilder.getFirstMessage(
      character: character,
      userName: userName,
    );

    // 세션 초기화
    _sessionProvider!.clearSession(sessionId);

    // 첫 인사말 추가
    final Message assistantMsg = Message(
      id: _uuid.v4(),
      chatId: sessionId,
      role: MessageRole.assistant,
      content: firstMessage,
    );
    _sessionProvider!.addMessageToSession(sessionId, assistantMsg);

    _errorMessage = null;
    notifyListeners();
  }

  /// 사용자 메시지를 보내고 AI 응답을 받습니다
  ///
  /// [targetSessionId]: 메시지를 저장할 세션 ID (없으면 현재 활성 세션)
  /// ⭐ 핵심: API 호출 시작 시점에 세션 ID를 캡처하여 응답까지 유지
  Future<void> sendMessage({
    required String userMessage,
    required Character character,
    required AppSettings settings,
    required String userName,
    ApiConfig? apiConfig,
    String? targetSessionId,
  }) async {
    // 빈 메시지는 무시
    if (userMessage.trim().isEmpty) return;

    // 이미 전송 중이면 무시
    if (_isLoading) return;

    // SessionProvider 확인
    if (_sessionProvider == null) {
      _errorMessage = 'SessionProvider가 연결되지 않았습니다.';
      notifyListeners();
      return;
    }

    // 🔒 세션 ID 캡처 (호출 시점에 고정)
    final sessionId = targetSessionId ?? _sessionProvider!.activeSessionId;
    if (sessionId == null) {
      _errorMessage = '활성 세션이 없습니다.';
      notifyListeners();
      return;
    }

    // 에러 메시지 초기화
    _errorMessage = null;

    debugPrint('╔════════════════════════════════════════════════════════════');
    debugPrint('║ >>> ChatProvider.sendMessage (v2.0.5)');
    debugPrint('║ >>> 🔒 캡처된 세션 ID: $sessionId');
    debugPrint('║ >>> API Config: ${apiConfig?.name ?? "레거시 모드"}');
    debugPrint('╚════════════════════════════════════════════════════════════');

    // === 1. 사용자 메시지 추가 (캡처된 세션 ID 사용) ===
    final Message userMsg = Message(
      id: _uuid.v4(),
      chatId: sessionId,
      role: MessageRole.user,
      content: userMessage.trim(),
    );
    _sessionProvider!.addMessageToSession(sessionId, userMsg);
    notifyListeners();

    // === 2. 로딩 상태 시작 ===
    _isLoading = true;
    notifyListeners();

    try {
      // === 3. API용 히스토리 가져오기 (캡처된 세션에서) ===
      final List<Message> chatHistory = _sessionProvider!.getMessagesForSession(
        sessionId,
      );

      final List<Message> apiMessages = _promptBuilder.buildMessages(
        character: character,
        settings: settings,
        chatHistory: chatHistory,
        userName: userName,
      );

      // === 4. API 호출 (시간 소요 - 세션 전환 가능) ===
      final String response;
      if (apiConfig != null) {
        final List<Map<String, String>> formattedMessages = apiMessages.map((
          msg,
        ) {
          return {'role': msg.roleString, 'content': msg.content};
        }).toList();

        debugPrint('>>> API 호출 - ${apiConfig.name} (${apiConfig.baseUrl})');

        response = await _apiService.sendMessageWithConfig(
          apiConfig: apiConfig,
          messages: formattedMessages,
          settings: settings,
        );
      } else {
        debugPrint('>>> 레거시 API 호출 (apiConfig 없음)');
        response = await _apiService.sendMessage(
          messages: apiMessages,
          settings: settings,
        );
      }

      // === 5. AI 응답 메시지 추가 (캡처된 세션 ID 사용!) ===
      final Message assistantMsg = Message(
        id: _uuid.v4(),
        chatId: sessionId, // 🔒 캡처된 ID 사용
        role: MessageRole.assistant,
        content: response,
      );
      _sessionProvider!.addMessageToSession(sessionId, assistantMsg);

      debugPrint('>>> v2.0.5: AI 응답이 세션 $sessionId에 저장됨');
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      debugPrint('메시지 전송 실패: $e');
    }

    // === 6. 로딩 상태 종료 ===
    _isLoading = false;
    notifyListeners();
  }

  /// 특정 메시지를 삭제합니다
  /// [targetSessionId]: 삭제할 세션 ID (없으면 현재 활성 세션)
  void deleteMessage(String messageId, {String? targetSessionId}) {
    final sessionId = targetSessionId ?? _sessionProvider?.activeSessionId;
    if (sessionId != null) {
      _sessionProvider?.deleteMessageFromSession(sessionId, messageId);
      notifyListeners();
    }
  }

  /// 마지막 메시지를 삭제합니다 (재생성 시 사용)
  void deleteLastMessage({String? targetSessionId}) {
    final sessionId = targetSessionId ?? _sessionProvider?.activeSessionId;
    if (sessionId != null) {
      _sessionProvider?.deleteLastMessageFromSession(sessionId);
      notifyListeners();
    }
  }

  /// 마지막 AI 응답을 재생성합니다
  Future<void> regenerateLastResponse({
    required Character character,
    required AppSettings settings,
    required String userName,
    ApiConfig? apiConfig,
    String? targetSessionId,
  }) async {
    // 🔒 세션 ID 캡처
    final sessionId = targetSessionId ?? _sessionProvider?.activeSessionId;
    if (sessionId == null) return;

    final currentMessages = getMessagesFor(sessionId);

    // 마지막 메시지가 AI 응답이면 삭제
    if (currentMessages.isNotEmpty &&
        currentMessages.last.role == MessageRole.assistant) {
      deleteLastMessage(targetSessionId: sessionId);
    }

    // 마지막 사용자 메시지 찾기
    final updatedMessages = getMessagesFor(sessionId);
    Message? lastUserMessage;
    for (int i = updatedMessages.length - 1; i >= 0; i--) {
      if (updatedMessages[i].role == MessageRole.user) {
        lastUserMessage = updatedMessages[i];
        break;
      }
    }

    // 사용자 메시지가 있으면 다시 전송
    if (lastUserMessage != null) {
      // 마지막 사용자 메시지 삭제
      deleteMessage(lastUserMessage.id, targetSessionId: sessionId);

      // 다시 전송 (캡처된 세션 ID 사용)
      await sendMessage(
        userMessage: lastUserMessage.content,
        character: character,
        settings: settings,
        userName: userName,
        apiConfig: apiConfig,
        targetSessionId: sessionId,
      );
    }
  }

  /// 모든 대화 내역을 삭제합니다
  void clearMessages({String? targetSessionId}) {
    final sessionId = targetSessionId ?? _sessionProvider?.activeSessionId;
    if (sessionId != null) {
      _sessionProvider?.clearSession(sessionId);
    }
    _errorMessage = null;
    notifyListeners();
  }

  /// 에러 메시지를 지웁니다
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  /// 메시지 내용을 수정합니다
  void editMessage(
    String messageId,
    String newContent, {
    String? targetSessionId,
  }) {
    final sessionId = targetSessionId ?? _sessionProvider?.activeSessionId;
    if (sessionId != null) {
      _sessionProvider?.editMessageInSession(sessionId, messageId, newContent);
      notifyListeners();
    }
  }

  /// API 호출 없이 메시지만 추가합니다 (/send 명령어용)
  void addMessageWithoutApi(Message message, {String? targetSessionId}) {
    final sessionId = targetSessionId ?? _sessionProvider?.activeSessionId;
    if (sessionId == null) return;

    final messageWithId = message.id.isEmpty
        ? message.copyWith(id: _uuid.v4(), chatId: sessionId)
        : message.copyWith(chatId: sessionId);
    _sessionProvider?.addMessageToSession(sessionId, messageWithId);
    notifyListeners();
  }
}

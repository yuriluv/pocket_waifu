// ============================================================================
// 채팅 Provider (Chat Provider)
// ============================================================================
// 이 파일은 채팅 대화 내역과 메시지 전송을 관리하는 Provider입니다.
// 메시지 목록, 전송 상태, AI 응답 처리 등을 담당합니다.
// ============================================================================

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../models/message.dart';
import '../models/character.dart';
import '../models/settings.dart';
import '../services/api_service.dart';
import '../services/prompt_builder.dart';

/// 채팅 상태를 관리하는 Provider 클래스
class ChatProvider extends ChangeNotifier {
  // === 저장 키 상수 ===
  static const String _messagesKey = 'chat_messages';

  // === 서비스 인스턴스 ===
  final ApiService _apiService = ApiService();        // API 서비스
  final PromptBuilder _promptBuilder = PromptBuilder();  // 프롬프트 빌더
  final Uuid _uuid = const Uuid();                    // UUID 생성기

  // === 상태 변수 ===
  List<Message> _messages = [];  // 채팅 메시지 목록
  bool _isLoading = false;       // 메시지 전송 중 여부
  String? _errorMessage;         // 에러 메시지 (있을 경우)
  bool _isInitialized = false;   // 초기화 완료 여부

  // === Getter ===
  List<Message> get messages => _messages;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isInitialized => _isInitialized;

  /// 생성자 - 저장된 대화 내역을 불러옵니다
  ChatProvider() {
    loadMessages();
  }

  /// 저장된 메시지를 불러옵니다
  Future<void> loadMessages() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? messagesJson = prefs.getString(_messagesKey);
      
      if (messagesJson != null) {
        final List<dynamic> messagesList = jsonDecode(messagesJson);
        _messages = messagesList
            .map((json) => Message.fromMap(json))
            .toList();
      }
    } catch (e) {
      debugPrint('메시지 불러오기 실패: $e');
    }

    _isInitialized = true;
    notifyListeners();
  }

  /// 메시지를 저장합니다
  Future<void> saveMessages() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String messagesJson = jsonEncode(
        _messages.map((msg) => msg.toMap()).toList(),
      );
      await prefs.setString(_messagesKey, messagesJson);
    } catch (e) {
      debugPrint('메시지 저장 실패: $e');
    }
  }

  /// 대화를 초기화합니다 (캐릭터의 첫 인사말로 시작)
  void initializeChat({
    required Character character,
    required String userName,
  }) {
    // 첫 인사말 가져오기
    final String firstMessage = _promptBuilder.getFirstMessage(
      character: character,
      userName: userName,
    );

    // 메시지 목록 초기화하고 첫 인사말 추가
    _messages = [
      Message(
        id: _uuid.v4(),
        role: MessageRole.assistant,
        content: firstMessage,
      ),
    ];

    _errorMessage = null;
    notifyListeners();
    saveMessages();
  }

  /// 사용자 메시지를 보내고 AI 응답을 받습니다
  /// 
  /// [userMessage]: 사용자가 입력한 메시지
  /// [character]: 현재 캐릭터
  /// [settings]: 앱 설정
  /// [userName]: 사용자 이름
  Future<void> sendMessage({
    required String userMessage,
    required Character character,
    required AppSettings settings,
    required String userName,
  }) async {
    // 빈 메시지는 무시
    if (userMessage.trim().isEmpty) return;

    // 이미 전송 중이면 무시
    if (_isLoading) return;

    // 에러 메시지 초기화
    _errorMessage = null;

    // === 1. 사용자 메시지 추가 ===
    final Message userMsg = Message(
      id: _uuid.v4(),
      role: MessageRole.user,
      content: userMessage.trim(),
    );
    _messages.add(userMsg);
    notifyListeners();

    // === 2. 로딩 상태 시작 ===
    _isLoading = true;
    notifyListeners();

    try {
      // === 3. API에 보낼 메시지 목록 구성 ===
      // 프롬프트 빌더를 사용해 시스템 프롬프트 + 대화 내역 조합
      final List<Message> apiMessages = _promptBuilder.buildMessages(
        character: character,
        settings: settings,
        chatHistory: _messages,
        userName: userName,
      );

      // === 4. API 호출 ===
      final String response = await _apiService.sendMessage(
        messages: apiMessages,
        settings: settings,
      );

      // === 5. AI 응답 메시지 추가 ===
      final Message assistantMsg = Message(
        id: _uuid.v4(),
        role: MessageRole.assistant,
        content: response,
      );
      _messages.add(assistantMsg);
      
      // 메시지 저장
      await saveMessages();
    } catch (e) {
      // 에러 발생 시 에러 메시지 저장
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      debugPrint('메시지 전송 실패: $e');
    }

    // === 6. 로딩 상태 종료 ===
    _isLoading = false;
    notifyListeners();
  }

  /// 특정 메시지를 삭제합니다
  void deleteMessage(String messageId) {
    _messages.removeWhere((msg) => msg.id == messageId);
    notifyListeners();
    saveMessages();
  }

  /// 마지막 메시지를 삭제합니다 (재생성 시 사용)
  void deleteLastMessage() {
    if (_messages.isNotEmpty) {
      _messages.removeLast();
      notifyListeners();
      saveMessages();
    }
  }

  /// 마지막 AI 응답을 재생성합니다
  Future<void> regenerateLastResponse({
    required Character character,
    required AppSettings settings,
    required String userName,
  }) async {
    // 마지막 메시지가 AI 응답이면 삭제
    if (_messages.isNotEmpty && _messages.last.role == MessageRole.assistant) {
      deleteLastMessage();
    }

    // 마지막 사용자 메시지 찾기
    Message? lastUserMessage;
    for (int i = _messages.length - 1; i >= 0; i--) {
      if (_messages[i].role == MessageRole.user) {
        lastUserMessage = _messages[i];
        break;
      }
    }

    // 사용자 메시지가 있으면 다시 전송
    if (lastUserMessage != null) {
      // 마지막 사용자 메시지 삭제 (sendMessage에서 다시 추가됨)
      deleteMessage(lastUserMessage.id);
      
      // 다시 전송
      await sendMessage(
        userMessage: lastUserMessage.content,
        character: character,
        settings: settings,
        userName: userName,
      );
    }
  }

  /// 모든 대화 내역을 삭제합니다
  void clearMessages() {
    _messages.clear();
    _errorMessage = null;
    notifyListeners();
    saveMessages();
  }

  /// 에러 메시지를 지웁니다
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  /// 메시지 내용을 수정합니다
  void editMessage(String messageId, String newContent) {
    final int index = _messages.indexWhere((msg) => msg.id == messageId);
    if (index != -1) {
      _messages[index] = _messages[index].copyWith(content: newContent);
      notifyListeners();
      saveMessages();
    }
  }

  /// API 호출 없이 메시지만 추가합니다 (v1.5 - /send 명령어용)
  void addMessageWithoutApi(Message message) {
    final messageWithId = message.id.isEmpty 
        ? message.copyWith(id: _uuid.v4())
        : message;
    _messages.add(messageWithId);
    notifyListeners();
    saveMessages();
  }
}

// ============================================================================
// 채팅 세션 Provider (Chat Session Provider)
// ============================================================================
// 멀티 채팅 세션을 관리하는 Provider입니다.
// 여러 대화를 동시에 유지하고, 세션 간 전환을 지원합니다.
// ============================================================================

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../models/chat_session.dart';
import '../models/message.dart';

/// 채팅 세션 상태를 관리하는 Provider
class ChatSessionProvider extends ChangeNotifier {
  // === 저장 키 상수 ===
  static const String _sessionsKey = 'chat_sessions';
  static const String _activeSessionIdKey = 'active_session_id';

  // === 상태 변수 ===
  List<ChatSession> _sessions = [];     // 모든 채팅 세션 목록
  String? _activeSessionId;             // 현재 활성 세션 ID
  bool _isLoading = false;              // 로딩 상태
  final Uuid _uuid = const Uuid();      // UUID 생성기

  // === Getter ===
  List<ChatSession> get sessions => List.unmodifiable(_sessions);
  String? get activeSessionId => _activeSessionId;
  bool get isLoading => _isLoading;

  /// 현재 활성 세션 가져오기
  ChatSession? get activeSession {
    if (_activeSessionId == null) return null;
    try {
      return _sessions.firstWhere((s) => s.id == _activeSessionId);
    } catch (e) {
      return null;
    }
  }

  /// 현재 활성 세션의 메시지 목록
  List<Message> get currentMessages => activeSession?.messages ?? [];

  /// 생성자 - 저장된 세션을 불러옵니다
  ChatSessionProvider() {
    loadAllSessions();
  }

  /// 저장된 모든 세션을 불러옵니다
  Future<void> loadAllSessions() async {
    _isLoading = true;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();

      // 세션 목록 불러오기
      final String? sessionsJson = prefs.getString(_sessionsKey);
      if (sessionsJson != null) {
        final List<dynamic> sessionsList = jsonDecode(sessionsJson);
        _sessions = sessionsList
            .map((json) => ChatSession.fromMap(json))
            .toList();
      }

      // 활성 세션 ID 불러오기
      _activeSessionId = prefs.getString(_activeSessionIdKey);

      // 세션이 없거나 활성 세션이 유효하지 않으면 새 세션 생성
      if (_sessions.isEmpty) {
        createNewSession();
      } else if (_activeSessionId == null || 
                 !_sessions.any((s) => s.id == _activeSessionId)) {
        _activeSessionId = _sessions.first.id;
      }
    } catch (e) {
      debugPrint('세션 불러오기 실패: $e');
      createNewSession();
    }

    _isLoading = false;
    notifyListeners();
  }

  /// 모든 세션을 저장합니다
  Future<void> saveAllSessions() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // 세션 목록 저장
      final String sessionsJson = jsonEncode(
        _sessions.map((session) => session.toMap()).toList(),
      );
      await prefs.setString(_sessionsKey, sessionsJson);

      // 활성 세션 ID 저장
      if (_activeSessionId != null) {
        await prefs.setString(_activeSessionIdKey, _activeSessionId!);
      }
    } catch (e) {
      debugPrint('세션 저장 실패: $e');
    }
  }

  /// 새 채팅 세션을 생성합니다
  void createNewSession({String? name}) {
    final newSession = ChatSession(
      id: _uuid.v4(),
      name: name ?? '새 채팅 ${_sessions.length + 1}',
    );

    _sessions.insert(0, newSession);  // 최신 세션을 맨 앞에
    _activeSessionId = newSession.id;
    
    notifyListeners();
    saveAllSessions();
  }

  /// 세션을 전환합니다
  void switchSession(String id) {
    if (_sessions.any((s) => s.id == id)) {
      _activeSessionId = id;
      notifyListeners();
      saveAllSessions();
    }
  }

  /// 세션 이름을 변경합니다
  void renameSession(String id, String newName) {
    final index = _sessions.indexWhere((s) => s.id == id);
    if (index != -1) {
      _sessions[index].name = newName;
      _sessions[index].lastModifiedAt = DateTime.now();
      notifyListeners();
      saveAllSessions();
    }
  }

  /// 세션을 삭제합니다
  bool deleteSession(String id) {
    // 마지막 남은 세션은 삭제 불가
    if (_sessions.length <= 1) {
      debugPrint('마지막 세션은 삭제할 수 없습니다.');
      return false;
    }

    final index = _sessions.indexWhere((s) => s.id == id);
    if (index != -1) {
      _sessions.removeAt(index);

      // 삭제된 세션이 활성 세션이었다면 다른 세션으로 전환
      if (_activeSessionId == id) {
        _activeSessionId = _sessions.first.id;
      }

      notifyListeners();
      saveAllSessions();
      return true;
    }
    return false;
  }

  /// 현재 세션에 메시지 추가
  void addMessage(Message message) {
    final session = activeSession;
    if (session != null) {
      session.addMessage(message);
      notifyListeners();
      saveAllSessions();
    }
  }

  /// 현재 세션의 특정 인덱스 메시지 삭제 (0-based)
  void deleteMessageAt(int index) {
    final session = activeSession;
    if (session != null) {
      session.deleteMessageAt(index);  // 이미 0-based
      notifyListeners();
      saveAllSessions();
    }
  }

  /// 현재 세션의 메시지 ID로 삭제
  void deleteMessageById(String messageId) {
    final session = activeSession;
    if (session != null) {
      session.deleteMessageById(messageId);
      notifyListeners();
      saveAllSessions();
    }
  }

  /// 현재 세션의 범위 내 메시지 삭제 (1-based)
  void deleteMessagesInRange(int start, int end) {
    final session = activeSession;
    if (session != null) {
      session.deleteMessagesInRange(start, end);
      notifyListeners();
      saveAllSessions();
    }
  }

  /// 현재 세션의 특정 메시지 수정 (0-based)
  void editMessageAt(int index, String newContent) {
    final session = activeSession;
    if (session != null) {
      session.editMessageAt(index, newContent);  // 이미 0-based
      notifyListeners();
      saveAllSessions();
    }
  }

  /// 현재 세션의 모든 메시지 삭제
  void clearCurrentSession() {
    final session = activeSession;
    if (session != null) {
      session.clearMessages();
      notifyListeners();
      saveAllSessions();
    }
  }

  /// 현재 세션의 모든 메시지 삭제 (alias)
  void clearMessages() => clearCurrentSession();

  /// 현재 세션을 JSON으로 내보내기
  String exportCurrentSession() {
    final session = activeSession;
    if (session != null) {
      return const JsonEncoder.withIndent('  ').convert(session.toMap());
    }
    return '{}';
  }

  /// 특정 세션을 JSON으로 내보내기
  String exportSession(String id) {
    try {
      final session = _sessions.firstWhere((s) => s.id == id);
      return const JsonEncoder.withIndent('  ').convert(session.toMap());
    } catch (e) {
      return '{}';
    }
  }

  /// 특정 인덱스의 메시지 가져오기 (1-based)
  Message? getMessageAt(int index) {
    final session = activeSession;
    if (session != null && index >= 1 && index <= session.messages.length) {
      return session.messages[index - 1];
    }
    return null;
  }

  /// 마지막 메시지 삭제
  void deleteLastMessage() {
    final session = activeSession;
    if (session != null && session.messages.isNotEmpty) {
      session.messages.removeLast();
      session.lastModifiedAt = DateTime.now();
      notifyListeners();
      saveAllSessions();
    }
  }

  /// 세션 목록을 최근 수정 순으로 정렬
  void sortSessionsByLastModified() {
    _sessions.sort((a, b) => b.lastModifiedAt.compareTo(a.lastModifiedAt));
    notifyListeners();
  }

  /// 모든 세션 삭제 및 초기화
  void resetAllSessions() {
    _sessions.clear();
    _activeSessionId = null;
    createNewSession();
  }
}

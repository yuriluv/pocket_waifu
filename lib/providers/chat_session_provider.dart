// ============================================================================
// ============================================================================
// ============================================================================

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../models/chat_session.dart';
import '../models/chat_variable_scope.dart';
import '../models/message.dart';
import '../models/session_interaction_state.dart';
import '../models/session_variable_store.dart';
import '../services/image_cache_manager.dart';

class ChatSessionProvider extends ChangeNotifier {
  static const String _sessionsKey = 'chat_sessions';
  static const String _activeSessionIdKey = 'active_session_id';

  List<ChatSession> _sessions = [];
  String? _activeSessionId;
  bool _isLoading = false;
  final Uuid _uuid = const Uuid();
  Future<void> _sessionQueue = Future.value();
  Future<void> _saveQueue = Future.value();

  // === Getter ===
  List<ChatSession> get sessions => List.unmodifiable(_sessions);
  String? get activeSessionId => _activeSessionId;
  bool get isLoading => _isLoading;

  ChatSession? get activeSession {
    if (_activeSessionId == null) return null;
    try {
      return _sessions.firstWhere((s) => s.id == _activeSessionId);
    } catch (e) {
      return null;
    }
  }

  List<Message> get currentMessages => activeSession?.messages ?? [];

  ChatSessionProvider() {
    loadAllSessions();
  }

  Future<T> runSerialized<T>(Future<T> Function() action) {
    final completer = Completer<T>();
    _sessionQueue = _sessionQueue.then((_) async {
      try {
        final result = await action();
        completer.complete(result);
      } catch (e, stack) {
        completer.completeError(e, stack);
      }
    });
    return completer.future;
  }

  Future<void> loadAllSessions() async {
    _isLoading = true;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();

      final String? sessionsJson = prefs.getString(_sessionsKey);
      if (sessionsJson != null) {
        final List<dynamic> sessionsList = jsonDecode(sessionsJson);
        _sessions = sessionsList
            .map((json) => ChatSession.fromMap(json))
            .toList();
      }

      _activeSessionId = prefs.getString(_activeSessionIdKey);

      if (_sessions.isEmpty) {
        createNewSession();
      } else if (_activeSessionId == null ||
          !_sessions.any((s) => s.id == _activeSessionId)) {
        _activeSessionId = _sessions.first.id;
      }

      await _loadMessagesForAllSessions();
    } catch (e) {
      debugPrint('세션 불러오기 실패: $e');
      createNewSession();
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> _loadMessagesForAllSessions() async {
    final prefs = await SharedPreferences.getInstance();

    for (var session in _sessions) {
      final key = 'messages_${session.id}';
      final data = prefs.getString(key);

      if (data != null) {
        try {
          final list = jsonDecode(data) as List;
          session.messages = list.map((e) => Message.fromMap(e)).toList();
          debugPrint(
            '>>> v2.0.3: 세션 ${session.id} 메시지 ${session.messages.length}개 로드됨 (개별 저장소)',
          );
        } catch (e) {
          debugPrint('>>> 세션 ${session.id} 메시지 로드 실패: $e');
        }
      } else {
        if (session.messages.isEmpty) {
          debugPrint('>>> 세션 ${session.id} 메시지 없음 (새 채팅)');
        }
      }
    }
  }

  Future<void> saveAllSessions() async {
    _saveQueue = _saveQueue.then((_) => _persistAllSessions());
    return _saveQueue;
  }

  Future<void> _persistAllSessions() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final String sessionsJson = jsonEncode(
        _sessions.map((session) => session.toMetadataMap()).toList(),
      );
      await prefs.setString(_sessionsKey, sessionsJson);

      if (_activeSessionId != null) {
        await prefs.setString(_activeSessionIdKey, _activeSessionId!);
      }

      for (var session in _sessions) {
        final key = 'messages_${session.id}';
        final messagesJson = jsonEncode(session.messages.map(_toStorageMap).toList());
        await prefs.setString(key, messagesJson);
      }
    } catch (e) {
      debugPrint('세션 저장 실패: $e');
    }
  }

  void createNewSession({String? name}) {
    final newSession = ChatSession(
      id: _uuid.v4(),
      name: name ?? '새 채팅 ${_sessions.length + 1}',
      messages: [],
    );

    debugPrint('╔════════════════════════════════════════════════════════════');
    debugPrint('║ >>> 새 채팅 생성: ${newSession.id}');
    debugPrint('║ >>> 이름: ${newSession.name}');
    debugPrint('║ >>> 메시지 수: ${newSession.messages.length}');
    debugPrint('╚════════════════════════════════════════════════════════════');

    _sessions.insert(0, newSession);
    _activeSessionId = newSession.id;

    notifyListeners();
    saveAllSessions();
  }

  void switchSession(String id) {
    if (_sessions.any((s) => s.id == id)) {
      debugPrint('>>> 세션 전환: $_activeSessionId -> $id');
      _activeSessionId = id;
      notifyListeners();
      saveAllSessions();
    }
  }

  void renameSession(String id, String newName) {
    final index = _sessions.indexWhere((s) => s.id == id);
    if (index != -1) {
      _sessions[index].name = newName;
      _sessions[index].lastModifiedAt = DateTime.now();
      notifyListeners();
      saveAllSessions();
    }
  }

  Future<bool> deleteSession(String id) async {
    if (_sessions.length <= 1) {
      debugPrint('마지막 세션은 삭제할 수 없습니다.');
      return false;
    }

    final index = _sessions.indexWhere((s) => s.id == id);
    if (index != -1) {
      final removedSession = _sessions[index];
      final imagePaths = removedSession.messages
          .expand((message) => message.images)
          .map((image) => image.thumbnailPath)
          .whereType<String>()
          .where((path) => path.isNotEmpty)
          .toSet()
          .toList(growable: false);
      _sessions.removeAt(index);

      if (_activeSessionId == id) {
        _activeSessionId = _sessions.first.id;
      }

      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('messages_$id');
        await _deleteSessionImageFiles(imagePaths);
        debugPrint('>>> 세션 $id 및 메시지 삭제됨');
      } catch (e) {
        debugPrint('>>> 세션 $id 메시지 삭제 실패: $e');
      }

      notifyListeners();
      saveAllSessions();
      return true;
    }
    return false;
  }

  // =========================================================================
  // =========================================================================

  ChatSession? getSessionById(String sessionId) {
    try {
      return _sessions.firstWhere((s) => s.id == sessionId);
    } catch (e) {
      return null;
    }
  }

  void addMessageToSession(String sessionId, Message message) {
    final session = getSessionById(sessionId);
    if (session == null) {
      debugPrint('>>> 경고: 세션 $sessionId 없음, 메시지 추가 실패');
      return;
    }
    session.addMessage(_normalizeMessageForSession(sessionId, message));
    session.lastModifiedAt = DateTime.now();
    notifyListeners();
    saveAllSessions();
    debugPrint('>>> v2.0.5: 세션 $sessionId에 메시지 추가됨');
  }

  Message _normalizeMessageForSession(String sessionId, Message message) {
    return message.copyWith(
      id: message.id.isEmpty ? _uuid.v4() : message.id,
      chatId: message.chatId?.isNotEmpty == true ? message.chatId : sessionId,
    );
  }

  List<Message> getMessagesForSession(String sessionId) {
    final session = getSessionById(sessionId);
    if (session == null) {
      debugPrint('>>> 경고: 세션 $sessionId 없음');
      return [];
    }
    return List.unmodifiable(session.messages);
  }

  void deleteMessageFromSession(String sessionId, String messageId) {
    final session = getSessionById(sessionId);
    if (session == null) {
      debugPrint('>>> 경고: 세션 $sessionId 없음, 삭제 실패');
      return;
    }
    final messageIndex = session.messages.indexWhere((m) => m.id == messageId);
    final imagePaths = messageIndex == -1
        ? const <String>[]
        : session.messages[messageIndex].images
              .map((image) => image.thumbnailPath)
              .whereType<String>()
              .where((path) => path.isNotEmpty)
              .toList(growable: false);

    session.deleteMessageById(messageId);
    session.lastModifiedAt = DateTime.now();
    notifyListeners();
    saveAllSessions();
    _deleteSessionImageFiles(imagePaths);
  }

  void editMessageInSession(
    String sessionId,
    String messageId,
    String newContent,
  ) {
    final session = getSessionById(sessionId);
    if (session == null) {
      debugPrint('>>> 경고: 세션 $sessionId 없음, 수정 실패');
      return;
    }
    final index = session.messages.indexWhere((m) => m.id == messageId);
    if (index != -1) {
      session.messages[index] = session.messages[index].copyWith(
        content: newContent,
      );
      session.lastModifiedAt = DateTime.now();
      notifyListeners();
      saveAllSessions();
    }
  }

  Map<String, dynamic> _toStorageMap(Message message) {
    if (message.images.isEmpty) {
      return message.toMap();
    }

    final imageMaps = message.images
        .map((image) {
          final map = image.toMap();
          final storedPath = image.thumbnailPath;
          if (storedPath != null && storedPath.isNotEmpty) {
            map['base64Data'] = '';
          }
          return map;
        })
        .toList(growable: false);

    final out = message.toMap();
    out['images'] = imageMaps;
    return out;
  }

  Future<void> _deleteSessionImageFiles(List<String> paths) async {
    for (final filePath in paths) {
      await ImageCacheManager.instance.deleteFile(filePath);
    }
  }

  void removeImageFromMessageInSession(
    String sessionId,
    String messageId,
    String imageId,
  ) {
    final session = getSessionById(sessionId);
    if (session == null) {
      debugPrint('>>> 경고: 세션 $sessionId 없음, 이미지 삭제 실패');
      return;
    }

    final index = session.messages.indexWhere((m) => m.id == messageId);
    if (index == -1) {
      return;
    }

    final message = session.messages[index];
    if (message.images.isEmpty) {
      return;
    }

    final nextImages =
        message.images.where((image) => image.id != imageId).toList(growable: false);
    if (nextImages.length == message.images.length) {
      return;
    }

    session.messages[index] = message.copyWith(images: nextImages);
    session.lastModifiedAt = DateTime.now();
    notifyListeners();
    saveAllSessions();
    final removedImagePath = message.images
        .where((image) => image.id == imageId)
        .map((image) => image.thumbnailPath)
        .whereType<String>()
        .where((path) => path.isNotEmpty)
        .toList(growable: false);
    _deleteSessionImageFiles(removedImagePath);
  }

  void clearSession(String sessionId) {
    final session = getSessionById(sessionId);
    if (session == null) return;
    session.clearMessages();
    session.lastModifiedAt = DateTime.now();
    notifyListeners();
    saveAllSessions();
  }

  Map<String, String> getVariables(
    String sessionId,
    ChatVariableScope scope,
  ) {
    final session = getSessionById(sessionId);
    if (session == null) {
      return const <String, String>{};
    }
    return Map<String, String>.from(session.variablesForScope(scope));
  }

  Map<String, String> getVariableAliases(
    String sessionId,
    ChatVariableScope scope,
  ) {
    final session = getSessionById(sessionId);
    if (session == null) {
      return const <String, String>{};
    }
    return Map<String, String>.from(session.aliasesForScope(scope));
  }

  String? getVariableValue(
    String sessionId,
    ChatVariableScope scope,
    String variableName,
  ) {
    final session = getSessionById(sessionId);
    if (session == null) {
      return null;
    }
    return session.variablesForScope(scope)[variableName];
  }

  void setVariable(
    String sessionId,
    ChatVariableScope scope,
    String variableName,
    String value,
  ) {
    final session = getSessionById(sessionId);
    final normalizedName = variableName.trim();
    if (session == null || normalizedName.isEmpty) {
      return;
    }
    final nextValues = SessionVariableStore.cloneScopeMap(session.variableStore.values);
    nextValues[scope]![normalizedName] = value;
    session.variableStore = session.variableStore.copyWith(values: nextValues);
    session.lastModifiedAt = DateTime.now();
    notifyListeners();
    saveAllSessions();
  }

  void removeVariable(
    String sessionId,
    ChatVariableScope scope,
    String variableName,
  ) {
    final session = getSessionById(sessionId);
    if (session == null) {
      return;
    }
    final nextValues = SessionVariableStore.cloneScopeMap(session.variableStore.values);
    final nextAliases = SessionVariableStore.cloneScopeMap(session.variableStore.aliases);
    nextValues[scope]!.remove(variableName);
    nextAliases[scope]!.remove(variableName);
    session.variableStore = session.variableStore.copyWith(
      values: nextValues,
      aliases: nextAliases,
    );
    session.lastModifiedAt = DateTime.now();
    notifyListeners();
    saveAllSessions();
  }

  void incrementVariable(
    String sessionId,
    ChatVariableScope scope,
    String variableName,
    num delta,
  ) {
    final existing = num.tryParse(
      getVariableValue(sessionId, scope, variableName) ?? '0',
    );
    final next = (existing ?? 0) + delta;
    setVariable(sessionId, scope, variableName, _formatNumericValue(next));
  }

  void setVariableAlias(
    String sessionId,
    ChatVariableScope scope,
    String variableName,
    String alias,
  ) {
    final session = getSessionById(sessionId);
    if (session == null || variableName.trim().isEmpty) {
      return;
    }
    final nextAliases = SessionVariableStore.cloneScopeMap(session.variableStore.aliases);
    if (alias.trim().isEmpty) {
      nextAliases[scope]!.remove(variableName);
    } else {
      nextAliases[scope]![variableName] = alias.trim();
    }
    session.variableStore = session.variableStore.copyWith(aliases: nextAliases);
    session.lastModifiedAt = DateTime.now();
    notifyListeners();
    saveAllSessions();
  }

  SessionInteractionState getInteractionState(String sessionId) {
    final session = getSessionById(sessionId);
    return session?.interactionState ?? const SessionInteractionState();
  }

  void updateInteractionState(
    String sessionId, {
    String? html,
    String? css,
    String? activePresetId,
    bool clearPreset = false,
  }) {
    final session = getSessionById(sessionId);
    if (session == null) {
      return;
    }
    session.interactionState = session.interactionState.copyWith(
      html: html,
      css: css,
      activePresetId: activePresetId,
      clearPreset: clearPreset,
    );
    session.lastModifiedAt = DateTime.now();
    notifyListeners();
    saveAllSessions();
  }

  String _formatNumericValue(num value) {
    if (value is int) {
      return value.toString();
    }
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }
    return value.toString();
  }

  void deleteLastMessageFromSession(String sessionId) {
    final session = getSessionById(sessionId);
    if (session == null || session.messages.isEmpty) return;
    session.messages.removeLast();
    session.lastModifiedAt = DateTime.now();
    notifyListeners();
    saveAllSessions();
  }

  // =========================================================================
  // =========================================================================

  void addMessage(Message message) {
    final session = activeSession;
    if (session != null) {
      session.addMessage(message);
      notifyListeners();
      saveAllSessions();
    }
  }

  void deleteMessageAt(int index) {
    final session = activeSession;
    if (session != null) {
      session.deleteMessageAt(index);
      notifyListeners();
      saveAllSessions();
    }
  }

  void deleteMessageById(String messageId) {
    final session = activeSession;
    if (session != null) {
      session.deleteMessageById(messageId);
      notifyListeners();
      saveAllSessions();
    }
  }

  void deleteMessagesInRange(int start, int end) {
    final session = activeSession;
    if (session != null) {
      session.deleteMessagesInRange(start, end);
      notifyListeners();
      saveAllSessions();
    }
  }

  void editMessageAt(int index, String newContent) {
    final session = activeSession;
    if (session != null) {
      session.editMessageAt(index, newContent);
      notifyListeners();
      saveAllSessions();
    }
  }

  void clearCurrentSession() {
    final session = activeSession;
    if (session != null) {
      session.clearMessages();
      notifyListeners();
      saveAllSessions();
    }
  }

  void clearMessages() => clearCurrentSession();

  String exportCurrentSession() {
    final session = activeSession;
    if (session != null) {
      return const JsonEncoder.withIndent('  ').convert(session.toMap());
    }
    return '{}';
  }

  String exportSession(String id) {
    try {
      final session = _sessions.firstWhere((s) => s.id == id);
      return const JsonEncoder.withIndent('  ').convert(session.toMap());
    } catch (e) {
      return '{}';
    }
  }

  Message? getMessageAt(int index) {
    final session = activeSession;
    if (session != null && index >= 1 && index <= session.messages.length) {
      return session.messages[index - 1];
    }
    return null;
  }

  void deleteLastMessage() {
    final session = activeSession;
    if (session != null && session.messages.isNotEmpty) {
      session.messages.removeLast();
      session.lastModifiedAt = DateTime.now();
      notifyListeners();
      saveAllSessions();
    }
  }

  void sortSessionsByLastModified() {
    _sessions.sort((a, b) => b.lastModifiedAt.compareTo(a.lastModifiedAt));
    notifyListeners();
  }

  void resetAllSessions() {
    _sessions.clear();
    _activeSessionId = null;
    createNewSession();
  }
}

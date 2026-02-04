// ============================================================================
// 프롬프트 블록 Provider (Prompt Block Provider)
// ============================================================================
// 프롬프트 블록 시스템의 상태를 관리하는 Provider입니다.
// 블록 추가/삭제/수정/재정렬 기능을 제공합니다.
// ============================================================================

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../models/prompt_block.dart';
import '../models/message.dart';
import '../services/prompt_builder.dart';

/// 프롬프트 블록 상태를 관리하는 Provider
class PromptBlockProvider extends ChangeNotifier {
  // === 저장 키 상수 ===
  static const String _blocksKey = 'prompt_blocks';
  static const String _pastMessageCountKey = 'past_message_count';

  // === 상태 변수 ===
  List<PromptBlock> _blocks = []; // 프롬프트 블록 목록
  int _pastMessageCount = 10; // 과거 기억에 포함할 메시지 수
  bool _isLoading = false; // 로딩 상태
  final Uuid _uuid = const Uuid(); // UUID 생성기
  final PromptBuilder _promptBuilder = PromptBuilder(); // 프롬프트 빌더

  // === Getter ===
  List<PromptBlock> get blocks => List.unmodifiable(_blocks);
  int get pastMessageCount => _pastMessageCount;
  bool get isLoading => _isLoading;

  /// 생성자 - 저장된 블록을 불러오거나 기본 블록을 생성합니다
  PromptBlockProvider() {
    loadBlocks();
  }

  /// 저장된 블록을 불러옵니다
  Future<void> loadBlocks() async {
    _isLoading = true;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();

      // 블록 목록 불러오기
      final String? blocksJson = prefs.getString(_blocksKey);
      if (blocksJson != null) {
        final List<dynamic> blocksList = jsonDecode(blocksJson);
        _blocks = blocksList.map((json) => PromptBlock.fromMap(json)).toList();
      } else {
        // 저장된 데이터가 없으면 기본 블록 생성
        _initializeDefaultBlocks();
      }

      // 과거 메시지 수 불러오기
      _pastMessageCount = prefs.getInt(_pastMessageCountKey) ?? 10;
    } catch (e) {
      debugPrint('블록 불러오기 실패: $e');
      _initializeDefaultBlocks();
    }

    _isLoading = false;
    notifyListeners();
  }

  /// 기본 블록을 초기화합니다
  void _initializeDefaultBlocks() {
    _blocks = [
      PromptBlock.systemPrompt(), // 시스템 프롬프트
      PromptBlock.character(), // 캐릭터 설정
      PromptBlock.pastMemory(), // 과거 기억
      PromptBlock.userInput(), // 사용자 입력
    ];
  }

  /// 블록을 저장합니다
  Future<void> saveBlocks() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // 블록 목록 저장
      final String blocksJson = jsonEncode(
        _blocks.map((block) => block.toMap()).toList(),
      );
      await prefs.setString(_blocksKey, blocksJson);

      // 과거 메시지 수 저장
      await prefs.setInt(_pastMessageCountKey, _pastMessageCount);
    } catch (e) {
      debugPrint('블록 저장 실패: $e');
    }
  }

  /// 새 블록을 추가합니다
  ///
  /// 두 가지 방식으로 호출 가능:
  /// 1. addBlock(name, content) - 기본 설정으로 블록 생성
  /// 2. addBlock(PromptBlock block) - 완전한 블록 객체 전달
  void addBlock(dynamic nameOrBlock, [String? content]) {
    PromptBlock newBlock;

    if (nameOrBlock is PromptBlock) {
      // PromptBlock 객체가 전달된 경우
      newBlock = nameOrBlock.id.isEmpty
          ? nameOrBlock.copyWith(id: _uuid.v4())
          : nameOrBlock;
    } else if (nameOrBlock is String && content != null) {
      // 이름과 내용이 전달된 경우 (레거시 호환)
      // 새 블록의 order는 user_input 바로 앞
      final userInputIndex = _blocks.indexWhere(
        (b) => b.id == PromptBlock.TYPE_USER_INPUT,
      );
      final newOrder = userInputIndex > 0
          ? _blocks[userInputIndex - 1].order + 1
          : 50;

      newBlock = PromptBlock(
        id: _uuid.v4(),
        name: nameOrBlock,
        content: content,
        isEnabled: true,
        isSystemBlock: false,
        order: newOrder,
      );
    } else {
      debugPrint('addBlock: 잘못된 인자');
      return;
    }

    _blocks.add(newBlock);
    _sortBlocks();
    notifyListeners();
    saveBlocks();
  }

  /// 블록을 삭제합니다 (시스템 블록은 삭제 불가)
  bool removeBlock(String id) {
    final block = _blocks.firstWhere(
      (b) => b.id == id,
      orElse: () => PromptBlock(name: ''),
    );

    // 시스템 블록은 삭제 불가
    if (block.isSystemBlock) {
      debugPrint('시스템 블록은 삭제할 수 없습니다.');
      return false;
    }

    _blocks.removeWhere((b) => b.id == id);
    notifyListeners();
    saveBlocks();
    return true;
  }

  /// 블록 활성화/비활성화 토글
  void toggleBlock(String id) {
    final index = _blocks.indexWhere((b) => b.id == id);
    if (index != -1) {
      _blocks[index] = _blocks[index].copyWith(
        isEnabled: !_blocks[index].isEnabled,
      );
      notifyListeners();
      saveBlocks();
    }
  }

  /// 블록 순서 변경 (드래그 앤 드롭)
  void reorderBlocks(int oldIndex, int newIndex) {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }

    final block = _blocks.removeAt(oldIndex);
    _blocks.insert(newIndex, block);

    // order 값 재할당
    for (int i = 0; i < _blocks.length; i++) {
      _blocks[i] = _blocks[i].copyWith(order: i * 10);
    }

    notifyListeners();
    saveBlocks();
  }

  /// 블록 내용 수정
  void updateBlockContent(String id, String content) {
    final index = _blocks.indexWhere((b) => b.id == id);
    if (index != -1) {
      _blocks[index] = _blocks[index].copyWith(content: content);
      notifyListeners();
      saveBlocks();
    }
  }

  /// 블록 이름 수정
  void updateBlockName(String id, String name) {
    final index = _blocks.indexWhere((b) => b.id == id);
    if (index != -1) {
      _blocks[index] = _blocks[index].copyWith(name: name);
      notifyListeners();
      saveBlocks();
    }
  }

  /// 과거 메시지 수 변경
  void setPastMessageCount(int count) {
    if (count > 0) {
      _pastMessageCount = count;
      notifyListeners();
      saveBlocks();
    }
  }

  /// 블록을 order 기준으로 정렬
  void _sortBlocks() {
    _blocks.sort((a, b) => a.order.compareTo(b.order));
  }

  /// 특정 ID의 블록 가져오기
  PromptBlock? getBlock(String id) {
    try {
      return _blocks.firstWhere((b) => b.id == id);
    } catch (e) {
      return null;
    }
  }

  /// 최종 프롬프트 미리보기 (디버그/확인용)
  ///
  /// [pastMessages]: 과거 대화 내역
  /// [currentInput]: 현재 사용자 입력
  String buildFinalPrompt(List<Message> pastMessages, String currentInput) {
    return _promptBuilder.buildFinalPrompt(
      blocks: _blocks,
      pastMessages: pastMessages,
      currentInput: currentInput,
      pastMessageCount: _pastMessageCount,
    );
  }

  /// API 호출용 메시지 목록 생성
  List<Map<String, String>> buildMessagesForApi(
    List<Message> pastMessages,
    String currentInput, {
    bool hasFirstSystemPrompt = true,
    bool requiresAlternateRole = true,
  }) {
    return _promptBuilder.buildMessagesForApi(
      blocks: _blocks,
      pastMessages: pastMessages,
      currentInput: currentInput,
      pastMessageCount: _pastMessageCount,
      hasFirstSystemPrompt: hasFirstSystemPrompt,
      requiresAlternateRole: requiresAlternateRole,
    );
  }

  /// 모든 블록을 기본값으로 리셋
  void resetToDefaults() {
    _initializeDefaultBlocks();
    _pastMessageCount = 10;
    notifyListeners();
    saveBlocks();
  }

  /// 프롬프트 미리보기 텍스트 생성 (⭐ v2.0.3: 헤더 없이)
  String buildPreviewText() {
    final StringBuffer buffer = StringBuffer();

    for (final block in _blocks.where((b) => b.isEnabled)) {
      if (block.type == PromptBlock.TYPE_PAST_MEMORY) {
        buffer.writeln('[과거 대화]');
        buffer.writeln('(최근 $_pastMessageCount개 메시지가 여기에 포함됩니다)');
      } else if (block.type == PromptBlock.TYPE_USER_INPUT) {
        buffer.writeln('[사용자 입력]');
        buffer.writeln('(사용자 입력이 여기에 포함됩니다)');
      } else {
        // ⭐ v2.0.3: 헤더 없이 내용만 표시
        buffer.writeln(block.content.isEmpty ? '(내용 없음)' : block.content);
      }
      buffer.writeln();
    }

    return buffer.toString().trim();
  }
}

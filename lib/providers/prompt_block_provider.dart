// ============================================================================
// ============================================================================
// ============================================================================

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../models/prompt_block.dart';
import '../models/message.dart';
import '../services/prompt_builder.dart';

class PromptBlockProvider extends ChangeNotifier {
  static const String _blocksKey = 'prompt_blocks';
  static const String _pastMessageCountKey = 'past_message_count';

  List<PromptBlock> _blocks = [];
  int _pastMessageCount = 10;
  bool _isLoading = false;
  final Uuid _uuid = const Uuid();
  final PromptBuilder _promptBuilder = PromptBuilder();

  // === Getter ===
  List<PromptBlock> get blocks => List.unmodifiable(_blocks);
  int get pastMessageCount => _pastMessageCount;
  bool get isLoading => _isLoading;

  PromptBlockProvider() {
    loadBlocks();
  }

  Future<void> loadBlocks() async {
    _isLoading = true;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();

      final String? blocksJson = prefs.getString(_blocksKey);
      if (blocksJson != null) {
        final List<dynamic> blocksList = jsonDecode(blocksJson);
        _blocks = blocksList.map((json) => PromptBlock.fromMap(json)).toList();
      } else {
        _initializeDefaultBlocks();
      }

      _pastMessageCount = prefs.getInt(_pastMessageCountKey) ?? 10;
    } catch (e) {
      debugPrint('블록 불러오기 실패: $e');
      _initializeDefaultBlocks();
    }

    _isLoading = false;
    notifyListeners();
  }

  void _initializeDefaultBlocks() {
    _blocks = [
      PromptBlock.systemPrompt(),
      PromptBlock.character(),
      PromptBlock.pastMemory(),
      PromptBlock.userInput(),
    ];
  }

  Future<void> saveBlocks() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final String blocksJson = jsonEncode(
        _blocks.map((block) => block.toMap()).toList(),
      );
      await prefs.setString(_blocksKey, blocksJson);

      await prefs.setInt(_pastMessageCountKey, _pastMessageCount);
    } catch (e) {
      debugPrint('블록 저장 실패: $e');
    }
  }

  ///
  void addBlock(dynamic nameOrBlock, [String? content]) {
    PromptBlock newBlock;

    if (nameOrBlock is PromptBlock) {
      newBlock = nameOrBlock.id.isEmpty
          ? nameOrBlock.copyWith(id: _uuid.v4())
          : nameOrBlock;
    } else if (nameOrBlock is String && content != null) {
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

  bool removeBlock(String id) {
    final block = _blocks.firstWhere(
      (b) => b.id == id,
      orElse: () => PromptBlock(name: ''),
    );

    if (block.isSystemBlock) {
      debugPrint('시스템 블록은 삭제할 수 없습니다.');
      return false;
    }

    _blocks.removeWhere((b) => b.id == id);
    notifyListeners();
    saveBlocks();
    return true;
  }

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

  void reorderBlocks(int oldIndex, int newIndex) {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }

    final block = _blocks.removeAt(oldIndex);
    _blocks.insert(newIndex, block);

    for (int i = 0; i < _blocks.length; i++) {
      _blocks[i] = _blocks[i].copyWith(order: i * 10);
    }

    notifyListeners();
    saveBlocks();
  }

  void updateBlockContent(String id, String content) {
    final index = _blocks.indexWhere((b) => b.id == id);
    if (index != -1) {
      _blocks[index] = _blocks[index].copyWith(content: content);
      notifyListeners();
      saveBlocks();
    }
  }

  void updateBlockName(String id, String name) {
    final index = _blocks.indexWhere((b) => b.id == id);
    if (index != -1) {
      _blocks[index] = _blocks[index].copyWith(name: name);
      notifyListeners();
      saveBlocks();
    }
  }

  void setPastMessageCount(int count) {
    if (count > 0) {
      _pastMessageCount = count;
      notifyListeners();
      saveBlocks();
    }
  }

  void _sortBlocks() {
    _blocks.sort((a, b) => a.order.compareTo(b.order));
  }

  PromptBlock? getBlock(String id) {
    try {
      return _blocks.firstWhere((b) => b.id == id);
    } catch (e) {
      return null;
    }
  }

  ///
  String buildFinalPrompt(List<Message> pastMessages, String currentInput) {
    return _promptBuilder.buildFinalPrompt(
      blocks: _blocks,
      pastMessages: pastMessages,
      currentInput: currentInput,
      pastMessageCount: _pastMessageCount,
    );
  }

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

  void resetToDefaults() {
    _initializeDefaultBlocks();
    _pastMessageCount = 10;
    notifyListeners();
    saveBlocks();
  }

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
        buffer.writeln(block.content.isEmpty ? '(내용 없음)' : block.content);
      }
      buffer.writeln();
    }

    return buffer.toString().trim();
  }
}

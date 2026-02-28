// ============================================================================
// ============================================================================
// ============================================================================

import 'package:uuid/uuid.dart';

import '../models/character.dart';
import '../models/message.dart';
import '../models/settings.dart';
import '../models/prompt_block.dart';

class PromptBuilder {
  final Uuid _uuid = const Uuid();

  // ============================================================================
  // ============================================================================

  ///
  ///
  String buildFinalPrompt({
    required List<PromptBlock> blocks,
    required List<Message> pastMessages,
    required String currentInput,
    bool skipInputBlock = false,
  }) {
    final enabledBlocks = blocks.where((block) => block.isActive).toList()
      ..sort((a, b) => a.order.compareTo(b.order));

    final List<String> promptParts = [];

    for (final block in enabledBlocks) {
      String content = '';

      if (block.type == PromptBlock.typePastMemory) {
        content = _buildPastMemoryXml(pastMessages, block);
      } else if (block.type == PromptBlock.typeInput) {
        if (!skipInputBlock) {
          content = currentInput;
        }
      } else if (block.type == PromptBlock.typePrompt) {
        content = block.content;
      } else {
        content = block.content;
      }

      if (content.isNotEmpty) {
        promptParts.add(content);
      }
    }

    return promptParts.join('\n\n');
  }

  ///
  /// ```xml
  /// ```
  ///
  String _buildPastMemoryXml(List<Message> messages, PromptBlock block) {
    if (messages.isEmpty) return '';

    final filteredMessages = messages
        .where((msg) => msg.role != MessageRole.system)
        .toList();

    if (filteredMessages.isEmpty) return '';

    final int range = _parseNaturalRange(block.range);
    final recentMessages = filteredMessages.length > range
        ? filteredMessages.sublist(filteredMessages.length - range)
        : filteredMessages;

    final String userHeader = block.userHeader.trim().isEmpty
        ? 'user'
        : block.userHeader.trim();
    final String charHeader = block.charHeader.trim().isEmpty
        ? 'char'
        : block.charHeader.trim();

    final List<String> xmlParts = [];
    for (final msg in recentMessages) {
      if (msg.role == MessageRole.user) {
        xmlParts.add('<$userHeader>${msg.content}</$userHeader>');
      } else if (msg.role == MessageRole.assistant) {
        xmlParts.add('<$charHeader>${msg.content}</$charHeader>');
      }
    }

    return xmlParts.join('');
  }

  ///
  List<Map<String, String>> buildMessagesForApi({
    required List<PromptBlock> blocks,
    required List<Message> pastMessages,
    required String currentInput,
    bool hasFirstSystemPrompt = true,
    bool requiresAlternateRole = true,
    bool skipInputBlock = false,
  }) {
    // Kept for API compatibility with existing call sites.
    final _ = requiresAlternateRole;

    final String prompt = buildFinalPrompt(
      blocks: blocks,
      pastMessages: pastMessages,
      currentInput: currentInput,
      skipInputBlock: skipInputBlock,
    );

    if (prompt.isEmpty) {
      return [];
    }

    final role = hasFirstSystemPrompt ? 'system' : 'user';
    return [
      {'role': role, 'content': prompt},
    ];
  }

  int _parseNaturalRange(String value) {
    final parsed = int.tryParse(value.trim());
    if (parsed == null || parsed <= 0) {
      return 1;
    }
    return parsed;
  }

  // ============================================================================
  // ============================================================================

  String buildSystemPrompt({
    required Character character,
    required AppSettings settings,
    String userName = 'User',
  }) {
    final List<String> promptParts = [];

    promptParts.add('''당신은 "${character.name}"이라는 캐릭터를 연기하는 롤플레이 AI입니다.
아래의 캐릭터 정보와 시나리오에 따라 일관되게 행동하세요.
항상 캐릭터로서 응답하며, AI라는 사실을 언급하지 마세요.
사용자의 이름은 "$userName"입니다.''');

    if (character.description.isNotEmpty) {
      promptParts.add('[캐릭터 설명]\n${character.description}');
    }

    if (character.personality.isNotEmpty) {
      promptParts.add('[캐릭터 성격]\n${character.personality}');
    }

    if (character.scenario.isNotEmpty) {
      promptParts.add('[시나리오]\n${character.scenario}');
    }

    if (character.exampleDialogue.isNotEmpty) {
      String exampleDialogue = character.exampleDialogue
          .replaceAll('{{user}}', userName)
          .replaceAll('{{char}}', character.name);
      promptParts.add('[예시 대화]\n$exampleDialogue');
    }

    if (settings.live2dPromptInjectionEnabled &&
        settings.live2dSystemPromptTemplate.trim().isNotEmpty) {
      promptParts.add(settings.live2dSystemPromptTemplate.trim());
    }

    // Note: systemPrompt from AppSettings is deprecated.
    // All prompt configuration should use the Prompt Blocks system.

    return promptParts.join('\n\n');
  }

  List<Message> buildMessages({
    required Character character,
    required AppSettings settings,
    required List<Message> chatHistory,
    String userName = 'User',
  }) {
    final List<Message> messages = [];

    final String systemPrompt = buildSystemPrompt(
      character: character,
      settings: settings,
      userName: userName,
    );

    messages.add(
      Message(id: _uuid.v4(), role: MessageRole.system, content: systemPrompt),
    );

    if (chatHistory.isEmpty && character.firstMessage.isNotEmpty) {
      final String firstMessage = character.firstMessage
          .replaceAll('{{user}}', userName)
          .replaceAll('{{char}}', character.name);

      messages.add(
        Message(
          id: _uuid.v4(),
          role: MessageRole.assistant,
          content: firstMessage,
        ),
      );
    }

    for (final msg in chatHistory) {
      if (msg.role != MessageRole.system) {
        messages.add(msg);
      }
    }

    return messages;
  }

  String getFirstMessage({
    required Character character,
    String userName = 'User',
  }) {
    if (character.firstMessage.isEmpty) {
      return '안녕하세요!';
    }

    return character.firstMessage
        .replaceAll('{{user}}', userName)
        .replaceAll('{{char}}', character.name);
  }
}

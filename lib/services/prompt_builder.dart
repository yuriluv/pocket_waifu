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
    int pastMessageCount = 10,
  }) {
    final enabledBlocks = blocks.where((block) => block.isEnabled).toList()
      ..sort((a, b) => a.order.compareTo(b.order));

    final List<String> promptParts = [];

    for (final block in enabledBlocks) {
      String content = '';

      if (block.id == PromptBlock.TYPE_PAST_MEMORY) {
        content = _buildPastMemoryXml(pastMessages, pastMessageCount);
      } else if (block.id == PromptBlock.TYPE_USER_INPUT) {
        content = currentInput;
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
  String _buildPastMemoryXml(List<Message> messages, int count) {
    if (messages.isEmpty) return '';

    final recentMessages = messages.length > count
        ? messages.sublist(messages.length - count)
        : messages;

    final filteredMessages = recentMessages
        .where((msg) => msg.role != MessageRole.system)
        .toList();

    if (filteredMessages.isEmpty) return '';

    final List<String> xmlParts = [];
    int turnNumber = 1;
    int i = 0;

    while (i < filteredMessages.length) {
      final msg = filteredMessages[i];

      if (msg.role == MessageRole.user) {
        xmlParts.add(
          '<user chat $turnNumber>${msg.content}</user chat $turnNumber>',
        );
        i++;

        if (i < filteredMessages.length &&
            filteredMessages[i].role == MessageRole.assistant) {
          xmlParts.add(
            '<char chat $turnNumber>${filteredMessages[i].content}</char chat $turnNumber>',
          );
          i++;
        }
        turnNumber++;
      } else if (msg.role == MessageRole.assistant) {
        xmlParts.add(
          '<char chat $turnNumber>${msg.content}</char chat $turnNumber>',
        );
        i++;
        turnNumber++;
      } else {
        i++;
      }
    }

    return xmlParts.join('\n');
  }

  ///
  List<Map<String, String>> buildMessagesForApi({
    required List<PromptBlock> blocks,
    required List<Message> pastMessages,
    required String currentInput,
    int pastMessageCount = 10,
    bool hasFirstSystemPrompt = true,
    bool requiresAlternateRole = true,
  }) {
    final List<Map<String, String>> formatted = [];

    final enabledBlocks = blocks.where((block) => block.isEnabled).toList()
      ..sort((a, b) => a.order.compareTo(b.order));

    final systemParts = <String>[];
    for (final block in enabledBlocks) {
      if (block.id != PromptBlock.TYPE_PAST_MEMORY &&
          block.id != PromptBlock.TYPE_USER_INPUT &&
          block.content.isNotEmpty) {
        systemParts.add('[${block.name}]\n${block.content}');
      }
    }

    if (hasFirstSystemPrompt && systemParts.isNotEmpty) {
      formatted.add({'role': 'system', 'content': systemParts.join('\n\n')});
    }

    final pastMemoryBlock = enabledBlocks.firstWhere(
      (b) => b.id == PromptBlock.TYPE_PAST_MEMORY,
      orElse: () => PromptBlock.pastMemory()..isEnabled = false,
    );

    if (pastMemoryBlock.isEnabled && pastMessages.isNotEmpty) {
      final recentMessages = pastMessages.length > pastMessageCount
          ? pastMessages.sublist(pastMessages.length - pastMessageCount)
          : pastMessages;

      for (final msg in recentMessages) {
        if (msg.role == MessageRole.user) {
          formatted.add({'role': 'user', 'content': msg.content});
        } else if (msg.role == MessageRole.assistant) {
          formatted.add({'role': 'assistant', 'content': msg.content});
        }
      }
    }

    if (currentInput.isNotEmpty) {
      formatted.add({'role': 'user', 'content': currentInput});
    }

    if (requiresAlternateRole) {
      return _mergeConsecutiveSameRoles(formatted);
    }

    return formatted;
  }

  List<Map<String, String>> _mergeConsecutiveSameRoles(
    List<Map<String, String>> messages,
  ) {
    if (messages.isEmpty) return messages;

    final List<Map<String, String>> merged = [];

    for (final msg in messages) {
      if (merged.isEmpty) {
        merged.add(Map.from(msg));
      } else {
        final lastMsg = merged.last;
        if (lastMsg['role'] == msg['role']) {
          lastMsg['content'] = '${lastMsg['content']}\n\n${msg['content']}';
        } else {
          merged.add(Map.from(msg));
        }
      }
    }

    return merged;
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

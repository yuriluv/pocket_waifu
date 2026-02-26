import 'package:flutter_application_1/models/message.dart';
import 'package:flutter_application_1/models/prompt_block.dart';
import 'package:flutter_application_1/services/prompt_builder.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PromptBuilder regression', () {
    test('buildFinalPrompt keeps order and injects past-memory XML', () {
      final builder = PromptBuilder();
      final blocks = [
        PromptBlock(
          id: 'rule-block',
          name: 'Rules',
          content: 'Keep roleplay consistency.',
          order: 1,
        ),
        PromptBlock.pastMemory()..order = 2,
        PromptBlock.userInput()..order = 3,
      ];
      final pastMessages = [
        Message(id: 'a', role: MessageRole.system, content: 'ignored system'),
        Message(id: 'b', role: MessageRole.user, content: 'hello'),
        Message(id: 'c', role: MessageRole.assistant, content: 'hi there'),
      ];

      final prompt = builder.buildFinalPrompt(
        blocks: blocks,
        pastMessages: pastMessages,
        currentInput: 'current input',
      );

      expect(prompt, contains('Keep roleplay consistency.'));
      expect(prompt, contains('<user chat 1>hello</user chat 1>'));
      expect(prompt, contains('<char chat 1>hi there</char chat 1>'));
      expect(prompt, endsWith('current input'));
    });

    test('buildMessagesForApi merges consecutive user roles', () {
      final builder = PromptBuilder();
      final blocks = [
        PromptBlock(
          id: PromptBlock.TYPE_SYSTEM_PROMPT,
          name: 'System',
          type: PromptBlock.TYPE_SYSTEM_PROMPT,
          content: 'System contract',
          order: 0,
        ),
        PromptBlock.pastMemory()..order = 1,
      ];
      final pastMessages = [
        Message(id: 'u1', role: MessageRole.user, content: 'old user one'),
        Message(id: 'u2', role: MessageRole.user, content: 'old user two'),
      ];

      final apiMessages = builder.buildMessagesForApi(
        blocks: blocks,
        pastMessages: pastMessages,
        currentInput: 'new user input',
        hasFirstSystemPrompt: true,
        requiresAlternateRole: true,
      );

      expect(apiMessages.first['role'], 'system');
      expect(apiMessages[1]['role'], 'user');
      expect(apiMessages[1]['content'], contains('old user one'));
      expect(apiMessages[1]['content'], contains('old user two'));
      expect(apiMessages[1]['content'], contains('new user input'));
      expect(apiMessages.length, 2);
    });
  });
}

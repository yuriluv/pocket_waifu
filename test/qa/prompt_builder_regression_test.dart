import 'package:flutter_application_1/models/message.dart';
import 'package:flutter_application_1/models/prompt_block.dart';
import 'package:flutter_application_1/services/prompt_builder.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PromptBuilder regression', () {
    test('buildFinalPrompt keeps order and injects past-memory XML', () {
      final builder = PromptBuilder();
      final blocks = [
        PromptBlock.prompt(
          id: 'rule-block',
          title: 'Rules',
          content: 'Keep roleplay consistency.',
          order: 1,
        ),
        PromptBlock.pastMemory(
          title: 'Past Memory',
          range: '2',
          userHeader: 'user',
          charHeader: 'char',
          order: 2,
        ),
        PromptBlock.input(title: 'Input', order: 3),
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
      expect(prompt, contains('<user>hello</user>'));
      expect(prompt, contains('<char>hi there</char>'));
      expect(prompt, endsWith('current input'));
    });

    test('buildMessagesForApi returns single message payload', () {
      final builder = PromptBuilder();
      final blocks = [
        PromptBlock.prompt(
          title: 'System',
          content: 'System contract',
          order: 0,
        ),
        PromptBlock.input(title: 'Input', order: 1),
      ];
      final pastMessages = <Message>[];

      final apiMessages = builder.buildMessagesForApi(
        blocks: blocks,
        pastMessages: pastMessages,
        currentInput: 'new user input',
        hasFirstSystemPrompt: true,
        requiresAlternateRole: true,
      );

      expect(apiMessages.first['role'], 'system');
      expect(apiMessages.first['content'], contains('System contract'));
      expect(apiMessages.first['content'], contains('new user input'));
      expect(apiMessages.length, 1);
    });
  });
}

import 'package:flutter_application_1/models/message.dart';
import 'package:flutter_application_1/models/prompt_block.dart';
import 'package:flutter_application_1/models/settings.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Model serialization contract', () {
    test('Message round-trip keeps core fields', () {
      final original = Message(
        id: 'msg-1',
        chatId: 'chat-1',
        role: MessageRole.assistant,
        content: 'contract payload',
        timestamp: DateTime.parse('2026-01-01T00:00:00.000Z'),
        metadata: {'tokens': 42},
      );

      final restored = Message.fromMap(original.toMap());

      expect(restored.id, original.id);
      expect(restored.chatId, original.chatId);
      expect(restored.role, original.role);
      expect(restored.content, original.content);
      expect(restored.timestamp.toIso8601String(), original.timestamp.toIso8601String());
      expect(restored.metadata, original.metadata);
    });

    test('PromptBlock map conversion preserves read-only types', () {
      final block = PromptBlock.pastMemory(range: '5', userHeader: 'user');

      final restored = PromptBlock.fromMap(block.toMap());

      expect(restored.type, PromptBlock.typePastMemory);
      expect(restored.range, '5');
      expect(restored.userHeader, 'user');
    });

    test('AppSettings defaults can be materialized from empty map', () {
      final settings = AppSettings.fromMap({});

      expect(settings.apiProvider, ApiProvider.openai);
      expect(settings.currentModel, 'gpt-4o-mini');
      expect(settings.maxTokens, 1024);
      expect(settings.live2dLlmIntegrationEnabled, isTrue);
      expect(settings.live2dLuaExecutionEnabled, isTrue);
      expect(settings.live2dShowRawDirectivesInChat, isFalse);
      expect(settings.live2dSystemPromptTokenBudget, 500);
    });
  });
}

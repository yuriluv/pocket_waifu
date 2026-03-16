import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_application_1/models/chat_variable_scope.dart';
import 'package:flutter_application_1/models/message.dart';
import 'package:flutter_application_1/providers/chat_session_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Session interaction persistence', () {
    test('variables stay isolated per session and scope', () async {
      SharedPreferences.setMockInitialValues({});
      final provider = ChatSessionProvider();
      await provider.loadAllSessions();

      final firstSessionId = provider.activeSessionId!;
      provider.setVariable(firstSessionId, ChatVariableScope.mainChat, 'hp', '12');
      provider.setVariable(firstSessionId, ChatVariableScope.menu, 'hp', '30');
      provider.setVariableAlias(firstSessionId, ChatVariableScope.mainChat, 'hp', 'Health');

      provider.createNewSession(name: 'Session 2');
      final secondSessionId = provider.activeSessionId!;
      provider.setVariable(secondSessionId, ChatVariableScope.mainChat, 'hp', '99');

      expect(provider.getVariableValue(firstSessionId, ChatVariableScope.mainChat, 'hp'), '12');
      expect(provider.getVariableValue(firstSessionId, ChatVariableScope.menu, 'hp'), '30');
      expect(provider.getVariableValue(secondSessionId, ChatVariableScope.mainChat, 'hp'), '99');
      expect(provider.getVariableAliases(firstSessionId, ChatVariableScope.mainChat)['hp'], 'Health');
    });

    test('interaction state survives reload', () async {
      SharedPreferences.setMockInitialValues({});
      final provider = ChatSessionProvider();
      await provider.loadAllSessions();

      final sessionId = provider.activeSessionId!;
      provider.updateInteractionState(
        sessionId,
        html: '<div id="board">hello</div>',
        css: '#board { color: red; }',
        activePresetId: 'preset-1',
      );
      provider.setVariable(sessionId, ChatVariableScope.newChat, 'intro_seen', '1');
      await provider.saveAllSessions();

      final restored = ChatSessionProvider();
      await restored.loadAllSessions();
      final restoredSessionId = restored.activeSessionId!;
      final interactionState = restored.getInteractionState(restoredSessionId);

      expect(interactionState.html, '<div id="board">hello</div>');
      expect(interactionState.css, '#board { color: red; }');
      expect(interactionState.activePresetId, 'preset-1');
      expect(
        restored.getVariableValue(
          restoredSessionId,
          ChatVariableScope.newChat,
          'intro_seen',
        ),
        '1',
      );
    });

    test('provider normalizes persisted message ids and chat ids', () async {
      SharedPreferences.setMockInitialValues({});
      final provider = ChatSessionProvider();
      await provider.loadAllSessions();
      final sessionId = provider.activeSessionId!;

      provider.addMessageToSession(
        sessionId,
        Message(role: MessageRole.user, content: 'hello'),
      );

      final message = provider.getMessagesForSession(sessionId).last;
      expect(message.id, isNotEmpty);
      expect(message.chatId, sessionId);
    });
  });
}

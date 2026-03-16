import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_application_1/features/cbs/services/cbs_service.dart';
import 'package:flutter_application_1/models/chat_variable_scope.dart';
import 'package:flutter_application_1/models/message.dart';
import 'package:flutter_application_1/providers/chat_session_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CBS service contract', () {
    test('setvar and getvar mutate session-scoped variables', () async {
      SharedPreferences.setMockInitialValues({});
      final sessionProvider = ChatSessionProvider();
      await sessionProvider.loadAllSessions();
      final sessionId = sessionProvider.activeSessionId!;

      final result = CbsService.instance.render(
        '{{setvar::hp::15}}HP={{getvar::hp}}',
        CbsRenderContext(
          sessionProvider: sessionProvider,
          sessionId: sessionId,
          scope: ChatVariableScope.mainChat,
          phase: CbsPhase.userInput,
          characterName: 'Mika',
          userName: 'User',
          messages: const <Message>[],
        ),
      );

      expect(result.output, 'HP=15');
      expect(
        sessionProvider.getVariableValue(sessionId, ChatVariableScope.mainChat, 'hp'),
        '15',
      );
    });

    test('when block and calc resolve nested expressions', () async {
      SharedPreferences.setMockInitialValues({});
      final sessionProvider = ChatSessionProvider();
      await sessionProvider.loadAllSessions();
      final sessionId = sessionProvider.activeSessionId!;
      sessionProvider.setVariable(sessionId, ChatVariableScope.mainChat, 'level', '7');

      final result = CbsService.instance.render(
        '{{#when {{? {{getvar::level}}>5}}}}high{{:else}}low{{/when}}',
        CbsRenderContext(
          sessionProvider: sessionProvider,
          sessionId: sessionId,
          scope: ChatVariableScope.mainChat,
          phase: CbsPhase.promptBuild,
          characterName: 'Mika',
          userName: 'User',
          messages: const <Message>[],
        ),
      );

      expect(result.output, 'high');
    });

    test('each block iterates arrays', () async {
      SharedPreferences.setMockInitialValues({});
      final sessionProvider = ChatSessionProvider();
      await sessionProvider.loadAllSessions();
      final sessionId = sessionProvider.activeSessionId!;

      final result = CbsService.instance.render(
        '{{#each {{array::a::b::c}} item}}[{{slot::item}}]{{/each}}',
        CbsRenderContext(
          sessionProvider: sessionProvider,
          sessionId: sessionId,
          scope: ChatVariableScope.mainChat,
          phase: CbsPhase.promptBuild,
          characterName: 'Mika',
          userName: 'User',
          messages: const <Message>[],
        ),
      );

      expect(result.output, '[a][b][c]');
    });

    test('allowWrites false prevents preview-side mutations', () async {
      SharedPreferences.setMockInitialValues({});
      final sessionProvider = ChatSessionProvider();
      await sessionProvider.loadAllSessions();
      final sessionId = sessionProvider.activeSessionId!;

      final result = CbsService.instance.render(
        '{{setvar::hp::99}}HP={{getvar::hp}}',
        CbsRenderContext(
          sessionProvider: sessionProvider,
          sessionId: sessionId,
          scope: ChatVariableScope.mainChat,
          phase: CbsPhase.promptBuild,
          characterName: 'Mika',
          userName: 'User',
          messages: const <Message>[],
          allowWrites: false,
        ),
      );

      expect(result.output, 'HP=null');
      expect(
        sessionProvider.getVariableValue(sessionId, ChatVariableScope.mainChat, 'hp'),
        isNull,
      );
    });
  });
}

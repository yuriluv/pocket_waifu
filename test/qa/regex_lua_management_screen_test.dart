import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_application_1/features/lua/services/lua_scripting_service.dart';
import 'package:flutter_application_1/providers/settings_provider.dart';
import 'package:flutter_application_1/screens/regex_lua_management_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    LuaScriptingService.instance.setLogsForTesting(const []);
  });

  testWidgets('lua diagnostics summary reflects latest logs and clears', (
    tester,
  ) async {
    final service = LuaScriptingService.instance;
    service.setLogsForTesting(const [
      '[2026-03-17T10:00:00.000Z] lua.exec script=demo scriptId=1 hook=onAssistantMessage stage=fallback reason=fallback_success elapsedMs=12 context={"hook":"onAssistantMessage"}',
      '[2026-03-17T10:00:01.000Z] lua.diag reason=pseudo_unsupported_statement_if_then context={"severity":"warning","engine":"fallback","hook":"onUserMessage"}',
    ]);

    await tester.pumpWidget(
      ChangeNotifierProvider<SettingsProvider>(
        create: (_) => SettingsProvider(),
        child: const MaterialApp(home: RegexLuaManagementScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Lua'));
    await tester.pumpAndSettle();

    expect(find.text('최근 Lua 진단'), findsOneWidget);
    expect(find.textContaining('fallback'), findsOneWidget);
    expect(find.textContaining('fallback_success'), findsOneWidget);
    expect(find.textContaining('pseudo_unsupported_statement_if_then'), findsOneWidget);

    await tester.tap(find.widgetWithText(OutlinedButton, '로그 지우기'));
    await tester.pumpAndSettle();

    expect(find.textContaining('기록 없음'), findsWidgets);
    expect(find.textContaining('경고/오류 없음'), findsOneWidget);
  });
}

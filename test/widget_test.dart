// ============================================================================
// ============================================================================
// ============================================================================

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/main.dart';

void main() {
  testWidgets('Pocket Waifu 앱이 시작됩니다', (WidgetTester tester) async {
    await tester.pumpWidget(const PocketWaifuApp());

    expect(find.text('Pocket Waifu'), findsNothing);
  });
}

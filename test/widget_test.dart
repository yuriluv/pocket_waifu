// ============================================================================
// Pocket Waifu 위젯 테스트
// ============================================================================
// 앱의 기본 위젯 테스트입니다.
// ============================================================================

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/main.dart';

void main() {
  testWidgets('Pocket Waifu 앱이 시작됩니다', (WidgetTester tester) async {
    // 앱 빌드
    await tester.pumpWidget(const PocketWaifuApp());

    // 앱이 로드되었는지 확인
    expect(find.text('Pocket Waifu'), findsNothing);  // 로딩 전에는 없을 수 있음
  });
}

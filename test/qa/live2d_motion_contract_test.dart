import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';

import 'package:flutter_application_1/features/live2d/data/services/live2d_native_bridge.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('com.example.flutter_application_1/live2d');

  final messenger = TestDefaultBinaryMessengerBinding
      .instance.defaultBinaryMessenger;
  final bridge = Live2DNativeBridge();

  setUp(() {
    messenger.setMockMethodCallHandler(channel, null);
    bridge.dispose();
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
    bridge.dispose();
  });

  group('Live2D motion no-fallback', () {
    test(
      'missing motion group should not fall back to a default motion',
      () async {
        final calls = <MethodCall>[];
        messenger.setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          if (call.method == 'playMotion') {
            return false;
          }
          return null;
        });

        final played = await bridge.playMotion('missing_group', 0);

        expect(played, isFalse);
        expect(calls, hasLength(1));
        expect(calls.single.method, 'playMotion');
        expect(
          calls.single.arguments,
          {'group': 'missing_group', 'index': 0, 'priority': 2},
        );
      },
    );

    test(
      'empty motion inventory reports zero groups and zero count',
      () async {
        messenger.setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'getMotionGroups') {
            return <dynamic>[];
          }
          if (call.method == 'getMotionCount') {
            return 0;
          }
          return null;
        });

        final groups = await bridge.getMotionGroups();
        final idleCount = await bridge.getMotionCount('Idle');

        expect(groups, isEmpty);
        expect(idleCount, 0);
      },
    );
  });
}

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

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

  group('Live2D bridge parameter/model contracts', () {
    test('setParameter sends exact payload including duration', () async {
      final calls = <MethodCall>[];
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        if (call.method == 'setParameter') {
          return true;
        }
        return null;
      });

      final ok = await bridge.setParameter('ParamAngleX', 0.35, durationMs: 200);

      expect(ok, isTrue);
      expect(calls, hasLength(1));
      expect(calls.single.method, 'setParameter');
      expect(
        calls.single.arguments,
        {'id': 'ParamAngleX', 'value': 0.35, 'durationMs': 200},
      );
    });

    test('getParameter returns null on plugin exception instead of throwing', () async {
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'getParameter') {
          throw MissingPluginException('simulated missing plugin');
        }
        return null;
      });

      final value = await bridge.getParameter('ParamEyeLOpen');

      expect(value, isNull);
    });

    test('getModelInfo returns empty map when native layer unavailable', () async {
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'getModelInfo') {
          throw MissingPluginException('simulated missing plugin');
        }
        return null;
      });

      final modelInfo = await bridge.getModelInfo();

      expect(modelInfo, isEmpty);
    });
  });
}

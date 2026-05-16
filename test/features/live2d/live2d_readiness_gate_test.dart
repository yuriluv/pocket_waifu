import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/features/live2d/data/services/live2d_native_bridge.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('com.example.flutter_application_1/live2d');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final bridge = Live2DNativeBridge();

  setUp(() {
    messenger.setMockMethodCallHandler(channel, null);
    bridge.dispose();
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
    bridge.dispose();
  });

  test('runtime parameter call defers until model-ready state arrives', () async {
    final calls = <MethodCall>[];
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      if (call.method == 'getHealthStatus') {
        return {
          'service': {'isRunning': false, 'currentModel': null},
        };
      }
      if (call.method == 'setParameter') {
        return true;
      }
      return null;
    });

    final pendingSet = bridge.setParameter('ParamAngleX', 0.35, durationMs: 250);

    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(calls.where((call) => call.method == 'setParameter'), isEmpty);

    bridge.debugHandleStateSync(<String, dynamic>{
      'type': 'stateSync',
      'isRunning': true,
      'modelLoaded': true,
      'uptimeMs': 1,
    });

    final ok = await pendingSet;
    expect(ok, isTrue);
    expect(calls.where((call) => call.method == 'setParameter'), hasLength(1));
  });

  test('runtime gate times out to degraded and blocks repeated parameter fetch', () async {
    final methodNames = <String>[];
    messenger.setMockMethodCallHandler(channel, (call) async {
      methodNames.add(call.method);
      if (call.method == 'getHealthStatus') {
        return {
          'service': {'isRunning': true, 'currentModel': null},
        };
      }
      return null;
    });

    final ready = await bridge.waitForRuntimeModelReady(
      timeout: const Duration(milliseconds: 30),
    );

    expect(ready, isFalse);
    expect(bridge.runtimeReadinessState, Live2DRuntimeReadinessState.degraded);
    expect(bridge.runtimeReadinessMessage, contains('Timed out'));

    final value = await bridge.getParameter('ParamEyeLOpen');
    expect(value, isNull);

    expect(methodNames.where((name) => name == 'getHealthStatus'), hasLength(1));
    expect(methodNames.where((name) => name == 'getParameter'), isEmpty);
  });
}

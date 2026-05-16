import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_application_1/features/live2d/data/models/model3_data.dart';
import 'package:flutter_application_1/features/live2d/data/services/model3_json_parser.dart';
import 'package:flutter_application_1/features/live2d/data/services/resolved_model_service.dart';
import 'package:flutter_application_1/features/live2d/presentation/screens/live2d_advanced_settings_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const live2dChannel = MethodChannel('com.example.flutter_application_1/live2d');
  const pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');

  final calls = <String>[];

  setUp(() async {
    calls.clear();
    SharedPreferences.setMockInitialValues(<String, Object>{});

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, (call) async {
      if (call.method == 'getApplicationDocumentsDirectory') {
        return '/tmp';
      }
      return '/tmp';
    });

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(live2dChannel, (call) async {
      calls.add(call.method);
      switch (call.method) {
        case 'getParameterIds':
          return <String>[];
        case 'getParameter':
          return 0.0;
        case 'setParameter':
          return true;
        default:
          return null;
      }
    });
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(live2dChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, null);
  });

  testWidgets(
    'Interaction and Motion tabs render runtime-fallback parameters from resolved model',
    (tester) async {
      final parser = _FakeParser(
        const Model3Data(
          motionGroups: <String, List<String>>{'Idle': <String>['idle_0.motion3.json']},
          expressions: <Model3Expression>[
            Model3Expression(name: 'Smile', filePath: 'exp_smile.exp3.json'),
          ],
          parameters: <Model3Parameter>[],
          hitAreas: <Model3HitArea>[],
        ),
      );

      final service = ResolvedModelService(
        runtimeSource: _FakeRuntimeSource(
          const ResolvedModelRuntimeSnapshot(
            runtimeBridgeAvailable: true,
            parameterIds: <String>['ParamRuntime'],
            parameterValues: <String, double>{'ParamRuntime': 1.25},
            motionGroups: <String, List<String>>{},
            expressions: <String>[],
          ),
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Live2DAdvancedSettingsScreen(
            model3Path: '/tmp/fake.model3.json',
            parser: parser,
            resolvedModelService: service,
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));

      await tester.tap(find.text('Interaction Test'));
      await tester.pumpAndSettle();
      expect(find.textContaining('ParamRuntime'), findsWidgets);

      await tester.tap(find.text('Motion & Params'));
      await tester.pumpAndSettle();
      expect(find.textContaining('ParamRuntime'), findsWidgets);

      expect(calls.where((method) => method == 'getParameterIds'), isEmpty);
    },
  );
}

class _FakeParser extends Model3JsonParser {
  _FakeParser(this._result);

  final Model3Data _result;

  @override
  Future<Model3Data> parseFile(String model3Path) async => _result;
}

class _FakeRuntimeSource implements ResolvedModelRuntimeSource {
  _FakeRuntimeSource(this._snapshot);

  final ResolvedModelRuntimeSnapshot _snapshot;

  @override
  Future<ResolvedModelRuntimeSnapshot> read() async => _snapshot;
}

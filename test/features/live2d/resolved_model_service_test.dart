import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/features/live2d/data/models/model3_data.dart';
import 'package:flutter_application_1/features/live2d/data/models/resolved_model.dart';
import 'package:flutter_application_1/features/live2d/data/services/resolved_model_service.dart';

void main() {
  group('ResolvedModelService', () {
    test('uses runtime parameter ids when static parameters are empty', () async {
      final service = ResolvedModelService(
        runtimeSource: _FakeRuntimeSource(
          const ResolvedModelRuntimeSnapshot(
            runtimeBridgeAvailable: true,
            parameterIds: <String>['ParamBody', 'ParamAngleX'],
            parameterValues: <String, double>{
              'ParamAngleX': 0.2,
              'ParamBody': -0.1,
            },
            motionGroups: <String, List<String>>{},
            expressions: <String>[],
          ),
        ),
      );

      final resolved = await service.resolve(
        const Model3Data(
          motionGroups: <String, List<String>>{},
          expressions: <Model3Expression>[],
          parameters: <Model3Parameter>[],
          hitAreas: <Model3HitArea>[],
        ),
      );

      expect(resolved.isDegraded, isFalse);
      expect(
        resolved.parameters.map((p) => p.id).toList(growable: false),
        equals(<String>['ParamAngleX', 'ParamBody']),
      );
      expect(resolved.parameters.first.source, ResolvedParameterSource.runtimeOnly);
      expect(resolved.parameters.first.defaultValue, 0.2);
      expect(resolved.diagnostics.usedRuntimeParameterFallback, isTrue);
    });

    test('exposes explicit degraded state when runtime bridge is unavailable', () async {
      final service = ResolvedModelService(
        runtimeSource: _FakeRuntimeSource(
          const ResolvedModelRuntimeSnapshot.unavailable(
            reason: 'Plugin not registered',
          ),
        ),
      );

      final resolved = await service.resolve(Model3Data.empty);

      expect(resolved.isDegraded, isTrue);
      expect(
        resolved.diagnostics.degradedReason,
        ResolvedModelDegradedReason.runtimeBridgeUnavailable,
      );
      expect(resolved.diagnostics.degradedMessage, 'Plugin not registered');
      expect(resolved.diagnostics.runtimeBridgeAvailable, isFalse);
    });

    test('keeps deterministic ordering for merged motion groups and parameters', () async {
      final service = ResolvedModelService(
        runtimeSource: _FakeRuntimeSource(
          const ResolvedModelRuntimeSnapshot(
            runtimeBridgeAvailable: true,
            parameterIds: <String>['ParamZ', 'ParamA'],
            parameterValues: <String, double>{'ParamA': 0.5},
            motionGroups: <String, List<String>>{
              'TapBody': <String>['tap_1', 'tap_0'],
              'Idle': <String>['idle_0'],
            },
            expressions: <String>['Smile'],
          ),
        ),
      );

      final resolved = await service.resolve(
        const Model3Data(
          motionGroups: <String, List<String>>{
            'TapBody': <String>['tap_0'],
          },
          expressions: <Model3Expression>[],
          parameters: <Model3Parameter>[
            Model3Parameter(
              id: 'ParamMouth',
              name: 'Mouth',
              min: -1,
              defaultValue: 0,
              max: 1,
            ),
          ],
          hitAreas: <Model3HitArea>[],
        ),
      );

      expect(
        resolved.motionGroups.keys.toList(growable: false),
        equals(<String>['Idle', 'TapBody']),
      );
      expect(
        resolved.motionGroups['TapBody'],
        equals(<String>['tap_0', 'tap_1']),
      );
      expect(
        resolved.parameters.map((p) => p.id).toList(growable: false),
        equals(<String>['ParamA', 'ParamMouth', 'ParamZ']),
      );
    });
  });
}

class _FakeRuntimeSource implements ResolvedModelRuntimeSource {
  const _FakeRuntimeSource(this.snapshot);

  final ResolvedModelRuntimeSnapshot snapshot;

  @override
  Future<ResolvedModelRuntimeSnapshot> read() async => snapshot;
}

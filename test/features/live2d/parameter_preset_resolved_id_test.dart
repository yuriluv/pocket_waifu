import 'package:flutter_application_1/features/live2d/data/models/live2d_parameter_preset.dart';
import 'package:flutter_application_1/features/live2d/data/models/parameter_alias_map.dart';
import 'package:flutter_application_1/features/live2d/data/repositories/live2d_settings_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('parameter preset resolved id behavior', () {
    final repository = Live2DSettingsRepository();

    test('apply preset to resolved ids', () {
      const preset = Live2DParameterPreset(
        id: 'preset-1',
        name: 'idle-smile',
        overrides: <String, double>{
          'parameter1': 1.0,
          'ParamBodyAngleX': 15.0,
        },
      );

      final aliases = ParameterAliasMap.fromAliasToReal(<String, String>{
        'parameter1': 'ParamEyeLOpen',
      });

      final result = repository.resolvePresetAgainstResolvedIds(
        preset,
        resolvedParameterIds: <String>{
          'ParamBodyAngleX',
          'ParamEyeLOpen',
        },
        aliases: aliases,
      );

      expect(result.warning, isNull);
      expect(
        result.preset.overrides,
        <String, double>{
          'ParamEyeLOpen': 1.0,
          'ParamBodyAngleX': 15.0,
        },
      );
    });

    test('unknown id warning', () {
      const preset = Live2DParameterPreset(
        id: 'preset-2',
        name: 'mixed',
        overrides: <String, double>{
          'unknownZ': 0.1,
          'ParamMouthOpenY': 0.8,
          'unknownA': 0.2,
        },
      );

      final result = repository.resolvePresetAgainstResolvedIds(
        preset,
        resolvedParameterIds: <String>{'ParamMouthOpenY'},
      );

      expect(result.preset.overrides, <String, double>{'ParamMouthOpenY': 0.8});
      expect(result.warning, isNotNull);
      expect(result.warning!.presetId, 'preset-2');
      expect(result.warning!.unknownParameterIds, <String>['unknownA', 'unknownZ']);
      expect(
        result.warning!.toMetadata(),
        <String, Object>{
          'presetId': 'preset-2',
          'unknownParameterIds': <String>['unknownA', 'unknownZ'],
        },
      );
    });
  });
}

import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_application_1/features/live2d/data/models/auto_motion_config.dart';
import 'package:flutter_application_1/features/live2d/data/models/gesture_motion_mapping.dart';
import 'package:flutter_application_1/features/live2d/data/models/live2d_parameter_preset.dart';
import 'package:flutter_application_1/features/live2d/data/models/parameter_alias_map.dart';
import 'package:flutter_application_1/features/live2d/data/repositories/live2d_settings_repository.dart';
import 'package:flutter_application_1/features/live2d/domain/entities/interaction_event.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');

  late Directory tempDir;

  group('Live2DSettingsRepository contract', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      tempDir = await Directory.systemTemp.createTemp('live2d-repo-contract-');

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(pathProviderChannel, (call) async {
        if (call.method == 'getApplicationDocumentsDirectory') {
          return tempDir.path;
        }
        return tempDir.path;
      });
    });

    tearDown(() async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(pathProviderChannel, null);
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('saves and loads auto motion config per model', () async {
      final repo = Live2DSettingsRepository();
      const modelPath = '/models/hiyori/model3.json';

      const config = AutoMotionConfig(
        enabled: true,
        motionGroup: 'Idle',
        intervalSeconds: 15,
        randomMode: false,
        autoExpressionChange: true,
        expressionSelection: 'happy',
      );

      await repo.saveAutoMotionConfig(modelPath, config);
      final loaded = await repo.loadAutoMotionConfig(modelPath);

      expect(loaded, isNotNull);
      expect(loaded!.enabled, isTrue);
      expect(loaded.motionGroup, 'Idle');
      expect(loaded.intervalSeconds, 15);
      expect(loaded.randomMode, isFalse);
      expect(loaded.autoExpressionChange, isTrue);
      expect(loaded.expressionSelection, 'happy');
    });

    test('saves and loads gesture mapping config per model', () async {
      final repo = Live2DSettingsRepository();
      const modelPath = '/models/hiyori/model3.json';

      final config = GestureMotionConfig.defaults().copyWith(
        mappings: <InteractionType, List<GestureMotionEntry>>{
          ...GestureMotionConfig.defaults().mappings,
          InteractionType.doubleTap: const <GestureMotionEntry>[
            GestureMotionEntry(
              id: 'entry-1',
              motionGroup: 'TapBody',
              motionIndex: 0,
              enabled: true,
              priority: 9,
              expressionOverride: 'smile',
            ),
          ],
        },
      );

      await repo.saveGestureMappingConfig(modelPath, config);
      final loaded = await repo.loadGestureMappingConfig(modelPath);

      expect(loaded, isNotNull);
      final entries = loaded!.entriesFor(InteractionType.doubleTap);
      expect(entries, hasLength(1));
      expect(entries.first.motionGroup, 'TapBody');
      expect(entries.first.motionIndex, 0);
      expect(entries.first.priority, 9);
      expect(entries.first.expressionOverride, 'smile');
    });

    test('loads presets against resolved ids and emits unknown id warnings', () async {
      final repo = Live2DSettingsRepository();
      const modelPath = '/models/hiyori/model3.json';

      const presets = <Live2DParameterPreset>[
        Live2DParameterPreset(
          id: 'preset-1',
          name: 'resolved',
          overrides: <String, double>{
            'parameter1': 0.5,
            'ParamMouthOpenY': 0.8,
            'legacyUnknown': 1.0,
          },
        ),
      ];

      await repo.saveParameterPresets(modelPath, presets);
      final aliases = ParameterAliasMap.fromAliasToReal(<String, String>{
        'parameter1': 'ParamEyeLOpen',
      });

      final result = await repo.loadParameterPresetsResolved(
        modelPath,
        resolvedParameterIds: <String>{'ParamEyeLOpen', 'ParamMouthOpenY'},
        aliases: aliases,
      );

      expect(result.presets, hasLength(1));
      expect(result.presets.first.overrides, <String, double>{
        'ParamEyeLOpen': 0.5,
        'ParamMouthOpenY': 0.8,
      });
      expect(result.warnings, hasLength(1));
      expect(result.warnings.first.presetId, 'preset-1');
      expect(result.warnings.first.unknownParameterIds, <String>['legacyUnknown']);
      expect(result.warnings.first.toMetadata(), <String, Object>{
        'presetId': 'preset-1',
        'unknownParameterIds': <String>['legacyUnknown'],
      });
    });
  });
}

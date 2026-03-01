import 'package:flutter_application_1/features/live2d/data/models/auto_motion_config.dart';
import 'package:flutter_application_1/features/live2d/data/models/gesture_motion_mapping.dart';
import 'package:flutter_application_1/features/live2d/data/repositories/live2d_settings_repository.dart';
import 'package:flutter_application_1/features/live2d/domain/entities/interaction_event.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Live2DSettingsRepository contract', () {
    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
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
  });
}

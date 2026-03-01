import 'package:flutter_application_1/features/live2d/data/models/gesture_motion_mapping.dart';
import 'package:flutter_application_1/features/live2d/data/services/gesture_motion_mapper.dart';
import 'package:flutter_application_1/features/live2d/domain/entities/interaction_event.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('GestureMotionMapper', () {
    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
    });

    test('persists and reloads gesture mapping config', () async {
      final mapper = GestureMotionMapper();

      final config = GestureMotionConfig.defaults().copyWith(
        mappings: {
          ...GestureMotionConfig.defaults().mappings,
          InteractionType.doubleTap: <GestureMotionEntry>[
            const GestureMotionEntry(
              id: 'm1',
              motionGroup: 'Idle',
              motionIndex: 1,
              enabled: true,
              priority: 7,
              expressionOverride: 'happy',
            ),
          ],
        },
        randomPerGesture: {
          ...GestureMotionConfig.defaults().randomPerGesture,
          InteractionType.doubleTap: true,
        },
      );

      await mapper.setConfig(config);
      final loaded = await mapper.loadConfig();

      final entries = loaded.entriesFor(InteractionType.doubleTap);
      expect(entries, hasLength(1));
      expect(entries.first.motionGroup, 'Idle');
      expect(entries.first.motionIndex, 1);
      expect(entries.first.priority, 7);
      expect(entries.first.expressionOverride, 'happy');
      expect(loaded.randomEnabled(InteractionType.doubleTap), isTrue);
    });

    test('supports exactly 7 required gesture types', () {
      expect(GestureMotionConfig.supportedGestures, hasLength(7));
      expect(GestureMotionConfig.supportedGestures, contains(InteractionType.tap));
      expect(GestureMotionConfig.supportedGestures, contains(InteractionType.doubleTap));
      expect(GestureMotionConfig.supportedGestures, contains(InteractionType.longPress));
      expect(GestureMotionConfig.supportedGestures, contains(InteractionType.swipeLeft));
      expect(GestureMotionConfig.supportedGestures, contains(InteractionType.swipeRight));
      expect(GestureMotionConfig.supportedGestures, contains(InteractionType.swipeUp));
      expect(GestureMotionConfig.supportedGestures, contains(InteractionType.swipeDown));
    });
  });
}

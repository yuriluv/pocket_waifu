import 'dart:convert';

import 'package:flutter_application_1/features/live2d/data/models/display_config.dart';
import 'package:flutter_application_1/features/live2d/data/services/display_config_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Live2DDisplayConfigStore lifecycle contract', () {
    late Live2DDisplayConfigStore store;

    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      store = Live2DDisplayConfigStore();
      store.clearCache();
    });

    test('save -> simulated relaunch -> load keeps all fields', () async {
      const modelId = 'model-lifecycle-a';
      const original = Live2DDisplayConfig(
        modelId: modelId,
        modelPath: '/models/a.model3.json',
        containerWidthDp: 420,
        containerHeightDp: 360,
        containerXRatio: 0.21,
        containerYRatio: 0.73,
        containerWidthRatio: 0.37,
        containerHeightRatio: 0.41,
        modelScaleX: 1.16,
        modelScaleY: 1.16,
        modelOffsetXRatio: 0.14,
        modelOffsetYRatio: -0.09,
        modelOffsetXDp: 58,
        modelOffsetYDp: -32,
        relativeScaleRatio: 1.16,
        rotationDeg: 9,
      );

      final saveOk = await store.save(original);
      expect(saveOk, isTrue);

      store.clearCache();
      final restored = await store.loadForModel(modelId);

      expect(restored, isNotNull);
      _expectSameConfig(restored!, original);
      expect(restored.schemaVersion, Live2DDisplayConfig.currentSchemaVersion);
    });

    test('lifecycle save/load remains stable for 3 consecutive cycles', () async {
      const modelId = 'model-lifecycle-b';
      var latest = Live2DDisplayConfig.defaultConfig(modelId).copyWith(
        modelPath: '/models/b.model3.json',
        containerXRatio: 0.35,
        containerYRatio: 0.62,
        modelOffsetXDp: 12,
        modelOffsetYDp: -8,
      );

      for (var cycle = 0; cycle < 3; cycle++) {
        latest = latest.copyWith(
          containerXRatio: (0.35 + cycle * 0.1).clamp(0.0, 1.0),
          containerYRatio: (0.62 - cycle * 0.05).clamp(0.0, 1.0),
          rotationDeg: cycle * 5,
          modelOffsetXDp: latest.modelOffsetXDp + (cycle + 1) * 3,
          modelOffsetYDp: latest.modelOffsetYDp - (cycle + 1) * 2,
        );

        final saveOk = await store.save(latest);
        expect(saveOk, isTrue, reason: 'cycle=${cycle + 1} save must succeed');

        store.clearCache();
        final restored = await store.loadForModel(modelId);
        expect(restored, isNotNull, reason: 'cycle=${cycle + 1} load must succeed');
        _expectSameConfig(
          restored!,
          latest,
          reason: 'cycle=${cycle + 1} data mismatch',
        );
      }
    });

    test('old schema data is migrated and persisted to current schema', () async {
      const modelId = 'model-legacy';
      final legacy = Live2DDisplayConfig.defaultConfig(modelId)
          .copyWith(schemaVersion: 1)
          .toJson();
      final payload = jsonEncode(<Map<String, dynamic>>[legacy]);

      SharedPreferences.setMockInitialValues(<String, Object>{
        'live2d_display_configs': payload,
      });
      store = Live2DDisplayConfigStore();
      store.clearCache();

      final loaded = await store.loadForModel(modelId);
      expect(loaded, isNotNull);
      expect(loaded!.schemaVersion, Live2DDisplayConfig.currentSchemaVersion);

      store.clearCache();
      final reloaded = await store.loadForModel(modelId);
      expect(reloaded, isNotNull);
      expect(reloaded!.schemaVersion, Live2DDisplayConfig.currentSchemaVersion);
    });
  });
}

void _expectSameConfig(
  Live2DDisplayConfig actual,
  Live2DDisplayConfig expected, {
  String? reason,
}) {
  expect(actual.modelId, expected.modelId, reason: reason);
  expect(actual.modelPath, expected.modelPath, reason: reason);
  expect(actual.containerWidthDp, closeTo(expected.containerWidthDp, 0.0001), reason: reason);
  expect(actual.containerHeightDp, closeTo(expected.containerHeightDp, 0.0001), reason: reason);
  expect(actual.containerXRatio, closeTo(expected.containerXRatio, 0.0001), reason: reason);
  expect(actual.containerYRatio, closeTo(expected.containerYRatio, 0.0001), reason: reason);
  expect(actual.containerWidthRatio, closeTo(expected.containerWidthRatio, 0.0001), reason: reason);
  expect(actual.containerHeightRatio, closeTo(expected.containerHeightRatio, 0.0001), reason: reason);
  expect(actual.modelScaleX, closeTo(expected.modelScaleX, 0.0001), reason: reason);
  expect(actual.modelScaleY, closeTo(expected.modelScaleY, 0.0001), reason: reason);
  expect(actual.modelOffsetXRatio, closeTo(expected.modelOffsetXRatio, 0.0001), reason: reason);
  expect(actual.modelOffsetYRatio, closeTo(expected.modelOffsetYRatio, 0.0001), reason: reason);
  expect(actual.modelOffsetXDp, closeTo(expected.modelOffsetXDp, 0.0001), reason: reason);
  expect(actual.modelOffsetYDp, closeTo(expected.modelOffsetYDp, 0.0001), reason: reason);
  expect(actual.relativeScaleRatio, closeTo(expected.relativeScaleRatio, 0.0001), reason: reason);
  expect(actual.rotationDeg, expected.rotationDeg, reason: reason);
}

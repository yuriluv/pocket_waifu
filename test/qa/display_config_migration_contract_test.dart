import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/features/live2d/data/models/display_config.dart';

void main() {
  group('Live2DDisplayConfig legacy compatibility', () {
    test('loads canonical Part1 keys and derives normalized ratios', () {
      final config = Live2DDisplayConfig.fromJson({
        'schemaVersion': 1,
        'modelId': 'model-alpha',
        'containerWidth': 320,
        'containerHeight': 400,
        'containerX': 0.25,
        'containerY': 0.75,
        'modelScaleX': 1.1,
        'modelScaleY': 1.1,
        'modelOffsetX': 40,
        'modelOffsetY': -20,
        'relativeScaleRatio': 1.1,
        'rotationDeg': 15,
      });

      expect(config.modelId, 'model-alpha');
      expect(config.containerWidthDp, 320);
      expect(config.containerHeightDp, 400);
      expect(config.containerXRatio, 0.25);
      expect(config.containerYRatio, 0.75);
      expect(config.modelOffsetXRatio, closeTo(0.125, 0.0001));
      expect(config.modelOffsetYRatio, closeTo(-0.05, 0.0001));

      final normalized = config.normalizeWithScreen(1280, 1600, 2.0);
      expect(normalized.containerWidthRatio, closeTo(0.5, 0.0001));
      expect(normalized.containerHeightRatio, closeTo(0.5, 0.0001));
      expect(normalized.modelOffsetXDp, closeTo(40, 0.001));
      expect(normalized.modelOffsetYDp, closeTo(-20, 0.001));
    });

    test('exports both canonical and backward-compatible keys', () {
      const config = Live2DDisplayConfig(
        modelId: 'model-beta',
        modelPath: '/tmp/model-beta.model3.json',
        containerWidthDp: 300,
        containerHeightDp: 450,
        containerXRatio: 0.4,
        containerYRatio: 0.6,
        containerWidthRatio: 0.3,
        containerHeightRatio: 0.45,
        modelScaleX: 1.2,
        modelScaleY: 1.2,
        modelOffsetXRatio: 0.1,
        modelOffsetYRatio: -0.1,
        modelOffsetXDp: 30,
        modelOffsetYDp: -45,
        relativeScaleRatio: 1.2,
        rotationDeg: 5,
      );

      final json = config.toJson();
      expect(json['schemaVersion'], Live2DDisplayConfig.currentSchemaVersion);
      expect(json['containerWidth'], 300.0);
      expect(json['containerHeight'], 450.0);
      expect(json['containerX'], 0.4);
      expect(json['containerY'], 0.6);
      expect(json['modelOffsetX'], 30.0);
      expect(json['modelOffsetY'], -45.0);
      expect(json['containerWidthDp'], 300.0);
      expect(json['containerHeightDp'], 450.0);
      expect(json['modelOffsetXDp'], 30.0);
      expect(json['modelOffsetYDp'], -45.0);
    });
  });
}

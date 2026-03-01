import 'package:flutter_application_1/features/live2d/data/services/model3_json_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Model3JsonParser', () {
    final parser = Model3JsonParser();

    test('parses Hiyori-style model3 FileReferences structure', () {
      const raw = '''
{
  "Version": 3,
  "FileReferences": {
    "Motions": {
      "Idle": [
        {"File": "motions/idle_01.motion3.json"},
        {"File": "motions/idle_02.motion3.json"}
      ],
      "TapBody": [
        {"File": "motions/tap_01.motion3.json"}
      ]
    },
    "Expressions": [
      {"Name": "happy", "File": "expressions/happy.exp3.json"},
      {"Name": "sad", "File": "expressions/sad.exp3.json"}
    ]
  },
  "Parameters": [
    {"Id": "ParamEyeLOpen", "Name": "Eye L", "Min": 0, "Default": 1, "Max": 1},
    {"Id": "ParamMouthOpenY", "Name": "Mouth Open", "Min": 0, "Default": 0, "Max": 1}
  ],
  "HitAreas": [
    {"Name": "Head", "Id": "HitAreaHead"},
    {"Name": "Body", "Id": "HitAreaBody"}
  ]
}
''';

      final data = parser.parseContent(raw, source: 'hiyori_sample');

      expect(data.motionGroups.keys, containsAll(<String>['Idle', 'TapBody']));
      expect(data.motionGroups['Idle'], hasLength(2));
      expect(data.motionGroups['TapBody'], hasLength(1));
      expect(data.expressions.map((e) => e.name), containsAll(<String>['happy', 'sad']));
      expect(data.parameters.map((p) => p.id), contains('ParamEyeLOpen'));
      expect(data.parameters.map((p) => p.id), contains('ParamMouthOpenY'));
      expect(data.hitAreas.map((h) => h.name), containsAll(<String>['Head', 'Body']));
    });

    test('parses custom structure with root-level Motions/Expressions', () {
      const raw = '''
{
  "Motions": {
    "Idle": [
      {"File": "motion/idleA.motion3.json"}
    ],
    "Wave": [
      {"File": "motion/waveA.motion3.json"},
      {"File": "motion/waveB.motion3.json"}
    ]
  },
  "Expressions": [
    {"File": "exp/default.exp3.json"}
  ],
  "Parameters": [
    {"Id": "ParamAngleX", "Min": -30, "Default": 0, "Max": 30}
  ],
  "HitAreas": [
    {"Name": "Face", "Id": "HitFace"}
  ]
}
''';

      final data = parser.parseContent(raw, source: 'custom_sample');

      expect(data.motionGroups['Idle'], equals(<String>['motion/idleA.motion3.json']));
      expect(data.motionGroups['Wave'], hasLength(2));
      expect(data.expressions, hasLength(1));
      expect(data.expressions.first.filePath, 'exp/default.exp3.json');
      expect(data.expressions.first.name, 'exp/default.exp3.json');
      expect(data.parameters, hasLength(1));
      expect(data.parameters.first.id, 'ParamAngleX');
      expect(data.parameters.first.min, -30);
      expect(data.parameters.first.max, 30);
      expect(data.hitAreas.single.meshIds, equals(<String>['HitFace']));
    });

    test('returns empty data for malformed json', () {
      const raw = '{"FileReferences": {"Motions": [';

      final data = parser.parseContent(raw, source: 'malformed');

      expect(data.motionGroups, isEmpty);
      expect(data.expressions, isEmpty);
      expect(data.parameters, isEmpty);
      expect(data.hitAreas, isEmpty);
    });
  });
}

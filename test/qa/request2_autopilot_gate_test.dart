import 'package:flutter_test/flutter_test.dart';

import '../../tool/qa/check_request2_autopilot.dart' as gate;

void main() {
  group('request2 autopilot gate', () {
    test('passes valid Part1-in-progress payload', () {
      final payload = _basePayload();

      final result = gate.validateAutopilotStatus(payload);

      expect(result.errors, isEmpty);
      expect(result.warnings, isEmpty);
    });

    test('fails when failure category is invalid and repro logging delayed', () {
      final payload = _basePayload();
      payload['failures'] = [
        {
          'category': 'network',
          'detectedAt': '2026-02-27T10:00:00Z',
          'reproCapturedAt': '2026-02-27T10:22:00Z',
        },
      ];

      final result = gate.validateAutopilotStatus(payload);

      expect(result.errors, isNotEmpty);
      expect(
        result.errors.any((error) => error.contains('category must be one of')),
        isTrue,
      );
      expect(
        result.errors.any((error) => error.contains('exceeded 10 minutes')),
        isTrue,
      );
    });

    test('fails when Part1 is completed but gate conditions are not met', () {
      final payload = _basePayload();
      payload['part1'] = {
        'status': 'completed',
        'priority': 'highest',
        'gate': {
          'functionalPass': true,
          'regressionFailures': 1,
          'rerunSuccessStreak': 1,
          'passed': true,
        },
      };

      final result = gate.validateAutopilotStatus(payload);

      expect(result.errors, isNotEmpty);
      expect(
        result.errors.any((error) => error.contains('cannot be completed unless gate conditions pass')),
        isTrue,
      );
    });

    test('fails on docs-only code changes', () {
      final payload = _basePayload();
      payload['codeChanges'] = [
        {'path': 'docs/request2.md', 'commit': '1a2b3c4'},
      ];

      final result = gate.validateAutopilotStatus(payload);

      expect(result.errors, isNotEmpty);
      expect(
        result.errors.any((error) => error.contains('cannot be docs-only')),
        isTrue,
      );
    });
  });
}

Map<String, dynamic> _basePayload() {
  return {
    'cycle': {
      'startedAt': '2026-02-27T10:00:00Z',
      'checkedAt': '2026-02-27T10:30:00Z',
    },
    'part1': {
      'status': 'in_progress',
      'priority': 'highest',
      'gate': {
        'functionalPass': false,
        'regressionFailures': 0,
        'rerunSuccessStreak': 0,
        'passed': false,
      },
    },
    'part2': {'loopActive': false},
    'agents': {'activeCount': 3},
    'failures': [
      {
        'category': 'code',
        'detectedAt': '2026-02-27T10:12:00Z',
        'reproCapturedAt': '2026-02-27T10:20:00Z',
      },
    ],
    'evidence': {
      'executionLog': 'https://ci.example/log/100',
      'testReport': 'https://ci.example/test/100',
      'mainPush': 'https://github.com/yuriluv/pocket_waifu/commit/1a2b3c4',
      'codeDiff': 'https://github.com/yuriluv/pocket_waifu/pull/55/files',
      'followUpTask': 'https://tracker.example/task/200',
      'mainPushBranch': 'main',
      'mainPushCommit': '1a2b3c4',
    },
    'codeChanges': [
      {'path': 'tool/qa/check_request2_autopilot.dart', 'commit': '1a2b3c4'},
    ],
  };
}

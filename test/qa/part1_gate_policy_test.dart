import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Part1 gate policy contract', () {
    test('Part2 tests remain frozen until Part1 is complete', () {
      final part1Complete = Platform.environment['PART1_COMPLETE'] == 'true';
      if (part1Complete) {
        return;
      }

      final part2Contract = File('test/qa/part2_contract_test.dart').readAsStringSync();
      final totalTests = RegExp(r'\btest\s*\(').allMatches(part2Contract).length;
      final skippedTests = RegExp(r'\bskip\s*:').allMatches(part2Contract).length;

      expect(totalTests, greaterThan(0));
      expect(
        skippedTests,
        totalTests,
        reason: 'Part1 incomplete state requires Part2 test surface freeze.',
      );
    });

    test('request2 keeps explicit Part2 start condition linked to Part1 completion', () {
      final request2 = File('docs/request2.md').readAsStringSync();

      expect(
        request2.contains('The tasks in Part 2 shall only commence'),
        isTrue,
        reason: 'Part2 activation must be blocked by explicit Part1 completion text.',
      );
    });
  });
}

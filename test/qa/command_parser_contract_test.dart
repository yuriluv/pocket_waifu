import 'package:flutter_application_1/services/command_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CommandParser contract', () {
    test('returns non-command tuple for plain text', () {
      final result = CommandParser.parse('hello there');

      expect(result.$1, isFalse);
      expect(result.$2, isNull);
    });

    test('parses delete range command with index metadata', () {
      final result = CommandParser.parse('/del 2~4');

      expect(result.$1, isTrue);
      expect(result.$2, isNotNull);
      expect(result.$2!.type, CommandType.delete);
      expect(result.$2!.success, isTrue);
      expect(result.$2!.isRange, isTrue);
      expect(result.$2!.index, 2);
      expect(result.$2!.endIndex, 4);
    });

    test('parses unknown command as failed unknown result', () {
      final result = CommandParser.parse('/does-not-exist');

      expect(result.$1, isTrue);
      expect(result.$2, isNotNull);
      expect(result.$2!.type, CommandType.unknown);
      expect(result.$2!.success, isFalse);
    });

    test('parses command with leading and trailing whitespace', () {
      final result = CommandParser.parse('   /del 3   ');

      expect(result.$1, isTrue);
      expect(result.$2, isNotNull);
      expect(result.$2!.type, CommandType.delete);
      expect(result.$2!.success, isTrue);
      expect(result.$2!.index, 3);
    });

    test('parses send command with multiple spaces between args', () {
      final result = CommandParser.parse('/send   hello   world');

      expect(result.$1, isTrue);
      expect(result.$2, isNotNull);
      expect(result.$2!.type, CommandType.send);
      expect(result.$2!.success, isTrue);
      expect(result.$2!.content, 'hello world');
    });
  });
}

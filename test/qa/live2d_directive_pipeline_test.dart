import 'dart:math';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/features/live2d_llm/services/live2d_directive_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('com.example.flutter_application_1/live2d');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  final methodCalls = <MethodCall>[];

  setUp(() {
    methodCalls.clear();
    messenger.setMockMethodCallHandler(channel, (call) async {
      methodCalls.add(call);
      switch (call.method) {
        case 'getModelInfo':
          return {
            'parameters': [
              {'id': 'ParamEyeLOpen', 'min': 0.0, 'max': 1.0},
            ],
          };
        case 'setExpression':
          final args = Map<String, dynamic>.from(call.arguments as Map);
          return args['id'] != 'nonexistent';
        case 'setParameter':
        case 'playMotion':
          return true;
        default:
          return null;
      }
    });
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
  });

  group('Live2DDirectiveService', () {
    test('strips live2d blocks from assistant output', () async {
      final service = Live2DDirectiveService.instance;
      final result = await service.processAssistantOutput(
        'hello<live2d><expression id="happy"/></live2d>world',
      );

      expect(result.cleanedText, 'helloworld');
    });

    test('strips tags and blocks when parsing is disabled', () async {
      final service = Live2DDirectiveService.instance;
      final input = 'a<live2d><motion group="Idle" index="0"/></live2d>b';
      final result = await service.processAssistantOutput(
        input,
        parsingEnabled: false,
      );

      expect(result.cleanedText, 'ab');
      expect(methodCalls.where((c) => c.method == 'playMotion'), isEmpty);
    });

    test('buffers stream chunks until complete block is formed', () async {
      final service = Live2DDirectiveService.instance;
      service.resetStreamBuffer();

      final first = await service.pushStreamChunk('start<live2d><param id="P"');
      expect(first.cleanedText, contains('<live2d>'));

      final second = await service.pushStreamChunk(
        ' value="0.2"/></live2d>end',
      );
      expect(second.cleanedText, contains('start'));
      expect(second.cleanedText, contains('end'));
      expect(second.cleanedText, isNot(contains('<live2d>')));
    });

    test('strips lua-live2d fenced blocks from assistant output', () async {
      final service = Live2DDirectiveService.instance;
      final input = 'hello\n```lua-live2d\nplayMotion("Idle", 0)\n```\nworld';

      final result = await service.processAssistantOutput(input);

      expect(result.cleanedText, contains('hello'));
      expect(result.cleanedText, contains('world'));
      expect(result.cleanedText, isNot(contains('lua-live2d')));
      expect(result.cleanedText, isNot(contains('playMotion')));
    });

    test('flushes dangling inline tag buffer when length exceeds threshold', () async {
      final service = Live2DDirectiveService.instance;
      service.resetStreamBuffer();

      final longChunk = '[motion:Idle/0${List.filled(120, 'a').join()}';
      final result = await service.pushStreamChunk(longChunk);

      expect(result.cleanedText, contains('[motion:Idle/0'));
      expect(result.cleanedText.length, greaterThan(100));
    });

    test('parses split inline tag across chunks correctly', () async {
      final service = Live2DDirectiveService.instance;
      service.resetStreamBuffer();

      final first = await service.pushStreamChunk('Hello [motion:Idle');
      expect(first.cleanedText, contains('[motion:Idle'));

      final second = await service.pushStreamChunk('/0] world');
      expect(second.cleanedText, contains('Hello'));
      expect(second.cleanedText, contains('world'));
      expect(second.cleanedText, isNot(contains('[motion:')));
      expect(methodCalls.where((c) => c.method == 'playMotion'), isNotEmpty);
    });

    test('clamps out-of-range param values before dispatch', () async {
      final service = Live2DDirectiveService.instance;
      final result = await service.processAssistantOutput(
        '[param:ParamEyeLOpen=5.0]',
      );

      expect(result.cleanedText, isEmpty);

      final setParamCall = methodCalls.lastWhere(
        (c) => c.method == 'setParameter',
      );
      final args = Map<String, dynamic>.from(setParamCall.arguments as Map);
      expect(args['id'], 'ParamEyeLOpen');
      expect(args['value'], 1.0);
    });

    test('nonexistent expression does not crash and still strips tag', () async {
      final service = Live2DDirectiveService.instance;
      final result = await service.processAssistantOutput(
        'Text [expression:nonexistent] tail',
      );

      expect(result.cleanedText, contains('Text'));
      expect(result.cleanedText, contains('tail'));
      expect(result.cleanedText, isNot(contains('[expression:')));
    });

    test('renders directive chips when raw directive debug mode is enabled', () async {
      final service = Live2DDirectiveService.instance;
      final result = await service.processAssistantOutput(
        'Hello [motion:Idle/0] [expression:happy]',
        exposeRawDirectives: true,
      );

      expect(result.cleanedText, contains('⟦motion:Idle/0⟧'));
      expect(result.cleanedText, contains('⟦expression:happy⟧'));
    });

    test('fuzz split streaming chunks preserves parsing correctness', () async {
      final service = Live2DDirectiveService.instance;
      final random = Random(42);
      const source =
          'Hello [motion:Idle/0] world [param:ParamEyeLOpen=0.8] !';

      final expected = await service.processAssistantOutput(source);

      for (var i = 0; i < 100; i++) {
        service.resetStreamBuffer();
        var offset = 0;
        Live2DDirectiveResult? last;

        while (offset < source.length) {
          final chunkSize = random.nextInt(20) + 1;
          final end = (offset + chunkSize).clamp(0, source.length);
          final chunk = source.substring(offset, end);
          last = await service.pushStreamChunk(chunk);
          offset = end;
        }

        expect(last, isNotNull);
        final normalizedActual = last!.cleanedText.replaceAll(RegExp(r'\s+'), '');
        final normalizedExpected =
            expected.cleanedText.replaceAll(RegExp(r'\s+'), '');
        expect(normalizedActual, normalizedExpected);
      }
    });
  });
}

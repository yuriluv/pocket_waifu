import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/features/live2d_llm/services/live2d_directive_service.dart';

void main() {
  group('Live2DDirectiveService', () {
    test('strips live2d blocks from assistant output', () async {
      final service = Live2DDirectiveService.instance;
      final result = await service.processAssistantOutput(
        'hello<live2d><expression id="happy"/></live2d>world',
      );

      expect(result.cleanedText, 'helloworld');
    });

    test('keeps text unchanged when parsing is disabled', () async {
      final service = Live2DDirectiveService.instance;
      final input = 'a<live2d><motion group="Idle" index="0"/></live2d>b';
      final result = await service.processAssistantOutput(
        input,
        parsingEnabled: false,
      );

      expect(result.cleanedText, input);
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
  });
}

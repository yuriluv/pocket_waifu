import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/models/api_config.dart';
import 'package:flutter_application_1/models/settings.dart';
import 'package:flutter_application_1/services/api_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ApiService preset parameter contract', () {
    test('openai-compatible requests prefer preset-owned parameters', () {
      final service = ApiService();
      final apiConfig = ApiConfig.openaiDefault().copyWith(
        additionalParams: {
          'temperature': 0.2,
          'top_p': 0.7,
          'max_output_tokens': 321,
          'frequency_penalty': 0.4,
          'presence_penalty': 0.6,
        },
      );

      final body = service.buildOpenAICompatibleRequestBodyForTest(
        apiConfig: apiConfig,
        messages: const [
          {'role': 'user', 'content': 'hello'},
        ],
        settings: AppSettings(
          temperature: 1.9,
          topP: 0.1,
          maxTokens: 9999,
          frequencyPenalty: 1.1,
          presencePenalty: 1.2,
        ),
      );

      expect(body['temperature'], 0.2);
      expect(body['top_p'], 0.7);
      expect(body['max_output_tokens'], 321);
      expect(body['frequency_penalty'], 0.4);
      expect(body['presence_penalty'], 0.6);
    });
  });

  group('ApiService cancellation contract', () {
    test('cancelled request handle short-circuits sendMessageWithConfig', () async {
      final service = ApiService();
      final requestHandle = service.createRequestHandle();
      requestHandle.cancel();

      final apiConfig = ApiConfig.openaiDefault().copyWith(
        apiKey: 'test-key',
        baseUrl: 'https://example.com/v1/chat/completions',
        modelName: 'gpt-4o-mini',
      );

      await expectLater(
        service.sendMessageWithConfig(
          apiConfig: apiConfig,
          messages: const [
            {'role': 'user', 'content': 'hello'},
          ],
          settings: AppSettings.fromMap({}),
          requestHandle: requestHandle,
        ),
        throwsA(isA<ApiCancelledException>()),
      );
    });

    test('cancel can be called repeatedly without throwing', () {
      final service = ApiService();
      final requestHandle = service.createRequestHandle();

      requestHandle.cancel();
      requestHandle.cancel();

      expect(requestHandle.isCancelled, isTrue);
    });
  });
}

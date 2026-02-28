import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/models/api_config.dart';
import 'package:flutter_application_1/models/settings.dart';
import 'package:flutter_application_1/services/api_service.dart';

void main() {
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

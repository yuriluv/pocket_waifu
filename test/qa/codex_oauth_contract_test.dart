import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/models/api_config.dart';
import 'package:flutter_application_1/models/oauth_account.dart';
import 'package:flutter_application_1/services/api_service.dart';
import 'package:flutter_application_1/services/oauth_account_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Codex OAuth contract', () {
    test('authorization URL matches official Codex query shape', () async {
      final session = await OAuthAccountService.instance.beginAuthorization(
        provider: OAuthAccountProvider.codex,
      );

      addTearDown(session.dispose);

      final query = session.authUrl.queryParameters;
      expect(query['client_id'], 'app_EMoamEEZ73f0CkXaXp7hrann');
      expect(query['redirect_uri'], 'http://localhost:1455/auth/callback');
      expect(query['codex_cli_simplified_flow'], 'true');
      expect(query['id_token_add_organizations'], 'true');
      expect(query['originator'], 'codex_cli_rs');

      final scope = query['scope'];
      expect(scope, isNotNull);
      expect(scope, contains('openid'));
      expect(scope, contains('offline_access'));
      expect(scope, contains('api.connectors.read'));
      expect(scope, contains('api.connectors.invoke'));
    });

    test('responses request sends instructions and strips system messages from input', () async {
      final service = ApiService();
      final config = ApiConfig(
        name: 'Codex Test',
        baseUrl: 'https://chatgpt.com/backend-api/codex/responses',
        apiKey: 'test-token',
        modelName: 'gpt-5.3-codex',
        format: ApiFormat.openAIResponses,
        additionalParams: const {},
        hasFirstSystemPrompt: true,
        requiresAlternateRole: false,
      );

      final requestBody = service.buildOpenAIResponsesRequestBodyForTest(
        apiConfig: config,
        messages: const [
          {'role': 'system', 'content': 'Follow system rules.'},
          {'role': 'user', 'content': 'hello'},
        ],
      );

      expect(requestBody['instructions'], 'Follow system rules.');
      expect(requestBody['store'], false);
      expect(requestBody['stream'], true);
      expect(requestBody.containsKey('temperature'), isFalse);
      expect(requestBody.containsKey('top_p'), isFalse);
      expect(requestBody.containsKey('max_output_tokens'), isFalse);

      final input = requestBody['input'] as List<dynamic>;
      expect(input, hasLength(1));
      expect(input.single['role'], 'user');
    });

    test('responses request falls back to default instructions when none exist', () async {
      final service = ApiService();
      final config = ApiConfig(
        name: 'Codex Test',
        baseUrl: 'https://chatgpt.com/backend-api/codex/responses',
        apiKey: 'test-token',
        modelName: 'gpt-5.3-codex',
        format: ApiFormat.openAIResponses,
        additionalParams: const {},
      );

      final requestBody = service.buildOpenAIResponsesRequestBodyForTest(
        apiConfig: config,
        messages: const [
          {'role': 'user', 'content': 'hello'},
        ],
      );

      expect(requestBody['instructions'], 'You are a helpful assistant.');
    });

    test('responses headers include Codex-specific headers when account metadata exists', () {
      final service = ApiService();
      final config = ApiConfig.codexOAuth(
        oauthAccountId: 'oauth-1',
        modelName: 'gpt-5.3-codex',
      );
      final account = OAuthAccount(
        id: 'oauth-1',
        provider: OAuthAccountProvider.codex,
        label: 'Codex',
        accessToken: 'token',
        chatgptAccountId: 'acc_123',
      );

      final headers = service.buildOpenAIResponsesHeadersForTest(
        apiConfig: config,
        authToken: 'token',
        oauthAccount: account,
      );

      expect(headers['Authorization'], 'Bearer token');
      expect(headers['Content-Type'], 'application/json');
      expect(headers['Accept'], 'text/event-stream');
      expect(headers['originator'], 'codex_cli_rs');
      expect(headers['OpenAI-Beta'], 'responses=experimental');
      expect(headers['ChatGPT-Account-Id'], 'acc_123');
    });

    test('responses parser extracts text from event stream payloads', () {
      final service = ApiService();
      const body = 'event: response.output_text.delta\n'
          'data: {"type":"response.output_text.delta","delta":"Hel"}\n\n'
          'event: response.output_text.delta\n'
          'data: {"type":"response.output_text.delta","delta":"lo"}\n\n'
          'event: response.completed\n'
          'data: {"type":"response.completed","response":{"output_text":"Hello"}}\n\n'
          'data: [DONE]\n';

      final content = service.extractResponsesResponseContentForTest(
        responseBody: body,
        contentType: 'text/event-stream; charset=utf-8',
      );

      expect(content, 'Hello');
    });
  });
}

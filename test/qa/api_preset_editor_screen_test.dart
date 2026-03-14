import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_application_1/models/api_config.dart';
import 'package:flutter_application_1/models/oauth_account.dart';
import 'package:flutter_application_1/providers/settings_provider.dart';
import 'package:flutter_application_1/screens/api_preset_editor_screen.dart';
import 'package:flutter_application_1/utils/api_preset_parameter_policy.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ApiPresetEditorScreen', () {
    testWidgets('standard preset editor does not expose unsupported formats', (
      tester,
    ) async {
      expect(
        ApiPresetParameterPolicy.supportedStandardFormats,
        contains(ApiFormat.openAICompatible),
      );
      expect(
        ApiPresetParameterPolicy.supportedStandardFormats,
        contains(ApiFormat.anthropic),
      );
      expect(
        ApiPresetParameterPolicy.supportedStandardFormats,
        contains(ApiFormat.openRouter),
      );
      expect(
        ApiPresetParameterPolicy.supportedStandardFormats,
        contains(ApiFormat.custom),
      );
      expect(
        ApiPresetParameterPolicy.supportedStandardFormats,
        isNot(contains(ApiFormat.google)),
      );
      expect(
        ApiPresetParameterPolicy.supportedStandardFormats,
        isNot(contains(ApiFormat.openAIResponses)),
      );
    });

    testWidgets('gemini oauth save clears stale preset project id', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final account = OAuthAccount(
        id: 'oauth-1',
        provider: OAuthAccountProvider.geminiGca,
        label: 'Gemini',
        accessToken: 'token',
      );
      final provider = _FakeSettingsProvider([account]);
      final existingConfig = ApiConfig.geminiCodeAssistOAuth(
        oauthAccountId: account.id,
        modelName: 'gemini-2.5-pro',
        name: 'Gemini OAuth',
      ).copyWith(
        additionalParams: {
          'googleCloudProject': 'old-project',
          'temperature': 0.5,
        },
      );

      ApiConfig? savedResult;

      await tester.pumpWidget(
        ChangeNotifierProvider<SettingsProvider>.value(
          value: provider,
          child: MaterialApp(
            home: Builder(
              builder: (context) {
                return Scaffold(
                  body: Center(
                    child: ElevatedButton(
                      onPressed: () async {
                        savedResult = await Navigator.of(context).push<ApiConfig>(
                          MaterialPageRoute(
                            builder: (_) => ApiPresetEditorScreen(
                              existingConfig: existingConfig,
                            ),
                          ),
                        );
                      },
                      child: const Text('open'),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('프리셋 저장'));
      await tester.pumpAndSettle();

      expect(savedResult, isNotNull);
      expect(savedResult!.additionalParams.containsKey('googleCloudProject'), isFalse);
    });
  });
}

class _FakeSettingsProvider extends SettingsProvider {
  _FakeSettingsProvider(this._accounts);

  final List<OAuthAccount> _accounts;

  @override
  List<OAuthAccount> get oauthAccounts => List.unmodifiable(_accounts);

  @override
  OAuthAccount? getOAuthAccountById(String? id) {
    if (id == null) {
      return null;
    }
    for (final account in _accounts) {
      if (account.id == id) {
        return account;
      }
    }
    return null;
  }

  @override
  Future<void> reloadOAuthAccounts() async {}
}

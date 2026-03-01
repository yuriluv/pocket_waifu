import 'package:flutter_application_1/providers/screen_share_provider.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ScreenShare settings contract', () {
    const channel = MethodChannel('com.pocketwaifu/screen_capture');

    setUp(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        switch (call.method) {
          case 'hasPermission':
            return false;
          case 'requestPermission':
            return true;
          case 'release':
            return null;
          default:
            return null;
        }
      });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test('fresh install defaults are applied', () async {
      SharedPreferences.setMockInitialValues({});

      final provider = ScreenShareProvider();
      await provider.load();

      expect(provider.settings.enabled, isFalse);
      expect(provider.settings.captureInterval, 60);
      expect(provider.settings.autoCapture, isFalse);
      expect(provider.settings.maxResolution, 1080);
    });

    test('settings persist across provider reload', () async {
      SharedPreferences.setMockInitialValues({});

      final provider = ScreenShareProvider();
      await provider.load();
      await provider.setEnabled(true);
      await provider.setCaptureInterval(90);
      await provider.setAutoCapture(true);
      await provider.setMaxResolution(1440);

      final reloaded = ScreenShareProvider();
      await reloaded.load();

      expect(reloaded.settings.enabled, isTrue);
      expect(reloaded.settings.captureInterval, 90);
      expect(reloaded.settings.autoCapture, isTrue);
      expect(reloaded.settings.maxResolution, 1440);
    });
  });
}

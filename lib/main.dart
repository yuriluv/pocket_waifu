// ============================================================================
// ============================================================================
//
// ============================================================================

import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/chat_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/prompt_block_provider.dart';
import 'providers/chat_session_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/global_runtime_provider.dart';
import 'providers/notification_settings_provider.dart';
import 'providers/prompt_preset_provider.dart';
import 'services/release_log_service.dart';
import 'services/notification_bridge.dart';
import 'services/notification_coordinator.dart';
import 'services/proactive_response_service.dart';
import 'services/live2d_global_runtime_handler.dart';
import 'services/global_runtime_registry.dart';

import 'screens/chat_screen.dart';



Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await ReleaseLogService.instance.initialize();

  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    final exceptionType = details.exception.runtimeType.toString();
    final stackHead = details.stack?.toString().split('\n').first ?? 'no_stack';
    unawaited(
      ReleaseLogService.instance.error(
        'flutter_error',
        'Unhandled Flutter framework exception',
        payload: {
          'errorType': exceptionType,
          'reason': stackHead,
          'buildType': kReleaseMode ? 'release' : 'debug',
        },
      ),
    );
  };

  PlatformDispatcher.instance.onError = (Object error, StackTrace stackTrace) {
    final stackHead = stackTrace.toString().split('\n').first;
    unawaited(
      ReleaseLogService.instance.error(
        'platform_error',
        'Unhandled platform exception',
        payload: {
          'errorType': error.runtimeType.toString(),
          'reason': stackHead,
          'buildType': kReleaseMode ? 'release' : 'debug',
        },
      ),
    );
    return false;
  };

  runApp(const PocketWaifuApp());
}

class PocketWaifuApp extends StatelessWidget {
  const PocketWaifuApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SettingsProvider()),

        ChangeNotifierProvider(create: (_) => ChatProvider()),

        ChangeNotifierProvider(create: (_) => PromptBlockProvider()),

        ChangeNotifierProvider(create: (_) => ChatSessionProvider()),

        ChangeNotifierProvider(create: (_) => ThemeProvider()),

        ChangeNotifierProvider(create: (_) => GlobalRuntimeProvider()),

        ChangeNotifierProvider(create: (_) => NotificationSettingsProvider()),

        ChangeNotifierProvider(create: (_) => PromptPresetProvider()),

        Provider(
          create: (_) {
            final handler = Live2DGlobalRuntimeHandler();
            GlobalRuntimeRegistry.instance.register(handler);
            return handler;
          },
          dispose: (_, handler) =>
              GlobalRuntimeRegistry.instance.unregister(handler),
        ),

        ProxyProvider5<SettingsProvider, PromptBlockProvider,
            ChatSessionProvider, NotificationSettingsProvider,
            GlobalRuntimeProvider, NotificationCoordinator>(
          create: (_) =>
              NotificationCoordinator(bridge: NotificationBridge.instance),
          update: (context, settings, prompt, sessions, notificationSettings,
              globalRuntime, coordinator) {
            final instance = coordinator ??
                NotificationCoordinator(bridge: NotificationBridge.instance);
            notificationSettings.rebindApiPresets(settings.apiConfigs);
            notificationSettings.rebindPromptPresets(
              context.read<PromptPresetProvider>().presets,
            );
            instance.attach(
              settingsProvider: settings,
              promptBlockProvider: prompt,
              sessionProvider: sessions,
              notificationSettingsProvider: notificationSettings,
              globalRuntimeProvider: globalRuntime,
            );
            return instance;
          },
          dispose: (_, coordinator) => coordinator.dispose(),
        ),

        ProxyProvider4<NotificationCoordinator, GlobalRuntimeProvider,
            NotificationSettingsProvider, SettingsProvider,
            ProactiveResponseService>(
          create: (context) =>
              ProactiveResponseService(context.read<NotificationCoordinator>()),
          update: (_, coordinator, globalRuntime, notificationSettings,
              settingsProvider, service) {
            final instance =
                service ?? ProactiveResponseService(coordinator);
            instance.attach(
              globalRuntimeProvider: globalRuntime,
              notificationSettingsProvider: notificationSettings,
              settingsProvider: settingsProvider,
            );
            return instance;
          },
        ),
      ],
      child: const _AppWithTheme(),
    );
  }
}

class _AppWithTheme extends StatelessWidget {
  const _AppWithTheme();

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return MaterialApp(
      title: 'Pocket Waifu',

      debugShowCheckedModeBanner: false,

      theme: themeProvider.getThemeData(isDark: false),

      darkTheme: themeProvider.getThemeData(isDark: true),

      themeMode: themeProvider.themeMode,

      home: const ChatScreen(),
    );
  }
}

// ============================================================================
// ============================================================================
//
// ============================================================================

import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/chat_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/prompt_block_provider.dart';
import 'providers/chat_session_provider.dart';
import 'providers/theme_provider.dart';
import 'services/release_log_service.dart';

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

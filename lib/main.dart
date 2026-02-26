// ============================================================================
// ============================================================================
//
// ============================================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/chat_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/prompt_block_provider.dart';
import 'providers/chat_session_provider.dart';
import 'providers/theme_provider.dart';

import 'screens/chat_screen.dart';



void main() {
  WidgetsFlutterBinding.ensureInitialized();

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

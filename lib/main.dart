// ============================================================================
// ============================================================================
//
// ============================================================================

import 'dart:async';

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
import 'providers/agent_prompt_preset_provider.dart';
import 'providers/screen_share_provider.dart';
import 'providers/screen_capture_provider.dart';
import 'services/release_log_service.dart';
import 'services/unified_capture_service.dart';
import 'services/notification_bridge.dart';
import 'services/notification_coordinator.dart';
import 'services/proactive_response_service.dart';
import 'services/agent_mode_service.dart';
import 'services/mini_menu_service.dart';
import 'services/live2d_global_runtime_handler.dart';
import 'services/image_overlay_global_runtime_handler.dart';
import 'services/global_runtime_registry.dart';
import 'services/live2d_quick_toggle_service.dart';
import 'features/live2d/data/models/live2d_settings.dart';
import 'features/image_overlay/data/models/image_overlay_settings.dart';
import 'features/live2d/data/services/live2d_native_bridge.dart';

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

        ChangeNotifierProvider(create: (_) => ScreenShareProvider()),

        ChangeNotifierProxyProvider<ScreenShareProvider, ScreenCaptureProvider>(
          create: (_) => ScreenCaptureProvider(),
          update: (_, screenShareProvider, screenCaptureProvider) {
            final provider = screenCaptureProvider ?? ScreenCaptureProvider();
            provider.syncSettings(screenShareProvider.settings);
            return provider;
          },
        ),

        ChangeNotifierProxyProvider<PromptBlockProvider, PromptPresetProvider>(
          create: (_) => PromptPresetProvider(),
          update: (_, promptBlockProvider, promptPresetProvider) {
            final provider = promptPresetProvider ?? PromptPresetProvider();
            provider.syncFromPromptPresets(promptBlockProvider.presets);
            return provider;
          },
        ),

        ChangeNotifierProvider(create: (_) => AgentPromptPresetProvider()),

        Provider(
          create: (_) {
            final handler = Live2DGlobalRuntimeHandler();
            GlobalRuntimeRegistry.instance.register(handler);
            return handler;
          },
          dispose: (_, handler) =>
              GlobalRuntimeRegistry.instance.unregister(handler),
        ),

        Provider(
          create: (_) {
            final handler = ImageOverlayGlobalRuntimeHandler();
            GlobalRuntimeRegistry.instance.register(handler);
            return handler;
          },
          dispose: (_, handler) =>
              GlobalRuntimeRegistry.instance.unregister(handler),
        ),

        ProxyProvider5<
          SettingsProvider,
          PromptBlockProvider,
          ChatSessionProvider,
          NotificationSettingsProvider,
          GlobalRuntimeProvider,
          NotificationCoordinator
        >(
          create: (_) =>
              NotificationCoordinator(bridge: NotificationBridge.instance),
          update:
              (
                context,
                settings,
                prompt,
                sessions,
                notificationSettings,
                globalRuntime,
                coordinator,
              ) {
                final instance =
                    coordinator ??
                    NotificationCoordinator(
                      bridge: NotificationBridge.instance,
                    );
                notificationSettings.rebindApiPresets(settings.apiConfigs);
                notificationSettings.rebindPromptPresets(
                  context.read<PromptPresetProvider>().presets,
                );
                notificationSettings.rebindAgentPromptPresets(
                  context.read<AgentPromptPresetProvider>().references,
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

        ProxyProvider4<
          NotificationCoordinator,
          GlobalRuntimeProvider,
          NotificationSettingsProvider,
          SettingsProvider,
          ProactiveResponseService
        >(
          create: (context) =>
              ProactiveResponseService(context.read<NotificationCoordinator>()),
          update:
              (
                _,
                coordinator,
                globalRuntime,
                notificationSettings,
                settingsProvider,
                service,
              ) {
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

        ProxyProvider6<
          NotificationCoordinator,
          NotificationSettingsProvider,
          SettingsProvider,
          GlobalRuntimeProvider,
          AgentPromptPresetProvider,
          ChatSessionProvider,
          AgentModeService
        >(
          lazy: false,
          create: (context) =>
              AgentModeService(context.read<NotificationCoordinator>()),
          update:
              (
                _,
                coordinator,
                notificationSettings,
                settingsProvider,
                globalRuntime,
                agentPromptPresetProvider,
                chatSessionProvider,
                service,
              ) {
                final instance = service ?? AgentModeService(coordinator);
                instance.attach(
                  notificationSettingsProvider: notificationSettings,
                  settingsProvider: settingsProvider,
                  globalRuntimeProvider: globalRuntime,
                  agentPromptPresetProvider: agentPromptPresetProvider,
                  chatSessionProvider: chatSessionProvider,
                );
                return instance;
              },
        ),

        ProxyProvider4<
          NotificationCoordinator,
          ChatSessionProvider,
          NotificationSettingsProvider,
          SettingsProvider,
          MiniMenuService
        >(
          lazy: false,
          create: (_) => MiniMenuService.instance,
          update:
              (
                _,
                coordinator,
                sessionProvider,
                notificationSettingsProvider,
                settingsProvider,
                miniMenuService,
              ) {
                final instance = miniMenuService ?? MiniMenuService.instance;
                instance.configure(
                  getActiveSessionId: () => sessionProvider.activeSessionId,
                  getMessages: (sessionId) async {
                    final resolved = sessionId ?? sessionProvider.activeSessionId;
                    if (resolved == null) return const <Map<String, dynamic>>[];
                    return sessionProvider
                        .getMessagesForSession(resolved)
                        .map((m) => {
                              'id': m.id,
                              'role': m.roleString,
                              'content': m.content,
                              'timestamp': m.timestamp.toIso8601String(),
                            })
                        .toList(growable: false);
                  },
                  sendMessage: (message, sessionId) async {
                    final result = await coordinator.handleMiniMenuReply(
                      message,
                      sessionId: sessionId,
                    );
                    return result;
                  },
                  captureAndSend: (sessionId, text) async {
                    try {
                      debugPrint(
                        'MiniMenu: captureAndSend called sessionId=$sessionId text="${text.length > 20 ? text.substring(0, 20) : text}"',
                      );
                      final settings = context.read<ScreenShareProvider>().settings;
                      final captureService = UnifiedCaptureService();
                      final hasPermission = await captureService.hasPermission();
                      debugPrint('MiniMenu: hasPermission=$hasPermission');
                      if (!hasPermission) {
                        try {
                          debugPrint('MiniMenu: requesting capture permission from overlay');
                          final granted = await captureService.requestPermission();
                          debugPrint('MiniMenu: permission granted=$granted');
                          if (!granted) {
                            return {
                              'ok': false,
                              'error': 'capture_permission_denied',
                              'message': 'Shizuku 권한이 없습니다. 설정에서 Shizuku 연결을 확인하세요.',
                            };
                          }
                        } catch (permError) {
                          debugPrint('MiniMenu: permission request failed (likely no Activity): $permError');
                          return {
                            'ok': false,
                            'error': 'capture_permission_unavailable',
                            'message': '앱에서 먼저 Shizuku 권한을 허용해 주세요.',
                          };
                        }
                      }
                      debugPrint('MiniMenu: capturing screen...');
                      final image = await captureService.capture(settings);
                      debugPrint('MiniMenu: capture result available=${image != null}');
                      if (image == null) {
                        debugPrint('MiniMenu: capture returned null');
                        return {
                          'ok': false,
                          'error': 'capture_failed',
                          'message': '화면 캡처에 실패했습니다. 앱에서 Shizuku 연결을 확인하세요.',
                        };
                      }
                      debugPrint('MiniMenu: sending screenshot to coordinator '
                          'imageId=${image.id} size=${image.width}x${image.height}');
                      final result = await coordinator.handleMiniMenuReplyWithImages(
                        message: text,
                        images: [image],
                        sessionId: sessionId,
                      );
                      debugPrint('MiniMenu: coordinator result=$result');
                      return result;
                    } catch (e, stack) {
                      debugPrint('MiniMenu: captureAndSend exception=$e');
                      debugPrint('MiniMenu: captureAndSend stack=$stack');
                      return {
                        'ok': false,
                        'error': 'capture_exception',
                        'message': '스크린샷 처리 중 오류: $e',
                      };
                    }
                  },
                  getNotificationsEnabled: () =>
                      notificationSettingsProvider
                          .notificationSettings
                          .notificationsEnabled,
                  setNotificationsEnabled: (enabled) async {
                    await notificationSettingsProvider.setNotificationsEnabled(
                      enabled,
                    );
                  },
                  toggleTouchThrough: () async {
                    return Live2DQuickToggleService.instance.toggleTouchThrough();
                  },
                  getTouchThroughEnabled: () async {
                    final bridge = Live2DNativeBridge();
                    final mode = await bridge.getOverlayMode();
                    if (mode == 'image') {
                      final settings = await ImageOverlaySettings.load();
                      return settings.touchThroughEnabled;
                    }
                    final settings = await Live2DSettings.load();
                    return settings.touchThroughEnabled;
                  },
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

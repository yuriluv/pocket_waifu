// ============================================================================
// Pocket Waifu - AI 채팅 앱 v2.0 (Live2D)
// ============================================================================
// 이 파일은 앱의 진입점(Entry Point)입니다.
// Flutter 앱은 main() 함수에서 시작됩니다.
// 여기서 Provider를 설정하고 앱을 실행합니다.
// 
// v2.0: Live2D 오버레이 시스템 추가
// - overlayMain(): 오버레이 윈도우의 별도 진입점
// ============================================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// 프로바이더 (상태 관리)
import 'providers/chat_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/prompt_block_provider.dart';
import 'providers/chat_session_provider.dart';
import 'providers/theme_provider.dart';

// 화면
import 'screens/chat_screen.dart';

// Live2D 오버레이 위젯
import 'widgets/live2d_overlay_widget.dart';

/// 앱의 시작점
/// 모든 Flutter 앱은 이 함수에서 시작됩니다
void main() {
  // Flutter 엔진 초기화 (비동기 작업 전에 필요)
  WidgetsFlutterBinding.ensureInitialized();
  
  // 앱 실행
  runApp(const PocketWaifuApp());
}

/// 오버레이 윈도우의 진입점
/// flutter_overlay_window 패키지에서 사용됩니다.
/// @pragma 어노테이션은 트리 쉐이킹에서 제외되도록 합니다.
@pragma("vm:entry-point")
void overlayMain() {
  // Flutter 엔진 초기화
  WidgetsFlutterBinding.ensureInitialized();
  
  // 오버레이 앱 실행
  runApp(const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: Live2DOverlayWidget(),
  ));
}

/// 앱의 최상위 위젯
/// MultiProvider를 사용해 여러 Provider를 앱 전체에 제공합니다
class PocketWaifuApp extends StatelessWidget {
  const PocketWaifuApp({super.key});

  @override
  Widget build(BuildContext context) {
    // MultiProvider: 여러 Provider를 한 번에 설정
    // 이렇게 하면 하위 위젯들이 Provider 데이터에 접근할 수 있습니다
    return MultiProvider(
      providers: [
        // 설정 Provider - 앱 설정과 캐릭터 정보를 관리
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
        
        // 채팅 Provider - 대화 내역과 메시지 전송을 관리
        ChangeNotifierProvider(create: (_) => ChatProvider()),
        
        // 프롬프트 블록 Provider - 프롬프트 블록 시스템 관리 (v1.5)
        ChangeNotifierProvider(create: (_) => PromptBlockProvider()),
        
        // 채팅 세션 Provider - 멀티 채팅 세션 관리 (v1.5)
        ChangeNotifierProvider(create: (_) => ChatSessionProvider()),
        
        // 테마 Provider - 테마 프리셋 및 설정 관리 (v1.5)
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ],
      child: const _AppWithTheme(),
    );
  }
}

/// 테마 Provider를 사용하는 앱 위젯
class _AppWithTheme extends StatelessWidget {
  const _AppWithTheme();

  @override
  Widget build(BuildContext context) {
    // 테마 Provider에서 테마 데이터 가져오기
    final themeProvider = Provider.of<ThemeProvider>(context);

    return MaterialApp(
      // 앱 이름
      title: 'Pocket Waifu',
      
      // 디버그 배너 숨기기
      debugShowCheckedModeBanner: false,
      
      // 앱 테마 설정 (ThemeProvider에서 가져옴)
      theme: themeProvider.getThemeData(isDark: false),
      
      // 다크 테마 설정 (ThemeProvider에서 가져옴)
      darkTheme: themeProvider.getThemeData(isDark: true),
      
      // ThemeProvider의 테마 모드 사용
      themeMode: themeProvider.themeMode,
      
      // 시작 화면 - 채팅 화면
      home: const ChatScreen(),
    );
  }
}

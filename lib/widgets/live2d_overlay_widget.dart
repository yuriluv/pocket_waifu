// ============================================================================
// Live2D 오버레이 위젯 (Live2D Overlay Widget)
// ============================================================================
// 이 파일은 오버레이 윈도우에 표시되는 Live2D WebView 위젯입니다.
// flutter_overlay_window의 overlayMain에서 실행됩니다.
// 
// 주요 기능:
// - 투명 배경의 WebView
// - 로컬 서버에서 Live2D 웹 페이지 로드
// - 메인 앱에서 전송된 데이터 수신
// ============================================================================

import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

/// 오버레이 윈도우에 표시되는 Live2D WebView 위젯
class Live2DOverlayWidget extends StatefulWidget {
  const Live2DOverlayWidget({super.key});

  @override
  State<Live2DOverlayWidget> createState() => _Live2DOverlayWidgetState();
}

class _Live2DOverlayWidgetState extends State<Live2DOverlayWidget> {
  // === WebView 컨트롤러 ===
  late final WebViewController _controller;

  // === 상태 변수 ===
  bool _isLoading = true;
  String? _currentModelUrl;
  StreamSubscription? _dataSubscription;

  @override
  void initState() {
    super.initState();
    _initializeWebView();
    _listenToMainApp();
  }

  @override
  void dispose() {
    _dataSubscription?.cancel();
    super.dispose();
  }

  /// WebView 컨트롤러 초기화
  void _initializeWebView() {
    _controller = WebViewController()
      // JavaScript 활성화 (Live2D SDK에 필수)
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      // 배경 투명하게 설정
      ..setBackgroundColor(Colors.transparent)
      // 네비게이션 이벤트 처리
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {
            debugPrint('[Overlay] 로딩 진행률: $progress%');
          },
          onPageStarted: (String url) {
            setState(() => _isLoading = true);
            debugPrint('[Overlay] 페이지 로딩 시작: $url');
          },
          onPageFinished: (String url) {
            setState(() => _isLoading = false);
            debugPrint('[Overlay] 페이지 로딩 완료: $url');
          },
          onWebResourceError: (WebResourceError error) {
            debugPrint('[Overlay] WebView 오류: ${error.description} (${error.errorCode})');
            setState(() => _isLoading = false);
          },
        ),
      );

    // Android WebView 디버깅 활성화
    if (Platform.isAndroid) {
      final androidController = _controller.platform as AndroidWebViewController;
      AndroidWebViewController.enableDebugging(true);
      androidController.setMediaPlaybackRequiresUserGesture(false);
    }

    // 초기 페이지 (빈 페이지 또는 로딩 페이지)
    _controller.loadHtmlString(_getLoadingHtml());
  }

  /// 메인 앱에서 데이터 수신
  void _listenToMainApp() {
    _dataSubscription = FlutterOverlayWindow.overlayListener.listen((data) {
      debugPrint('[Overlay] 메인 앱에서 데이터 수신: $data');
      
      // 데이터 파싱 및 처리
      _handleReceivedData(data);
    });
  }

  /// 수신된 데이터 처리
  void _handleReceivedData(dynamic data) {
    if (data == null) return;

    try {
      // 데이터가 문자열인 경우 Map으로 파싱 시도
      // (실제로는 JSON 파싱이 더 안전함)
      if (data is String && data.contains('loadModel')) {
        // URL 추출 (간단한 파싱)
        final urlMatch = RegExp(r'url:\s*(http[^\s,}]+)').firstMatch(data);
        if (urlMatch != null) {
          final url = urlMatch.group(1);
          if (url != null) {
            _loadModel(url);
          }
        }
      }
    } catch (e) {
      debugPrint('[Overlay] 데이터 처리 오류: $e');
    }
  }

  /// Live2D 모델 로드
  void _loadModel(String url) {
    if (_currentModelUrl == url) return;

    setState(() {
      _currentModelUrl = url;
      _isLoading = true;
    });

    debugPrint('[Overlay] 모델 로딩: $url');
    _controller.loadRequest(Uri.parse(url));
  }

  /// 로딩 HTML 페이지
  String _getLoadingHtml() {
    return '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <style>
    * { margin: 0; padding: 0; }
    body {
      background: transparent;
      display: flex;
      justify-content: center;
      align-items: center;
      height: 100vh;
      font-family: -apple-system, BlinkMacSystemFont, sans-serif;
    }
    .loading {
      text-align: center;
      color: rgba(255, 255, 255, 0.8);
    }
    .spinner {
      width: 40px;
      height: 40px;
      border: 3px solid rgba(255, 255, 255, 0.3);
      border-top: 3px solid #fff;
      border-radius: 50%;
      animation: spin 1s linear infinite;
      margin: 0 auto 16px;
    }
    @keyframes spin {
      0% { transform: rotate(0deg); }
      100% { transform: rotate(360deg); }
    }
  </style>
</head>
<body>
  <div class="loading">
    <div class="spinner"></div>
    <p>모델 대기 중...</p>
  </div>
</body>
</html>
''';
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: Stack(
        children: [
          // WebView (투명 배경)
          Positioned.fill(
            child: WebViewWidget(controller: _controller),
          ),

          // 로딩 인디케이터
          if (_isLoading)
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(0.3),
                child: const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
              ),
            ),

          // 닫기 버튼 (우측 상단)
          Positioned(
            top: 4,
            right: 4,
            child: GestureDetector(
              onTap: () async {
                await FlutterOverlayWindow.closeOverlay();
              },
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.close,
                  size: 16,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

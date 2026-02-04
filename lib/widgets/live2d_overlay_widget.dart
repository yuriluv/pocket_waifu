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
import 'dart:convert';
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
  String _debugStatus = '초기화 중...'; // 디버그용

  @override
  void initState() {
    super.initState();
    debugPrint('[Overlay] ========== 위젯 initState ==========');
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
            debugPrint(
              '[Overlay] WebView 오류: ${error.description} (${error.errorCode})',
            );
            debugPrint('[Overlay] 오류 URL: ${error.url}');
            setState(() => _isLoading = false);
          },
          onHttpError: (HttpResponseError error) {
            debugPrint('[Overlay] HTTP 오류: ${error.response?.statusCode}');
          },
        ),
      );

    // Android WebView 디버깅 활성화
    if (Platform.isAndroid) {
      final androidController =
          _controller.platform as AndroidWebViewController;
      AndroidWebViewController.enableDebugging(true);
      androidController.setMediaPlaybackRequiresUserGesture(false);
    }

    // 초기 페이지 (빈 페이지 또는 로딩 페이지)
    _controller.loadHtmlString(_getLoadingHtml());

    setState(() {
      _debugStatus = 'WebView 초기화 완료';
    });
  }

  /// 메인 앱에서 데이터 수신
  void _listenToMainApp() {
    debugPrint('[Overlay] overlayListener 등록 시작');

    _dataSubscription = FlutterOverlayWindow.overlayListener.listen((data) {
      debugPrint('[Overlay] ★★★ 데이터 수신됨 ★★★: $data');

      setState(() {
        _debugStatus =
            '데이터 수신: ${data.toString().substring(0, data.toString().length > 30 ? 30 : data.toString().length)}...';
      });

      // 데이터 파싱 및 처리
      _handleReceivedData(data);
    });

    debugPrint('[Overlay] overlayListener 등록 완료');
  }

  /// 수신된 데이터 처리
  void _handleReceivedData(dynamic data) {
    if (data == null) return;

    debugPrint('[Overlay] 수신 데이터 타입: ${data.runtimeType}');
    debugPrint('[Overlay] 수신 데이터 내용: $data');

    try {
      String? url;

      // 1. Map 타입인 경우
      if (data is Map) {
        if (data['action'] == 'loadModel' && data['url'] != null) {
          url = data['url'].toString();
        }
      }
      // 2. 문자열인 경우
      else if (data is String) {
        // 2-1. JSON 형식으로 파싱 시도
        if (data.startsWith('{')) {
          try {
            final jsonData = jsonDecode(data);
            if (jsonData is Map &&
                jsonData['action'] == 'loadModel' &&
                jsonData['url'] != null) {
              url = jsonData['url'].toString();
            }
          } catch (jsonError) {
            debugPrint('[Overlay] JSON 파싱 실패, 정규식으로 시도: $jsonError');
          }
        }

        // 2-2. Dart Map.toString() 형식으로 파싱 시도
        // 형식: {action: loadModel, url: http://localhost:8080/?model=/models/...}
        if (url == null && data.contains('loadModel')) {
          // url: 뒤에 오는 http로 시작하는 URL 추출
          // URL이 } 또는 , 또는 공백으로 끝날 수 있음
          final urlMatch = RegExp(r'url:\s*(http[^\s,}]+)').firstMatch(data);
          if (urlMatch != null) {
            url = urlMatch.group(1);
          }
        }

        // 2-3. URL 자체인 경우
        if (url == null && data.startsWith('http')) {
          url = data;
        }
      }

      // URL이 추출되었으면 모델 로드
      if (url != null && url.isNotEmpty) {
        debugPrint('[Overlay] 추출된 URL: $url');
        _loadModel(url);
      } else {
        debugPrint('[Overlay] URL 추출 실패');
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
    // 🧪 디버그 모드: WebView 대신 간단한 UI로 테스트
    const bool debugMode = true; // false로 바꾸면 WebView 사용

    if (debugMode) {
      return Material(
        type: MaterialType.transparency,
        child: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.purple.withOpacity(0.9),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white, width: 2),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.bug_report, color: Colors.white, size: 32),
              const SizedBox(height: 8),
              const Text(
                'Live2D 오버레이 테스트',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                margin: const EdgeInsets.symmetric(horizontal: 8),
                color: Colors.black45,
                child: Column(
                  children: [
                    Text(
                      '상태: $_debugStatus',
                      style: const TextStyle(color: Colors.green, fontSize: 10),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'URL: ${_currentModelUrl ?? "대기 중..."}',
                      style: const TextStyle(color: Colors.yellow, fontSize: 8),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // 닫기 버튼
              GestureDetector(
                onTap: () async {
                  await FlutterOverlayWindow.closeOverlay();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    '닫기',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // 원래 WebView UI
    return Material(
      type: MaterialType.transparency,
      child: Container(
        // 디버그: 배경색 추가해서 오버레이가 보이는지 확인
        decoration: BoxDecoration(
          color: Colors.blue.withOpacity(0.3), // 반투명 파란색
          border: Border.all(color: Colors.red, width: 2),
        ),
        child: Stack(
          children: [
            // WebView (투명 배경)
            Positioned.fill(child: WebViewWidget(controller: _controller)),

            // 디버그 상태 표시 (항상 표시)
            Positioned(
              top: 30,
              left: 4,
              right: 4,
              child: Container(
                padding: const EdgeInsets.all(4),
                color: Colors.black.withOpacity(0.7),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '상태: $_debugStatus',
                      style: const TextStyle(color: Colors.green, fontSize: 9),
                    ),
                    Text(
                      'URL: ${_currentModelUrl ?? "없음"}',
                      style: const TextStyle(color: Colors.yellow, fontSize: 8),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),

            // 로딩 인디케이터 (로드 중일 때만)
            if (_isLoading)
              Positioned.fill(
                child: Container(
                  color: Colors.black.withOpacity(0.3),
                  child: const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      strokeWidth: 2,
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
                  child: const Icon(Icons.close, size: 16, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

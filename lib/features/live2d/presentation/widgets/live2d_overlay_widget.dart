// ============================================================================
// Live2D 오버레이 위젯 v3.0 (WebViewAssetLoader 버전)
// ============================================================================
// 오버레이 윈도우에 표시되는 Live2D WebView 위젯입니다.
// flutter_overlay_window의 overlayMain에서 실행됩니다.
// 
// v3.0 변경사항:
// - WebViewAssetLoader 가상 도메인 지원 (https://live2d.local/)
// - HTTPS URL 처리 추가
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
  late final WebViewController _controller;
  bool _isLoading = true;
  bool _hasError = false;
  String? _errorMessage;
  String? _currentModelUrl;
  StreamSubscription? _dataSubscription;
  bool _webViewReady = false;
  String? _pendingUrl;

  @override
  void initState() {
    super.initState();
    debugPrint('[Live2D Overlay] initState 시작');
    _initializeWebView();
    _listenToMainApp();
  }

  @override
  void dispose() {
    debugPrint('[Live2D Overlay] dispose');
    _dataSubscription?.cancel();
    super.dispose();
  }

  /// WebView 컨트롤러 초기화
  void _initializeWebView() {
    debugPrint('[Live2D Overlay] WebView 초기화 시작');
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.transparent)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {
            debugPrint('[Live2D Overlay] 로딩: $progress%');
          },
          onPageStarted: (String url) {
            setState(() {
              _isLoading = true;
              _hasError = false;
            });
            debugPrint('[Live2D Overlay] 페이지 시작: $url');
          },
          onPageFinished: (String url) {
            debugPrint('[Live2D Overlay] 페이지 완료: $url');
            setState(() {
              _isLoading = false;
              _webViewReady = true;
            });
            // 페이지 로드 완료 후 대기 중인 URL이 있으면 로드
            if (_pendingUrl != null) {
              debugPrint('[Live2D Overlay] 대기 중인 URL 로드: $_pendingUrl');
              final url = _pendingUrl!;
              _pendingUrl = null;
              Future.delayed(const Duration(milliseconds: 300), () {
                _loadModel(url);
              });
            }
          },
          onWebResourceError: (WebResourceError error) {
            debugPrint('[Live2D Overlay] 에러: ${error.description}');
            setState(() {
              _isLoading = false;
              _hasError = true;
              _errorMessage = error.description;
            });
          },
        ),
      )
      ..addJavaScriptChannel(
        'FlutterChannel',
        onMessageReceived: (message) {
          debugPrint('[Live2D Overlay] JS 메시지: ${message.message}');
          _handleJsMessage(message.message);
        },
      );

    // Android WebView 설정
    if (Platform.isAndroid) {
      final androidController = _controller.platform as AndroidWebViewController;
      AndroidWebViewController.enableDebugging(true);
      androidController.setMediaPlaybackRequiresUserGesture(false);
    }

    // 초기 로딩 페이지
    debugPrint('[Live2D Overlay] 초기 HTML 로딩');
    _controller.loadHtmlString(_getLoadingHtml());
  }

  /// 메인 앱에서 데이터 수신
  void _listenToMainApp() {
    debugPrint('[Live2D Overlay] 데이터 리스너 등록');
    _dataSubscription = FlutterOverlayWindow.overlayListener.listen(
      (data) {
        debugPrint('[Live2D Overlay] 데이터 수신: $data (타입: ${data.runtimeType})');
        _handleReceivedData(data);
      },
      onError: (error) {
        debugPrint('[Live2D Overlay] 리스너 에러: $error');
      },
      onDone: () {
        debugPrint('[Live2D Overlay] 리스너 종료');
      },
    );
  }

  /// 수신된 데이터 처리
  void _handleReceivedData(dynamic data) {
    debugPrint('[Live2D Overlay] 데이터 처리 시작: $data');
    if (data == null) {
      debugPrint('[Live2D Overlay] null 데이터 무시');
      return;
    }

    try {
      String? url;

      // Map 타입
      if (data is Map) {
        debugPrint('[Live2D Overlay] Map 타입 데이터: ${data.keys}');
        if (data['action'] == 'loadModel' && data['url'] != null) {
          url = data['url'].toString();
          debugPrint('[Live2D Overlay] Map에서 URL 추출: $url');
        }
      }
      // String 타입
      else if (data is String) {
        debugPrint('[Live2D Overlay] String 타입 데이터');
        // JSON 파싱 시도
        if (data.startsWith('{')) {
          try {
            final jsonData = jsonDecode(data);
            if (jsonData is Map &&
                jsonData['action'] == 'loadModel' &&
                jsonData['url'] != null) {
              url = jsonData['url'].toString();
              debugPrint('[Live2D Overlay] JSON에서 URL 추출: $url');
            }
          } catch (e) {
            debugPrint('[Live2D Overlay] JSON 파싱 실패: $e');
          }
        }

        // Map.toString() 형식 파싱 (http 또는 https)
        if (url == null && data.contains('loadModel')) {
          final urlMatch = RegExp(r'url:\s*(https?://[^\s,}]+)').firstMatch(data);
          if (urlMatch != null) {
            url = urlMatch.group(1);
            debugPrint('[Live2D Overlay] RegExp에서 URL 추출: $url');
          }
        }

        // URL 자체 (http 또는 https 모두 지원)
        if (url == null && _isValidUrl(data)) {
          url = data;
          debugPrint('[Live2D Overlay] 직접 URL: $url');
        }
      } else {
        debugPrint('[Live2D Overlay] 알 수 없는 타입: ${data.runtimeType}');
      }

      if (url != null && url.isNotEmpty) {
        debugPrint('[Live2D Overlay] 모델 로드 시작: $url');
        _loadModel(url);
      }
    } catch (e) {
      debugPrint('[Live2D Overlay] 데이터 처리 오류: $e');
    }
  }

  /// URL이 유효한지 확인 (http, https 모두 지원)
  bool _isValidUrl(String url) {
    return url.startsWith('http://') || url.startsWith('https://');
  }

  /// JavaScript 메시지 처리
  void _handleJsMessage(String message) {
    try {
      final json = jsonDecode(message);
      final type = json['type'] as String?;

      switch (type) {
        case 'error':
          setState(() {
            _hasError = true;
            _errorMessage = json['message'] as String?;
          });
          break;
        case 'loaded':
          setState(() {
            _isLoading = false;
            _hasError = false;
          });
          break;
        case 'tap':
          // 터치 이벤트 (필요시 처리)
          break;
      }
    } catch (e) {
      // JSON 파싱 실패 - 무시
    }
  }

  /// 모델 로드
  void _loadModel(String url) {
    debugPrint('[Live2D Overlay] _loadModel 호출: $url');
    debugPrint('[Live2D Overlay] WebView 준비됨: $_webViewReady');
    debugPrint('[Live2D Overlay] 현재 URL: $_currentModelUrl');
    
    // 동일한 URL이면 스킵
    if (_currentModelUrl == url) {
      debugPrint('[Live2D Overlay] 동일한 URL - 스킵');
      return;
    }

    // WebView가 준비되지 않았으면 대기열에 추가
    if (!_webViewReady) {
      debugPrint('[Live2D Overlay] WebView 미준비 - 대기열에 추가');
      _pendingUrl = url;
      return;
    }

    setState(() {
      _currentModelUrl = url;
      _isLoading = true;
      _hasError = false;
    });

    debugPrint('[Live2D Overlay] loadRequest 호출: $url');
    _controller.loadRequest(Uri.parse(url));
  }

  /// 로딩 HTML
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
      color: Colors.transparent,
      child: Stack(
        children: [
          // WebView
          WebViewWidget(controller: _controller),

          // 로딩 인디케이터
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.3),
              child: const Center(
                child: CircularProgressIndicator(
                  color: Colors.white,
                ),
              ),
            ),

          // 에러 표시
          if (_hasError)
            Container(
              color: Colors.black.withOpacity(0.7),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: Colors.red,
                      size: 48,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _errorMessage ?? '오류가 발생했습니다',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

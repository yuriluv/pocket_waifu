// ============================================================================
// 로컬 웹 서버 서비스 (Local Server Service)
// ============================================================================
// 이 파일은 앱 내부에서 동작하는 로컬 HTTP 서버를 관리합니다.
// Live2D 모델 파일들을 WebView에서 로드할 수 있도록 서빙합니다.
// 
// 하이브리드 라우팅:
// - http://localhost:8080/           -> assets/web/index.html (앱 내장)
// - http://localhost:8080/models/... -> 사용자가 선택한 폴더의 파일
// 
// CORS 헤더 추가로 WebView에서 리소스 접근 가능
// ============================================================================

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:path/path.dart' as path;
import 'package:flutter/services.dart' show rootBundle;

/// 로컬 웹 서버를 관리하는 싱글톤 서비스
class LocalServerService {
  // === 싱글톤 패턴 ===
  static final LocalServerService _instance = LocalServerService._internal();
  factory LocalServerService() => _instance;
  LocalServerService._internal();

  // === 서버 설정 ===
  static const int serverPort = 8080;              // 서버 포트
  static const String serverHost = 'localhost';    // 서버 호스트
  
  // === 상태 변수 ===
  HttpServer? _server;        // HTTP 서버 인스턴스
  bool _isRunning = false;    // 서버 실행 상태
  String? _rootPath;          // 서버 루트 경로

  // === Getter ===
  bool get isRunning => _isRunning;
  String get serverUrl => 'http://$serverHost:$serverPort';
  String? get rootPath => _rootPath;

  /// 서버를 시작합니다
  /// 
  /// [rootDirectory]: 모델 파일들이 있는 디렉토리 경로
  /// 예: /storage/emulated/0/Download/Live2D
  Future<bool> startServer(String rootDirectory) async {
    // 이미 실행 중이면 경로 업데이트
    if (_isRunning) {
      debugPrint('[LocalServer] 서버가 이미 실행 중입니다. 경로만 업데이트합니다.');
      _rootPath = rootDirectory;
      return true;
    }

    try {
      _rootPath = rootDirectory;

      // 루트 디렉토리 존재 확인
      final rootDir = Directory(rootDirectory);
      if (!await rootDir.exists()) {
        debugPrint('[LocalServer] 루트 디렉토리가 없습니다: $rootDirectory');
        return false;
      }

      // === Shelf 핸들러 구성 (하이브리드 라우팅) ===
      final handler = const shelf.Pipeline()
          .addMiddleware(_corsMiddleware())    // CORS 헤더 추가
          .addMiddleware(_loggingMiddleware()) // 요청 로깅
          .addHandler(_hybridRouter);

      // === 서버 시작 ===
      _server = await shelf_io.serve(
        handler,
        InternetAddress.anyIPv4,  // 모든 인터페이스에서 접근 허용
        serverPort,
      );

      _isRunning = true;
      debugPrint('[LocalServer] 서버 시작됨: $serverUrl');
      debugPrint('[LocalServer] 모델 폴더: $rootDirectory');
      
      return true;
    } catch (e) {
      debugPrint('[LocalServer] 서버 시작 실패: $e');
      _isRunning = false;
      return false;
    }
  }

  /// 하이브리드 라우터 - 경로에 따라 다른 소스에서 파일 제공
  Future<shelf.Response> _hybridRouter(shelf.Request request) async {
    final urlPath = request.url.path;
    
    // 1. 루트 경로 "/" 또는 빈 경로 -> index.html 제공
    if (urlPath.isEmpty || urlPath == '/' || urlPath == 'index.html') {
      return await _serveIndexHtml();
    }
    
    // 2. /models/ 경로 -> 외부 저장소에서 모델 파일 제공
    if (urlPath.startsWith('models/')) {
      return await _serveModelFile(urlPath.substring(7)); // 'models/' 제거
    }
    
    // 3. 기타 -> 404
    return shelf.Response.notFound('Not found: $urlPath');
  }

  /// assets/web/index.html 파일을 읽어서 반환
  Future<shelf.Response> _serveIndexHtml() async {
    try {
      final htmlContent = await rootBundle.loadString('assets/web/index.html');
      return shelf.Response.ok(
        htmlContent,
        headers: {
          'Content-Type': 'text/html; charset=utf-8',
          ..._corsHeaders,
        },
      );
    } catch (e) {
      debugPrint('[LocalServer] index.html 로드 실패: $e');
      return shelf.Response.internalServerError(
        body: 'Failed to load index.html: $e',
      );
    }
  }

  /// 외부 저장소에서 모델 파일 제공
  Future<shelf.Response> _serveModelFile(String relativePath) async {
    debugPrint('[LocalServer] === 모델 파일 요청 시작 ===');
    debugPrint('[LocalServer] 요청 경로 (원본): $relativePath');
    debugPrint('[LocalServer] 루트 경로: $_rootPath');
    
    if (_rootPath == null) {
      debugPrint('[LocalServer] 오류: 루트 경로가 설정되지 않음');
      return shelf.Response.internalServerError(
        body: 'Model root path not set',
      );
    }

    try {
      // URL 디코딩 (한글 파일명 등 처리)
      final decodedPath = Uri.decodeComponent(relativePath);
      debugPrint('[LocalServer] 디코딩 경로: $decodedPath');
      
      // URL 경로의 / 를 시스템 경로 구분자로 변환
      final normalizedPath = decodedPath.replaceAll('/', path.separator);
      debugPrint('[LocalServer] 정규화 경로: $normalizedPath');
      
      final filePath = path.join(_rootPath!, normalizedPath);
      debugPrint('[LocalServer] 최종 파일 경로: $filePath');
      
      final file = File(filePath);
      
      if (!await file.exists()) {
        debugPrint('[LocalServer] ⚠️ 파일 없음: $filePath');
        // 디렉토리 내용 출력 (디버깅용)
        final dir = Directory(_rootPath!);
        if (await dir.exists()) {
          debugPrint('[LocalServer] 루트 폴더 내용:');
          await for (final entity in dir.list(recursive: false)) {
            debugPrint('[LocalServer]   - ${entity.path}');
          }
        }
        return shelf.Response.notFound('File not found: $relativePath\nFull path: $filePath');
      }

      // 파일 읽기
      final bytes = await file.readAsBytes();
      final mimeType = _getMimeType(filePath);
      
      return shelf.Response.ok(
        bytes,
        headers: {
          'Content-Type': mimeType,
          'Content-Length': bytes.length.toString(),
          ..._corsHeaders,
        },
      );
    } catch (e) {
      debugPrint('[LocalServer] 파일 서빙 실패: $relativePath - $e');
      return shelf.Response.internalServerError(
        body: 'Error serving file: $e',
      );
    }
  }

  /// 서버를 중지합니다
  Future<void> stopServer() async {
    if (_server != null) {
      await _server!.close(force: true);
      _server = null;
      _isRunning = false;
      debugPrint('[LocalServer] 서버가 중지되었습니다.');
    }
  }

  /// CORS 미들웨어 - 모든 응답에 CORS 헤더를 추가합니다
  /// WebView가 로컬 서버 리소스를 로드할 수 있게 합니다
  shelf.Middleware _corsMiddleware() {
    return (shelf.Handler innerHandler) {
      return (shelf.Request request) async {
        // OPTIONS 요청 (Preflight) 처리
        if (request.method == 'OPTIONS') {
          return shelf.Response.ok(
            '',
            headers: _corsHeaders,
          );
        }

        // 실제 요청 처리 후 CORS 헤더 추가
        final response = await innerHandler(request);
        return response.change(headers: _corsHeaders);
      };
    };
  }

  /// CORS 헤더 맵
  Map<String, String> get _corsHeaders => {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
    'Access-Control-Allow-Headers': '*',
    'Access-Control-Max-Age': '86400',  // 24시간 캐시
  };

  /// 로깅 미들웨어 - 요청을 디버그 출력합니다 (개발용)
  shelf.Middleware _loggingMiddleware() {
    return (shelf.Handler innerHandler) {
      return (shelf.Request request) async {
        final stopwatch = Stopwatch()..start();
        final response = await innerHandler(request);
        stopwatch.stop();
        
        debugPrint(
          '[LocalServer] ${request.method} /${request.url.path} '
          '-> ${response.statusCode} (${stopwatch.elapsedMilliseconds}ms)'
        );
        
        return response;
      };
    };
  }

  /// 파일 확장자에 따른 MIME 타입 반환
  String _getMimeType(String filePath) {
    final ext = path.extension(filePath).toLowerCase();
    switch (ext) {
      case '.html':
        return 'text/html; charset=utf-8';
      case '.js':
        return 'application/javascript; charset=utf-8';
      case '.css':
        return 'text/css; charset=utf-8';
      case '.json':
        return 'application/json; charset=utf-8';
      case '.png':
        return 'image/png';
      case '.jpg':
      case '.jpeg':
        return 'image/jpeg';
      case '.gif':
        return 'image/gif';
      case '.webp':
        return 'image/webp';
      case '.svg':
        return 'image/svg+xml';
      case '.wasm':
        return 'application/wasm';
      case '.moc3':
        return 'application/octet-stream';
      case '.model3':
        return 'application/json';
      default:
        return 'application/octet-stream';
    }
  }

  /// 모델 파일의 서버 URL을 생성합니다
  /// 
  /// [modelRelativePath]: 모델 폴더 기준 상대 경로
  /// 예: "hiyori/hiyori.model3.json"
  /// 반환: "http://localhost:8080/models/hiyori/hiyori.model3.json"
  String getModelUrl(String modelRelativePath) {
    // 경로 구분자 정규화 (Windows \ -> /)
    final normalizedPath = modelRelativePath.replaceAll('\\', '/');
    return '$serverUrl/models/$normalizedPath';
  }

  /// WebView에서 로드할 전체 URL을 생성합니다
  /// 
  /// [modelRelativePath]: 모델 폴더 기준 상대 경로
  /// 반환: "http://localhost:8080/?model=/models/hiyori/hiyori.model3.json"
  String getWebViewUrl(String modelRelativePath) {
    // 경로 구분자 정규화 (Windows \ -> /)
    final normalizedPath = modelRelativePath.replaceAll('\\', '/');
    final url = '$serverUrl/?model=/models/$normalizedPath';
    debugPrint('[LocalServer] getWebViewUrl 입력: $modelRelativePath');
    debugPrint('[LocalServer] getWebViewUrl 정규화: $normalizedPath');
    debugPrint('[LocalServer] getWebViewUrl 출력: $url');
    return url;
  }
}

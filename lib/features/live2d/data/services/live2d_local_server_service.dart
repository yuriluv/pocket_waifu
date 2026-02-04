// ============================================================================
// Live2D 로컬 서버 서비스 v3.0 (Kotlin 네이티브 서버)
// ============================================================================
// v3.0 변경사항:
// - Dart Shelf 서버 제거
// - Kotlin 네이티브 HTTP 서버 사용
// - MethodChannel을 통해 서버 제어
// 
// 장점:
// - 안정적인 파일 서빙 (Java/Kotlin 네이티브)
// - URL 인코딩/디코딩 문제 해결
// - 대용량 파일 스트리밍 지원
// - Range 요청 지원
// ============================================================================

import 'dart:io';
import 'package:flutter/services.dart';
import 'live2d_log_service.dart';

/// 로컬 웹 서버를 관리하는 싱글톤 서비스 (v3.0 - Kotlin 서버)
class Live2DLocalServerService {
  // === 싱글톤 패턴 ===
  static final Live2DLocalServerService _instance = Live2DLocalServerService._internal();
  factory Live2DLocalServerService() => _instance;
  Live2DLocalServerService._internal();

  static const String _tag = 'Server';

  // === 서버 설정 ===
  static const int serverPort = 8080;
  static const String serverHost = 'localhost';
  static const String modelsPath = '/models';
  static const String assetsPath = '/assets';

  // === MethodChannel ===
  static const _channel = MethodChannel('com.example.flutter_application_1/live2d_loader');

  // === 상태 변수 ===
  bool _isRunning = false;
  String? _modelRootPath;

  // === Getter ===
  bool get isRunning => _isRunning;
  String get serverUrl => 'http://$serverHost:$serverPort';
  String? get modelRootPath => _modelRootPath;

  /// 서버를 시작합니다 (Kotlin 네이티브 서버)
  /// 
  /// [modelRootPath]: 모델 파일들이 있는 디렉토리 경로
  /// 예: /storage/emulated/0/Download/Live2D
  Future<bool> startServer(String modelRootPath) async {
    live2dLog.info(_tag, '========================================');
    live2dLog.info(_tag, 'v3.0 - Kotlin 네이티브 서버 모드');
    live2dLog.info(_tag, '========================================');
    live2dLog.info(_tag, '루트 경로: $modelRootPath');

    // 루트 디렉토리 존재 확인
    final rootDir = Directory(modelRootPath);
    if (!await rootDir.exists()) {
      live2dLog.error(_tag, '루트 디렉토리 없음', details: modelRootPath);
      return false;
    }

    _modelRootPath = modelRootPath;

    // Android에서만 Kotlin 서버 사용
    if (Platform.isAndroid) {
      try {
        final result = await _channel.invokeMethod('setModelRootPath', {
          'path': modelRootPath,
        });
        
        _isRunning = result == true;
        
        if (_isRunning) {
          live2dLog.info(_tag, '✅ Kotlin 서버 시작 완료');
          live2dLog.info(_tag, '서버 URL: $serverUrl');
        } else {
          live2dLog.error(_tag, '❌ Kotlin 서버 시작 실패');
        }
        
        return _isRunning;
      } catch (e, stack) {
        live2dLog.error(_tag, 'MethodChannel 오류', error: e, stackTrace: stack);
        return false;
      }
    } else {
      // Android 외 플랫폼은 현재 미지원
      live2dLog.warning(_tag, 'Android 외 플랫폼은 현재 미지원');
      return false;
    }
  }

  /// 서버를 중지합니다
  Future<void> stopServer() async {
    if (Platform.isAndroid) {
      try {
        await _channel.invokeMethod('stopServer');
        _isRunning = false;
        live2dLog.info(_tag, '서버 중지됨');
      } catch (e) {
        live2dLog.warning(_tag, '서버 중지 오류: $e');
      }
    }
  }

  /// 모델 파일의 URL을 생성합니다
  /// 
  /// [modelRelativePath]: 모델 폴더 기준 상대 경로
  /// 예: "hiyori/hiyori.model3.json"
  /// 반환: "http://localhost:8080/models/hiyori/hiyori.model3.json"
  String getModelUrl(String modelRelativePath) {
    // 경로 구분자 정규화 (Windows \ -> /)
    final normalizedPath = modelRelativePath.replaceAll('\\', '/');
    
    // 각 경로 세그먼트를 개별적으로 인코딩
    final encodedPath = normalizedPath
        .split('/')
        .map((segment) => Uri.encodeComponent(segment))
        .join('/');
    
    final url = '$serverUrl$modelsPath/$encodedPath';
    live2dLog.debug(_tag, '모델 URL 생성', details: url);
    return url;
  }

  /// WebView에서 로드할 전체 URL을 생성합니다
  /// 
  /// [modelRelativePath]: 모델 폴더 기준 상대 경로
  /// 반환: "http://localhost:8080/?model=/models/..."
  String getWebViewUrl(String modelRelativePath) {
    // 경로 구분자 정규화 (Windows \ -> /)
    final normalizedPath = modelRelativePath.replaceAll('\\', '/');
    
    // 각 경로 세그먼트를 개별적으로 인코딩
    final encodedPath = normalizedPath
        .split('/')
        .map((segment) => Uri.encodeComponent(segment))
        .join('/');
    
    // 모델 경로
    final modelUrl = '$modelsPath/$encodedPath';
    
    // model 파라미터도 인코딩 (쿼리 스트링에 안전하게)
    final encodedModelParam = Uri.encodeComponent(modelUrl);
    
    // 최종 URL: http://localhost:8080/?model=/models/...
    final url = '$serverUrl/?model=$encodedModelParam';
    
    live2dLog.info(_tag, 'WebView URL 생성');
    live2dLog.debug(_tag, '입력: $modelRelativePath');
    live2dLog.debug(_tag, '출력: $url');
    
    return url;
  }
}

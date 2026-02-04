// ============================================================================
// Live2D 로더 서비스 (Live2D Loader Service)
// ============================================================================
// Kotlin 네이티브 HTTP 서버와 통신하는 Flutter 서비스입니다.
// MethodChannel을 통해 서버 시작/중지 및 URL 생성을 수행합니다.
// 
// v3.0 - Kotlin 네이티브 HTTP 서버 사용
// 
// URL 스킴:
// - http://localhost:8080/models/... -> 외부 저장소 모델 파일
// - http://localhost:8080/assets/... -> 앱 내장 에셋
// ============================================================================

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Live2D 모델 로더 서비스 (Kotlin 서버 기반)
class Live2DLoaderService {
  // === 싱글톤 패턴 ===
  static final Live2DLoaderService _instance = Live2DLoaderService._internal();
  factory Live2DLoaderService() => _instance;
  Live2DLoaderService._internal();

  // === MethodChannel ===
  static const _channel = MethodChannel('com.example.flutter_application_1/live2d_loader');

  // === 서버 설정 ===
  static const String _serverHost = 'localhost';
  static const int _serverPort = 8080;
  static const String modelsPath = '/models/';
  static const String assetsPath = '/assets/';

  // === 상태 변수 ===
  String? _modelRootPath;
  bool _isConfigured = false;

  // === Getter ===
  String? get modelRootPath => _modelRootPath;
  bool get isConfigured => _isConfigured;
  String get baseUrl => 'http://$_serverHost:$_serverPort';

  /// 모델 루트 경로를 설정하고 Kotlin 서버를 시작합니다.
  /// 
  /// [rootPath]: 모델 파일들이 있는 외부 저장소 경로
  /// 예: /storage/emulated/0/Personal/Apps/PocketWaifu/Live2D
  Future<bool> setModelRootPath(String rootPath) async {
    debugPrint('[Live2DLoader] 모델 루트 경로 설정: $rootPath');
    
    // Android가 아니면 지원 안함
    if (!Platform.isAndroid) {
      debugPrint('[Live2DLoader] ❌ Android만 지원됩니다.');
      return false;
    }
    
    try {
      final result = await _channel.invokeMethod<bool>('setModelRootPath', {
        'path': rootPath,
      });
      
      if (result == true) {
        _modelRootPath = rootPath;
        _isConfigured = true;
        debugPrint('[Live2DLoader] ✅ 서버 시작 완료');
        return true;
      }
      
      return false;
    } on PlatformException catch (e) {
      debugPrint('[Live2DLoader] ❌ 설정 실패: ${e.message}');
      return false;
    }
  }

  /// Kotlin 서버를 중지합니다.
  Future<void> stopServer() async {
    if (!Platform.isAndroid) return;

    try {
      await _channel.invokeMethod('stopServer');
      _isConfigured = false;
      debugPrint('[Live2DLoader] 서버 중지됨');
    } catch (e) {
      debugPrint('[Live2DLoader] 서버 중지 오류: $e');
    }
  }

  /// 모델 파일의 URL을 생성합니다 (Kotlin 측에서 생성)
  /// 
  /// [relativePath]: 모델 루트 기준 상대 경로
  /// 예: "IceGirl_Live2d/IceGIrl Live2D/IceGirl.model3.json"
  /// 반환: "http://localhost:8080/models/IceGirl_Live2d/IceGIrl%20Live2D/IceGirl.model3.json"
  Future<String?> getModelUrl(String relativePath) async {
    if (!_isConfigured) {
      debugPrint('[Live2DLoader] ⚠️ 먼저 setModelRootPath()를 호출하세요.');
      return null;
    }
    
    try {
      final url = await _channel.invokeMethod<String>('getModelUrl', {
        'relativePath': relativePath,
      });
      
      debugPrint('[Live2DLoader] getModelUrl: $relativePath -> $url');
      return url;
    } on PlatformException catch (e) {
      debugPrint('[Live2DLoader] ❌ URL 생성 실패: ${e.message}');
      return null;
    }
  }

  /// WebView에서 로드할 전체 URL을 생성합니다 (index.html + model 파라미터)
  /// 
  /// [relativePath]: 모델 루트 기준 상대 경로
  /// 반환: "http://localhost:8080/?model=/models/..."
  Future<String?> getWebViewUrl(String relativePath) async {
    if (!_isConfigured) {
      debugPrint('[Live2DLoader] ⚠️ 먼저 setModelRootPath()를 호출하세요.');
      return null;
    }
    
    try {
      final url = await _channel.invokeMethod<String>('getWebViewUrl', {
        'relativePath': relativePath,
      });
      
      debugPrint('[Live2DLoader] getWebViewUrl: $relativePath -> $url');
      return url;
    } on PlatformException catch (e) {
      debugPrint('[Live2DLoader] ❌ URL 생성 실패: ${e.message}');
      return null;
    }
  }

  /// 현재 설정 정보를 가져옵니다
  Future<Map<String, dynamic>?> getConfig() async {
    try {
      final config = await _channel.invokeMethod<Map>('getConfig');
      return config?.cast<String, dynamic>();
    } on PlatformException catch (e) {
      debugPrint('[Live2DLoader] ❌ 설정 조회 실패: ${e.message}');
      return null;
    }
  }

  // ============================================================================
  // Dart 측에서도 URL 생성 가능 (Kotlin 호출 없이)
  // ============================================================================

  /// [Dart 전용] 모델 파일의 URL을 생성합니다
  /// 
  /// Kotlin 호출 없이 Dart에서 직접 URL 생성
  String getModelUrlDart(String relativePath) {
    final encodedPath = _encodeUrlPath(relativePath);
    return '$baseUrl$modelsPath$encodedPath';
  }

  /// [Dart 전용] WebView 전체 URL을 생성합니다
  String getWebViewUrlDart(String relativePath) {
    final encodedPath = _encodeUrlPath(relativePath);
    final modelUrl = '$modelsPath$encodedPath';
    final encodedModelParam = Uri.encodeComponent(modelUrl);
    return '$baseUrl/?model=$encodedModelParam';
  }

  /// URL 경로 인코딩 (각 세그먼트별)
  String _encodeUrlPath(String relativePath) {
    // 경로 구분자 정규화
    final normalizedPath = relativePath.replaceAll('\\', '/');
    
    // 각 세그먼트별 인코딩
    final segments = normalizedPath.split('/');
    final encodedSegments = segments.map((segment) {
      return Uri.encodeComponent(segment);
    }).toList();
    
    return encodedSegments.join('/');
  }
}

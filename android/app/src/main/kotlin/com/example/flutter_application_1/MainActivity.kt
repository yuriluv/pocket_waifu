package com.example.flutter_application_1

import android.content.Context
import android.os.Build
import android.util.Log
import android.webkit.WebResourceRequest
import android.webkit.WebResourceResponse
import android.webkit.WebView
import android.webkit.WebViewClient
import androidx.webkit.WebViewAssetLoader
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.InputStream
import java.net.URLEncoder

/**
 * MainActivity - Live2D 모델 로딩 지원 (v3.0)
 * 
 * 두 가지 방식 지원:
 * 1. Kotlin 네이티브 HTTP 서버 (기본값, 더 안정적)
 * 2. WebViewAssetLoader (실험적)
 * 
 * MethodChannel을 통해 Flutter와 통신
 */
class MainActivity : FlutterActivity() {
    
    companion object {
        private const val TAG = "MainActivity"
        private const val CHANNEL_NAME = "com.example.flutter_application_1/live2d_loader"
        
        // 서버 설정
        private const val SERVER_PORT = 8080
        private const val SERVER_HOST = "localhost"
        
        // 경로 프리픽스
        const val MODELS_PATH = "/models/"
        const val ASSETS_PATH = "/assets/"
    }
    
    private var modelRootPath: String? = null
    private val localServer = Live2DLocalServer.getInstance()
    
    val serverUrl: String get() = "http://$SERVER_HOST:$SERVER_PORT"
    
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // MethodChannel 설정
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL_NAME).setMethodCallHandler { call, result ->
            Log.d(TAG, "MethodChannel 호출: ${call.method}")
            
            when (call.method) {
                // 모델 루트 경로 설정 및 서버 시작
                "setModelRootPath" -> {
                    val path = call.argument<String>("path")
                    if (path != null) {
                        val success = setModelRootPath(path)
                        result.success(success)
                    } else {
                        result.error("INVALID_ARGUMENT", "path is required", null)
                    }
                }
                
                // 서버 중지
                "stopServer" -> {
                    stopServer()
                    result.success(true)
                }
                
                // 모델 URL 생성
                "getModelUrl" -> {
                    val relativePath = call.argument<String>("relativePath")
                    if (relativePath != null) {
                        val url = getModelUrl(relativePath)
                        result.success(url)
                    } else {
                        result.error("INVALID_ARGUMENT", "relativePath is required", null)
                    }
                }
                
                // WebView 전체 URL 생성
                "getWebViewUrl" -> {
                    val relativePath = call.argument<String>("relativePath")
                    if (relativePath != null) {
                        val url = getWebViewUrl(relativePath)
                        result.success(url)
                    } else {
                        result.error("INVALID_ARGUMENT", "relativePath is required", null)
                    }
                }
                
                // 현재 설정 정보 반환
                "getConfig" -> {
                    result.success(mapOf(
                        "serverUrl" to serverUrl,
                        "modelsPath" to MODELS_PATH,
                        "assetsPath" to ASSETS_PATH,
                        "modelRootPath" to modelRootPath,
                        "isRunning" to (modelRootPath != null)
                    ))
                }
                
                else -> {
                    result.notImplemented()
                }
            }
        }
    }
    
    /**
     * 모델 루트 경로 설정 및 서버 시작
     */
    private fun setModelRootPath(path: String): Boolean {
        Log.d(TAG, "========================================")
        Log.d(TAG, "모델 루트 경로 설정 (v3.0 Kotlin 서버)")
        Log.d(TAG, "========================================")
        Log.d(TAG, "경로: $path")
        
        // 디렉토리 존재 확인
        val dir = File(path)
        if (!dir.exists() || !dir.isDirectory) {
            Log.e(TAG, "❌ 디렉토리가 존재하지 않습니다: $path")
            return false
        }
        
        modelRootPath = path
        
        // assets 제공자 (Flutter assets 파일 접근)
        // Flutter assets는 빌드 후 flutter_assets/ 폴더에 위치
        val assetsProvider: (String) -> InputStream? = { assetPath ->
            try {
                // Flutter assets 경로로 변환
                val flutterAssetPath = "flutter_assets/assets/$assetPath"
                Log.d(TAG, "Asset 요청: $assetPath -> $flutterAssetPath")
                assets.open(flutterAssetPath)
            } catch (e: Exception) {
                Log.w(TAG, "Asset 열기 실패: $assetPath (${e.message})")
                // fallback: 원래 경로로 시도
                try {
                    assets.open(assetPath)
                } catch (e2: Exception) {
                    Log.w(TAG, "Fallback Asset도 실패: $assetPath")
                    null
                }
            }
        }
        
        // 네이티브 서버 시작
        val success = localServer.start(path, assetsProvider)
        
        if (success) {
            Log.i(TAG, "✅ Kotlin 네이티브 서버 시작 완료")
            Log.i(TAG, "   URL: $serverUrl")
            Log.i(TAG, "   모델: ${MODELS_PATH}...")
            Log.i(TAG, "   Assets: ${ASSETS_PATH}...")
        } else {
            Log.e(TAG, "❌ 서버 시작 실패")
        }
        
        return success
    }
    
    /**
     * 서버 중지
     */
    private fun stopServer() {
        localServer.stop()
        Log.d(TAG, "서버 중지됨")
    }
    
    /**
     * 모델 파일의 URL 생성
     * 
     * 입력: "IceGirl_Live2d/IceGIrl Live2D/IceGirl.model3.json"
     * 출력: "http://localhost:8080/models/IceGirl_Live2d/IceGIrl%20Live2D/IceGirl.model3.json"
     */
    private fun getModelUrl(relativePath: String): String {
        // 경로 구분자 정규화
        val normalizedPath = relativePath.replace("\\", "/")
        
        // 각 세그먼트별 URL 인코딩
        val encodedPath = normalizedPath.split("/").joinToString("/") { segment ->
            URLEncoder.encode(segment, "UTF-8")
                .replace("+", "%20")  // 공백 처리
        }
        
        val url = "$serverUrl$MODELS_PATH$encodedPath"
        Log.d(TAG, "getModelUrl: $relativePath -> $url")
        return url
    }
    
    /**
     * WebView에서 로드할 전체 URL 생성
     * 
     * 출력: "http://localhost:8080/?model=/models/..."
     */
    private fun getWebViewUrl(relativePath: String): String {
        // 경로 구분자 정규화
        val normalizedPath = relativePath.replace("\\", "/")
        
        // 각 세그먼트별 URL 인코딩
        val encodedPath = normalizedPath.split("/").joinToString("/") { segment ->
            URLEncoder.encode(segment, "UTF-8")
                .replace("+", "%20")
        }
        
        // 모델 경로
        val modelUrl = "$MODELS_PATH$encodedPath"
        
        // 쿼리 파라미터로 인코딩
        val encodedModelParam = URLEncoder.encode(modelUrl, "UTF-8")
        
        val url = "$serverUrl/?model=$encodedModelParam"
        Log.d(TAG, "getWebViewUrl: $relativePath -> $url")
        return url
    }
    
    override fun onDestroy() {
        super.onDestroy()
        stopServer()
    }
}

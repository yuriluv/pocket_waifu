package com.example.flutter_application_1

import android.Manifest
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.PowerManager
import android.provider.Settings
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
import com.example.flutter_application_1.live2d.Live2DPlugin

/**
 * 
 * 
 */
class MainActivity : FlutterActivity() {
    
    companion object {
        private const val TAG = "MainActivity"
        private const val CHANNEL_NAME = "com.example.flutter_application_1/live2d_loader"
        private const val REQUEST_NOTIFICATION_PERMISSION = 1001
        
        private const val SERVER_PORT = 8080
        private const val SERVER_HOST = "localhost"
        
        const val MODELS_PATH = "/models/"
        const val ASSETS_PATH = "/assets/"
    }
    
    private var modelRootPath: String? = null
    private val localServer = Live2DLocalServer.getInstance()
    
    val serverUrl: String get() = "http://$SERVER_HOST:$SERVER_PORT"
    
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            if (checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS)
                != PackageManager.PERMISSION_GRANTED) {
                Log.d(TAG, "알림 권한 요청 중...")
                requestPermissions(
                    arrayOf(Manifest.permission.POST_NOTIFICATIONS),
                    REQUEST_NOTIFICATION_PERMISSION
                )
            }
        }
        
        requestBatteryOptimizationExemption()
    }
    
    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == REQUEST_NOTIFICATION_PERMISSION) {
            if (grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED) {
                Log.d(TAG, "✅ 알림 권한 승인됨")
            } else {
                Log.w(TAG, "⚠️ 알림 권한 거부됨 - 포그라운드 서비스 알림이 표시되지 않을 수 있음")
            }
        }
    }
    
    /**
     * 
     */
    private fun requestBatteryOptimizationExemption() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
            if (!pm.isIgnoringBatteryOptimizations(packageName)) {
                Log.d(TAG, "배터리 최적화 제외 요청 중...")
                try {
                    val intent = Intent().apply {
                        action = Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS
                        data = Uri.parse("package:$packageName")
                    }
                    startActivity(intent)
                } catch (e: Exception) {
                    Log.w(TAG, "배터리 최적화 제외 요청 실패: ${e.message}")
                }
            } else {
                Log.d(TAG, "배터리 최적화 이미 제외됨")
            }
        }
    }
    
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        flutterEngine.plugins.add(Live2DPlugin())
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL_NAME).setMethodCallHandler { call, result ->
            Log.d(TAG, "MethodChannel 호출: ${call.method}")
            
            when (call.method) {
                "setModelRootPath" -> {
                    val path = call.argument<String>("path")
                    if (path != null) {
                        val success = setModelRootPath(path)
                        result.success(success)
                    } else {
                        result.error("INVALID_ARGUMENT", "path is required", null)
                    }
                }
                
                "stopServer" -> {
                    stopServer()
                    result.success(true)
                }
                
                "getModelUrl" -> {
                    val relativePath = call.argument<String>("relativePath")
                    if (relativePath != null) {
                        val url = getModelUrl(relativePath)
                        result.success(url)
                    } else {
                        result.error("INVALID_ARGUMENT", "relativePath is required", null)
                    }
                }
                
                "getWebViewUrl" -> {
                    val relativePath = call.argument<String>("relativePath")
                    if (relativePath != null) {
                        val url = getWebViewUrl(relativePath)
                        result.success(url)
                    } else {
                        result.error("INVALID_ARGUMENT", "relativePath is required", null)
                    }
                }
                
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
     */
    private fun setModelRootPath(path: String): Boolean {
        Log.d(TAG, "========================================")
        Log.d(TAG, "모델 루트 경로 설정 (v3.0 Kotlin 서버)")
        Log.d(TAG, "========================================")
        Log.d(TAG, "경로: $path")
        
        val dir = File(path)
        if (!dir.exists() || !dir.isDirectory) {
            Log.e(TAG, "❌ 디렉토리가 존재하지 않습니다: $path")
            return false
        }
        
        modelRootPath = path
        
        val assetsProvider: (String) -> InputStream? = { assetPath ->
            try {
                val flutterAssetPath = "flutter_assets/assets/$assetPath"
                Log.d(TAG, "Asset 요청: $assetPath -> $flutterAssetPath")
                assets.open(flutterAssetPath)
            } catch (e: Exception) {
                Log.w(TAG, "Asset 열기 실패: $assetPath (${e.message})")
                try {
                    assets.open(assetPath)
                } catch (e2: Exception) {
                    Log.w(TAG, "Fallback Asset도 실패: $assetPath")
                    null
                }
            }
        }
        
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
     */
    private fun stopServer() {
        localServer.stop()
        Log.d(TAG, "서버 중지됨")
    }
    
    /**
     * 
     */
    private fun getModelUrl(relativePath: String): String {
        val normalizedPath = relativePath.replace("\\", "/")
        
        val encodedPath = normalizedPath.split("/").joinToString("/") { segment ->
            URLEncoder.encode(segment, "UTF-8")
                .replace("+", "%20")
        }
        
        val url = "$serverUrl$MODELS_PATH$encodedPath"
        Log.d(TAG, "getModelUrl: $relativePath -> $url")
        return url
    }
    
    /**
     * 
     */
    private fun getWebViewUrl(relativePath: String): String {
        val normalizedPath = relativePath.replace("\\", "/")
        
        val encodedPath = normalizedPath.split("/").joinToString("/") { segment ->
            URLEncoder.encode(segment, "UTF-8")
                .replace("+", "%20")
        }
        
        val modelUrl = "$MODELS_PATH$encodedPath"
        
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

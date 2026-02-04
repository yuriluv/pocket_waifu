package com.example.flutter_application_1

import android.util.Log
import android.webkit.WebResourceResponse
import androidx.webkit.WebViewAssetLoader
import java.io.File
import java.io.FileInputStream
import java.io.InputStream
import java.net.URLDecoder

/**
 * 외부 저장소 파일을 WebView에 제공하는 커스텀 PathHandler
 * 
 * 가상 도메인: https://live2d.local/models/...
 * 실제 경로:   /storage/emulated/0/Personal/Apps/PocketWaifu/Live2D/...
 * 
 * 특징:
 * - 한글, 공백, 특수문자 경로 지원
 * - 대용량 파일 스트리밍 (InputStream 사용)
 * - 자동 MIME 타입 감지
 */
class ExternalStoragePathHandler(
    private val rootPath: String
) : WebViewAssetLoader.PathHandler {

    companion object {
        private const val TAG = "ExternalStorageHandler"
    }

    override fun handle(path: String): WebResourceResponse? {
        Log.d(TAG, "=== 파일 요청 ===")
        Log.d(TAG, "요청 경로 (원본): $path")
        
        try {
            // URL 디코딩 (다중 인코딩 처리)
            var decodedPath = path
            repeat(3) {
                val newDecoded = URLDecoder.decode(decodedPath, "UTF-8")
                if (newDecoded == decodedPath) return@repeat
                decodedPath = newDecoded
            }
            Log.d(TAG, "디코딩 경로: $decodedPath")
            
            // 전체 파일 경로 생성
            val file = File(rootPath, decodedPath)
            val absolutePath = file.absolutePath
            Log.d(TAG, "전체 경로: $absolutePath")
            
            // 보안: 경로 탈출 방지 (Path Traversal 공격 차단)
            if (!absolutePath.startsWith(rootPath)) {
                Log.e(TAG, "❌ 보안 위반: 루트 경로 외부 접근 시도")
                return null
            }
            
            // 파일 존재 확인
            if (!file.exists()) {
                Log.e(TAG, "❌ 파일 없음: $absolutePath")
                logDirectoryContents(file.parentFile)
                return null
            }
            
            if (!file.isFile) {
                Log.e(TAG, "❌ 파일이 아님 (디렉토리): $absolutePath")
                return null
            }
            
            // MIME 타입 결정
            val mimeType = getMimeType(file.name)
            Log.d(TAG, "✅ 파일 발견: ${file.length()} bytes, MIME: $mimeType")
            
            // 스트리밍 응답 생성 (대용량 파일 지원)
            val inputStream: InputStream = FileInputStream(file)
            
            return WebResourceResponse(
                mimeType,
                "UTF-8",
                200,
                "OK",
                mapOf(
                    "Access-Control-Allow-Origin" to "*",
                    "Access-Control-Allow-Methods" to "GET, HEAD, OPTIONS",
                    "Cache-Control" to "public, max-age=3600"
                ),
                inputStream
            )
            
        } catch (e: Exception) {
            Log.e(TAG, "❌ 파일 처리 오류: ${e.message}", e)
            return null
        }
    }
    
    /**
     * 파일 확장자에 따른 MIME 타입 반환
     */
    private fun getMimeType(fileName: String): String {
        val ext = fileName.substringAfterLast('.', "").lowercase()
        return when (ext) {
            // 웹 컨텐츠
            "html", "htm" -> "text/html"
            "js", "mjs" -> "application/javascript"
            "css" -> "text/css"
            
            // JSON
            "json" -> "application/json"
            
            // 이미지
            "png" -> "image/png"
            "jpg", "jpeg" -> "image/jpeg"
            "gif" -> "image/gif"
            "webp" -> "image/webp"
            "svg" -> "image/svg+xml"
            
            // Live2D 전용
            "moc3" -> "application/octet-stream"
            "physics3.json" -> "application/json"
            
            // 기타
            "wasm" -> "application/wasm"
            else -> "application/octet-stream"
        }
    }
    
    /**
     * 디버깅용: 디렉토리 내용 로깅
     */
    private fun logDirectoryContents(dir: File?) {
        if (dir == null || !dir.exists()) {
            Log.d(TAG, "부모 디렉토리 없음")
            return
        }
        
        Log.d(TAG, "📂 디렉토리 내용 (${dir.absolutePath}):")
        dir.listFiles()?.forEach { f ->
            val type = if (f.isDirectory) "📁" else "📄"
            Log.d(TAG, "  $type ${f.name}")
        }
    }
}

package com.example.flutter_application_1

import android.util.Log
import android.webkit.WebResourceResponse
import androidx.webkit.WebViewAssetLoader
import java.io.File
import java.io.FileInputStream
import java.io.InputStream
import java.net.URLDecoder

/**
 * 
 * 
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
            var decodedPath = path
            repeat(3) {
                val newDecoded = URLDecoder.decode(decodedPath, "UTF-8")
                if (newDecoded == decodedPath) return@repeat
                decodedPath = newDecoded
            }
            Log.d(TAG, "디코딩 경로: $decodedPath")
            
            val file = File(rootPath, decodedPath)
            val absolutePath = file.absolutePath
            Log.d(TAG, "전체 경로: $absolutePath")
            
            if (!absolutePath.startsWith(rootPath)) {
                Log.e(TAG, "❌ 보안 위반: 루트 경로 외부 접근 시도")
                return null
            }
            
            if (!file.exists()) {
                Log.e(TAG, "❌ 파일 없음: $absolutePath")
                logDirectoryContents(file.parentFile)
                return null
            }
            
            if (!file.isFile) {
                Log.e(TAG, "❌ 파일이 아님 (디렉토리): $absolutePath")
                return null
            }
            
            val mimeType = getMimeType(file.name)
            Log.d(TAG, "✅ 파일 발견: ${file.length()} bytes, MIME: $mimeType")
            
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
     */
    private fun getMimeType(fileName: String): String {
        val ext = fileName.substringAfterLast('.', "").lowercase()
        return when (ext) {
            "html", "htm" -> "text/html"
            "js", "mjs" -> "application/javascript"
            "css" -> "text/css"
            
            // JSON
            "json" -> "application/json"
            
            "png" -> "image/png"
            "jpg", "jpeg" -> "image/jpeg"
            "gif" -> "image/gif"
            "webp" -> "image/webp"
            "svg" -> "image/svg+xml"
            
            "moc3" -> "application/octet-stream"
            "physics3.json" -> "application/json"
            
            "wasm" -> "application/wasm"
            else -> "application/octet-stream"
        }
    }
    
    /**
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

package com.example.flutter_application_1

import android.util.Log
import android.webkit.MimeTypeMap
import java.io.*
import java.net.ServerSocket
import java.net.Socket
import java.net.URLDecoder
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors
import kotlin.concurrent.thread

/**
 * Live2D 모델 파일을 서빙하는 로컬 HTTP 서버 (Kotlin 네이티브)
 * 
 * 특징:
 * - 순수 Kotlin 구현 (외부 라이브러리 없음)
 * - URL 디코딩 완벽 지원 (한글, 공백, 특수문자)
 * - 대용량 파일 스트리밍
 * - Range 요청 지원
 * - CORS 헤더 완벽 지원
 */
class Live2DLocalServer private constructor() {
    
    companion object {
        private const val TAG = "Live2DLocalServer"
        private const val DEFAULT_PORT = 8080
        private const val BUFFER_SIZE = 8192 // 8KB 버퍼
        
        @Volatile
        private var instance: Live2DLocalServer? = null
        
        fun getInstance(): Live2DLocalServer {
            return instance ?: synchronized(this) {
                instance ?: Live2DLocalServer().also { instance = it }
            }
        }
    }
    
    private var serverSocket: ServerSocket? = null
    private var executor: ExecutorService? = null
    private var isRunning = false
    private var modelRootPath: String? = null
    private var assetsProvider: ((String) -> InputStream?)? = null
    
    val port: Int = DEFAULT_PORT
    val serverUrl: String get() = "http://localhost:$port"
    
    /**
     * 서버 시작
     * 
     * @param modelRoot 모델 파일들이 있는 루트 디렉토리 경로
     * @param assetsProvider 앱 내장 assets를 제공하는 함수
     */
    fun start(modelRoot: String, assetsProvider: ((String) -> InputStream?)?): Boolean {
        if (isRunning) {
            Log.d(TAG, "서버가 이미 실행 중입니다. 경로만 업데이트합니다.")
            modelRootPath = modelRoot
            this.assetsProvider = assetsProvider
            return true
        }
        
        return try {
            modelRootPath = modelRoot
            this.assetsProvider = assetsProvider
            
            // 기존 소켓 정리
            serverSocket?.close()
            
            // 서버 소켓 생성
            serverSocket = ServerSocket(port)
            serverSocket?.soTimeout = 0 // 무한 대기
            
            // 스레드 풀 생성 (최대 4개 동시 연결)
            executor = Executors.newFixedThreadPool(4)
            
            isRunning = true
            
            // 연결 수락 스레드 시작
            thread(name = "Live2DServer") {
                acceptConnections()
            }
            
            Log.i(TAG, "✅ 서버 시작됨: $serverUrl")
            Log.i(TAG, "📂 모델 루트: $modelRoot")
            true
        } catch (e: Exception) {
            Log.e(TAG, "❌ 서버 시작 실패: ${e.message}", e)
            isRunning = false
            false
        }
    }
    
    /**
     * 서버 중지
     */
    fun stop() {
        isRunning = false
        executor?.shutdownNow()
        executor = null
        try {
            serverSocket?.close()
        } catch (e: Exception) {
            // 무시
        }
        serverSocket = null
        Log.i(TAG, "서버 중지됨")
    }
    
    /**
     * 클라이언트 연결 수락 루프
     */
    private fun acceptConnections() {
        while (isRunning) {
            try {
                val clientSocket = serverSocket?.accept() ?: break
                executor?.submit {
                    handleClient(clientSocket)
                }
            } catch (e: Exception) {
                if (isRunning) {
                    Log.e(TAG, "연결 수락 오류: ${e.message}")
                }
            }
        }
    }
    
    /**
     * 클라이언트 요청 처리
     */
    private fun handleClient(socket: Socket) {
        try {
            socket.soTimeout = 30000 // 30초 타임아웃
            
            val input = BufferedReader(InputStreamReader(socket.getInputStream()))
            val output = BufferedOutputStream(socket.getOutputStream())
            
            // HTTP 요청 라인 읽기
            val requestLine = input.readLine() ?: return
            Log.d(TAG, "요청: $requestLine")
            
            // 헤더 읽기
            val headers = mutableMapOf<String, String>()
            var line: String?
            while (input.readLine().also { line = it } != null && line!!.isNotEmpty()) {
                val colonIndex = line!!.indexOf(':')
                if (colonIndex > 0) {
                    val key = line!!.substring(0, colonIndex).trim().lowercase()
                    val value = line!!.substring(colonIndex + 1).trim()
                    headers[key] = value
                }
            }
            
            // 요청 파싱
            val parts = requestLine.split(" ")
            if (parts.size < 2) {
                sendError(output, 400, "Bad Request")
                return
            }
            
            val method = parts[0]
            val rawPath = parts[1]
            
            // OPTIONS 요청 (Preflight)
            if (method == "OPTIONS") {
                sendOptions(output)
                return
            }
            
            // GET/HEAD 요청만 처리
            if (method != "GET" && method != "HEAD") {
                sendError(output, 405, "Method Not Allowed")
                return
            }
            
            // URL 경로 파싱 (쿼리 스트링 분리)
            val pathWithQuery = rawPath.split("?", limit = 2)
            val path = decodeUrlPath(pathWithQuery[0])
            
            Log.d(TAG, "디코딩된 경로: $path")
            
            // Range 헤더 확인
            val rangeHeader = headers["range"]
            
            // 라우팅
            when {
                path == "/" || path == "/index.html" || path.isEmpty() -> {
                    serveAsset(output, "web/index.html", rangeHeader)
                }
                path.startsWith("/models/") -> {
                    val relativePath = path.removePrefix("/models/")
                    serveModelFile(output, relativePath, rangeHeader, method == "HEAD")
                }
                path.startsWith("/assets/") -> {
                    val assetPath = path.removePrefix("/assets/")
                    serveAsset(output, assetPath, rangeHeader)
                }
                else -> {
                    sendError(output, 404, "Not Found: $path")
                }
            }
            
        } catch (e: Exception) {
            Log.e(TAG, "클라이언트 처리 오류: ${e.message}")
        } finally {
            try {
                socket.close()
            } catch (e: Exception) {
                // 무시
            }
        }
    }
    
    /**
     * URL 경로 디코딩 (다중 인코딩 처리)
     */
    private fun decodeUrlPath(encodedPath: String): String {
        var decoded = encodedPath
        repeat(5) {
            try {
                val newDecoded = URLDecoder.decode(decoded, "UTF-8")
                if (newDecoded == decoded) return decoded
                decoded = newDecoded
            } catch (e: Exception) {
                return decoded
            }
        }
        return decoded
    }
    
    /**
     * 모델 파일 서빙
     */
    private fun serveModelFile(
        output: BufferedOutputStream,
        relativePath: String,
        rangeHeader: String?,
        headOnly: Boolean
    ) {
        val rootPath = modelRootPath ?: run {
            sendError(output, 500, "Model root path not set")
            return
        }
        
        // 경로 탐색 공격 방지
        if (relativePath.contains("..")) {
            sendError(output, 403, "Forbidden")
            return
        }
        
        val filePath = File(rootPath, relativePath)
        
        if (!filePath.exists()) {
            Log.w(TAG, "파일 없음: ${filePath.absolutePath}")
            
            // 디버깅: 부모 디렉토리 내용 출력
            val parent = filePath.parentFile
            if (parent?.exists() == true) {
                val contents = parent.listFiles()?.take(10)?.joinToString { it.name } ?: "(empty)"
                Log.d(TAG, "부모 디렉토리 내용: $contents")
            }
            
            sendError(output, 404, "Not Found: $relativePath")
            return
        }
        
        if (!filePath.isFile) {
            sendError(output, 404, "Not a file: $relativePath")
            return
        }
        
        val fileSize = filePath.length()
        val mimeType = getMimeType(filePath.name)
        
        Log.d(TAG, "파일 서빙: ${filePath.name} ($fileSize bytes, $mimeType)")
        
        // Range 요청 처리
        if (rangeHeader != null && rangeHeader.startsWith("bytes=")) {
            servePartialContent(output, filePath, fileSize, mimeType, rangeHeader, headOnly)
        } else {
            serveFullContent(output, filePath, fileSize, mimeType, headOnly)
        }
    }
    
    /**
     * 앱 내장 asset 서빙
     */
    private fun serveAsset(output: BufferedOutputStream, assetPath: String, rangeHeader: String?) {
        val provider = assetsProvider ?: run {
            sendError(output, 500, "Assets provider not set")
            return
        }
        
        try {
            val inputStream = provider(assetPath) ?: run {
                sendError(output, 404, "Asset not found: $assetPath")
                return
            }
            
            val bytes = inputStream.readBytes()
            inputStream.close()
            
            val mimeType = getMimeType(assetPath)
            
            Log.d(TAG, "Asset 서빙: $assetPath (${bytes.size} bytes, $mimeType)")
            
            // 전체 응답
            val headers = buildString {
                appendLine("HTTP/1.1 200 OK")
                appendLine("Content-Type: $mimeType")
                appendLine("Content-Length: ${bytes.size}")
                appendLine("Accept-Ranges: bytes")
                appendLine("Cache-Control: public, max-age=3600")
                appendCorsHeaders()
                appendLine()
            }
            
            output.write(headers.toByteArray())
            output.write(bytes)
            output.flush()
            
        } catch (e: Exception) {
            Log.e(TAG, "Asset 서빙 실패: $assetPath", e)
            sendError(output, 500, "Error serving asset: ${e.message}")
        }
    }
    
    /**
     * 전체 파일 응답
     */
    private fun serveFullContent(
        output: BufferedOutputStream,
        file: File,
        fileSize: Long,
        mimeType: String,
        headOnly: Boolean
    ) {
        val headers = buildString {
            appendLine("HTTP/1.1 200 OK")
            appendLine("Content-Type: $mimeType")
            appendLine("Content-Length: $fileSize")
            appendLine("Accept-Ranges: bytes")
            appendLine("Cache-Control: public, max-age=3600")
            appendCorsHeaders()
            appendLine()
        }
        
        output.write(headers.toByteArray())
        
        if (!headOnly) {
            FileInputStream(file).use { fis ->
                val buffer = ByteArray(BUFFER_SIZE)
                var bytesRead: Int
                while (fis.read(buffer).also { bytesRead = it } != -1) {
                    output.write(buffer, 0, bytesRead)
                }
            }
        }
        
        output.flush()
    }
    
    /**
     * 부분 콘텐츠 응답 (Range 요청)
     */
    private fun servePartialContent(
        output: BufferedOutputStream,
        file: File,
        fileSize: Long,
        mimeType: String,
        rangeHeader: String,
        headOnly: Boolean
    ) {
        // Range: bytes=0-1023 형식 파싱
        val rangeSpec = rangeHeader.removePrefix("bytes=")
        val rangeParts = rangeSpec.split("-")
        
        val start = if (rangeParts[0].isNotEmpty()) rangeParts[0].toLong() else 0
        val end = if (rangeParts.size > 1 && rangeParts[1].isNotEmpty()) 
            rangeParts[1].toLong() else fileSize - 1
        
        // 범위 유효성 검사
        if (start >= fileSize || end >= fileSize || start > end) {
            val headers = buildString {
                appendLine("HTTP/1.1 416 Range Not Satisfiable")
                appendLine("Content-Range: bytes */$fileSize")
                appendCorsHeaders()
                appendLine()
            }
            output.write(headers.toByteArray())
            output.flush()
            return
        }
        
        val contentLength = end - start + 1
        
        val headers = buildString {
            appendLine("HTTP/1.1 206 Partial Content")
            appendLine("Content-Type: $mimeType")
            appendLine("Content-Length: $contentLength")
            appendLine("Content-Range: bytes $start-$end/$fileSize")
            appendLine("Accept-Ranges: bytes")
            appendCorsHeaders()
            appendLine()
        }
        
        output.write(headers.toByteArray())
        
        if (!headOnly) {
            RandomAccessFile(file, "r").use { raf ->
                raf.seek(start)
                val buffer = ByteArray(BUFFER_SIZE)
                var remaining = contentLength
                while (remaining > 0) {
                    val toRead = minOf(BUFFER_SIZE.toLong(), remaining).toInt()
                    val bytesRead = raf.read(buffer, 0, toRead)
                    if (bytesRead == -1) break
                    output.write(buffer, 0, bytesRead)
                    remaining -= bytesRead
                }
            }
        }
        
        output.flush()
    }
    
    /**
     * OPTIONS 응답 (CORS Preflight)
     */
    private fun sendOptions(output: BufferedOutputStream) {
        val headers = buildString {
            appendLine("HTTP/1.1 204 No Content")
            appendCorsHeaders()
            appendLine()
        }
        output.write(headers.toByteArray())
        output.flush()
    }
    
    /**
     * 에러 응답
     */
    private fun sendError(output: BufferedOutputStream, code: Int, message: String) {
        val body = """
            <!DOCTYPE html>
            <html>
            <head><title>$code $message</title></head>
            <body><h1>$code $message</h1></body>
            </html>
        """.trimIndent()
        
        val headers = buildString {
            appendLine("HTTP/1.1 $code $message")
            appendLine("Content-Type: text/html; charset=utf-8")
            appendLine("Content-Length: ${body.toByteArray().size}")
            appendCorsHeaders()
            appendLine()
        }
        
        output.write(headers.toByteArray())
        output.write(body.toByteArray())
        output.flush()
    }
    
    /**
     * CORS 헤더 추가
     */
    private fun StringBuilder.appendCorsHeaders() {
        appendLine("Access-Control-Allow-Origin: *")
        appendLine("Access-Control-Allow-Methods: GET, HEAD, OPTIONS")
        appendLine("Access-Control-Allow-Headers: Origin, X-Requested-With, Content-Type, Accept, Range")
        appendLine("Access-Control-Expose-Headers: Content-Length, Content-Range, Accept-Ranges")
        appendLine("Access-Control-Max-Age: 86400")
    }
    
    /**
     * MIME 타입 결정
     */
    private fun getMimeType(fileName: String): String {
        val ext = fileName.substringAfterLast('.', "").lowercase()
        return when (ext) {
            // 웹 콘텐츠
            "html", "htm" -> "text/html; charset=utf-8"
            "js", "mjs" -> "application/javascript; charset=utf-8"
            "css" -> "text/css; charset=utf-8"
            "json" -> "application/json; charset=utf-8"
            
            // 이미지
            "png" -> "image/png"
            "jpg", "jpeg" -> "image/jpeg"
            "gif" -> "image/gif"
            "webp" -> "image/webp"
            "svg" -> "image/svg+xml"
            "ico" -> "image/x-icon"
            
            // Live2D 전용
            "moc3", "moc" -> "application/octet-stream"
            "wasm" -> "application/wasm"
            "bin" -> "application/octet-stream"
            
            // 기본
            else -> MimeTypeMap.getSingleton().getMimeTypeFromExtension(ext)
                ?: "application/octet-stream"
        }
    }
}

package com.example.flutter_application_1.live2d.core

import android.os.Handler
import android.os.Looper
import android.util.Log
import com.example.flutter_application_1.live2d.Live2DEventStreamHandler

/**
 * Live2D 네이티브 로거
 * 
 * Native 측 로그를 수집하고 Flutter로 전달합니다.
 * 모든 Live2D 관련 컴포넌트에서 이 로거를 사용합니다.
 */
object Live2DLogger {
    
    private const val TAG = "Live2D"
    private const val DEFAULT_TAG = "General"
    
    // 로그 레벨
    enum class Level(val value: Int, val icon: String) {
        DEBUG(0, "🔍"),
        INFO(1, "ℹ️"),
        WARNING(2, "⚠️"),
        ERROR(3, "❌")
    }
    
    // 설정
    private var minLevel = Level.DEBUG
    private var isEnabled = true
    private var sendToFlutter = true
    
    private val mainHandler = Handler(Looper.getMainLooper())
    
    /**
     * 로깅 활성화/비활성화
     */
    fun setEnabled(enabled: Boolean) {
        isEnabled = enabled
    }
    
    /**
     * Flutter 전송 활성화/비활성화
     */
    fun setSendToFlutter(enabled: Boolean) {
        sendToFlutter = enabled
    }
    
    /**
     * 최소 로그 레벨 설정
     */
    fun setMinLevel(level: Level) {
        minLevel = level
    }
    
    /**
     * 디버그 로그 (간단 버전)
     */
    fun d(message: String, details: String?) {
        log(Level.DEBUG, DEFAULT_TAG, message, details)
    }
    
    /**
     * 정보 로그 (간단 버전)
     */
    fun i(message: String, details: String?) {
        log(Level.INFO, DEFAULT_TAG, message, details)
    }
    
    /**
     * 경고 로그 (간단 버전)
     */
    fun w(message: String, details: String?) {
        log(Level.WARNING, DEFAULT_TAG, message, details, null)
    }
    
    /**
     * 에러 로그 (간단 버전 - Exception 지원)
     */
    fun e(message: String, error: Throwable?) {
        log(Level.ERROR, DEFAULT_TAG, message, error?.message, error)
    }
    
    /**
     * 통합 로그 메서드
     */
    private fun log(
        level: Level,
        tag: String,
        message: String,
        details: String? = null,
        error: Throwable? = null
    ) {
        if (!isEnabled) return
        if (level.value < minLevel.value) return
        
        val fullTag = "$TAG:$tag"
        val fullMessage = buildString {
            append(message)
            if (details != null) {
                append(" | $details")
            }
        }
        
        // Android Logcat 출력
        when (level) {
            Level.DEBUG -> Log.d(fullTag, fullMessage, error)
            Level.INFO -> Log.i(fullTag, fullMessage, error)
            Level.WARNING -> Log.w(fullTag, fullMessage, error)
            Level.ERROR -> Log.e(fullTag, fullMessage, error)
        }
        
        // Flutter로 전송
        if (sendToFlutter) {
            sendLogToFlutter(level, tag, message, details, error)
        }
    }
    
    /**
     * Flutter로 로그 전송
     */
    private fun sendLogToFlutter(
        level: Level,
        tag: String,
        message: String,
        details: String?,
        error: Throwable?
    ) {
        mainHandler.post {
            try {
                Live2DEventStreamHandler.getInstance()?.sendEvent(
                    mapOf(
                        "type" to "nativeLog",
                        "level" to level.name.lowercase(),
                        "tag" to tag,
                        "message" to message,
                        "details" to details,
                        "error" to error?.message,
                        "stackTrace" to error?.stackTraceToString(),
                        "timestamp" to System.currentTimeMillis()
                    )
                )
            } catch (e: Exception) {
                Log.e(TAG, "Flutter로 로그 전송 실패", e)
            }
        }
    }
    
    // ============================================================================
    // 편의 메서드 - 특정 컴포넌트용
    // ============================================================================
    
    /**
     * OpenGL 관련 로그
     */
    object GL {
        private const val SUB_TAG = "OpenGL"
        
        fun d(message: String, details: String?) = logWithTag(Level.DEBUG, SUB_TAG, message, details, null)
        fun i(message: String, details: String?) = logWithTag(Level.INFO, SUB_TAG, message, details, null)
        fun w(message: String, details: String?) = logWithTag(Level.WARNING, SUB_TAG, message, details, null)
        fun e(message: String, details: String?) = logWithTag(Level.ERROR, SUB_TAG, message, details, null)
        fun e(message: String, error: Throwable) = logWithTag(Level.ERROR, SUB_TAG, message, null, error)
        fun e(message: String, details: String?, error: Throwable) = logWithTag(Level.ERROR, SUB_TAG, message, details, error)
    }
    
    /**
     * 오버레이 서비스 관련 로그
     */
    object Overlay {
        private const val SUB_TAG = "Overlay"
        
        fun d(message: String, details: String?) = logWithTag(Level.DEBUG, SUB_TAG, message, details, null)
        fun i(message: String, details: String?) = logWithTag(Level.INFO, SUB_TAG, message, details, null)
        fun w(message: String, details: String?) = logWithTag(Level.WARNING, SUB_TAG, message, details, null)
        fun e(message: String, details: String?) = logWithTag(Level.ERROR, SUB_TAG, message, details, null)
        fun e(message: String, error: Throwable) = logWithTag(Level.ERROR, SUB_TAG, message, null, error)
        fun e(message: String, details: String?, error: Throwable) = logWithTag(Level.ERROR, SUB_TAG, message, details, error)
    }
    
    /**
     * 모델 관련 로그
     */
    object Model {
        private const val SUB_TAG = "Model"
        
        fun d(message: String, details: String?) = logWithTag(Level.DEBUG, SUB_TAG, message, details, null)
        fun i(message: String, details: String?) = logWithTag(Level.INFO, SUB_TAG, message, details, null)
        fun w(message: String, details: String?) = logWithTag(Level.WARNING, SUB_TAG, message, details, null)
        fun e(message: String, details: String?) = logWithTag(Level.ERROR, SUB_TAG, message, details, null)
        fun e(message: String, error: Throwable) = logWithTag(Level.ERROR, SUB_TAG, message, null, error)
        fun e(message: String, details: String?, error: Throwable) = logWithTag(Level.ERROR, SUB_TAG, message, details, error)
    }
    
    /**
     * 렌더러 관련 로그
     */
    object Renderer {
        private const val SUB_TAG = "Renderer"
        
        fun d(message: String, details: String?) = logWithTag(Level.DEBUG, SUB_TAG, message, details, null)
        fun i(message: String, details: String?) = logWithTag(Level.INFO, SUB_TAG, message, details, null)
        fun w(message: String, details: String?) = logWithTag(Level.WARNING, SUB_TAG, message, details, null)
        fun e(message: String, details: String?) = logWithTag(Level.ERROR, SUB_TAG, message, details, null)
        fun e(message: String, error: Throwable) = logWithTag(Level.ERROR, SUB_TAG, message, null, error)
        fun e(message: String, details: String?, error: Throwable) = logWithTag(Level.ERROR, SUB_TAG, message, details, error)
    }
    
    /**
     * 상호작용 관련 로그
     */
    object Interaction {
        private const val SUB_TAG = "Interaction"
        
        fun d(message: String, details: String?) = logWithTag(Level.DEBUG, SUB_TAG, message, details, null)
        fun i(message: String, details: String?) = logWithTag(Level.INFO, SUB_TAG, message, details, null)
        fun w(message: String, details: String?) = logWithTag(Level.WARNING, SUB_TAG, message, details, null)
        fun e(message: String, details: String?) = logWithTag(Level.ERROR, SUB_TAG, message, details, null)
        fun e(message: String, error: Throwable) = logWithTag(Level.ERROR, SUB_TAG, message, null, error)
        fun e(message: String, details: String?, error: Throwable) = logWithTag(Level.ERROR, SUB_TAG, message, details, error)
    }
    
    /**
     * 태그가 포함된 내부 로그 메서드
     */
    private fun logWithTag(
        level: Level,
        tag: String,
        message: String,
        details: String?,
        error: Throwable?
    ) {
        log(level, tag, message, details, error)
    }
}

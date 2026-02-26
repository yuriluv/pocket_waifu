package com.example.flutter_application_1.live2d.core

import android.os.Handler
import android.os.Looper
import android.util.Log
import com.example.flutter_application_1.live2d.Live2DEventStreamHandler

/**
 * 
 */
object Live2DLogger {
    
    private const val TAG = "Live2D"
    private const val DEFAULT_TAG = "General"
    
    enum class Level(val value: Int, val icon: String) {
        DEBUG(0, "🔍"),
        INFO(1, "ℹ️"),
        WARNING(2, "⚠️"),
        ERROR(3, "❌")
    }
    
    private var minLevel = Level.DEBUG
    private var isEnabled = true
    private var sendToFlutter = true
    
    private const val MIN_THROTTLE_INTERVAL_MS = 2000L
    private val lastLogTimestamps = HashMap<String, Long>(64)

    private const val FLUTTER_THROTTLE_INTERVAL_MS = 3000L
    private val lastFlutterTimestamps = HashMap<String, Long>(64)

    private var lastCleanupTime = 0L
    private const val CLEANUP_INTERVAL_MS = 60_000L

    private val mainHandler = Handler(Looper.getMainLooper())
    
    /**
     */
    fun setEnabled(enabled: Boolean) {
        isEnabled = enabled
    }
    
    /**
     */
    fun setSendToFlutter(enabled: Boolean) {
        sendToFlutter = enabled
    }
    
    /**
     */
    fun setMinLevel(level: Level) {
        minLevel = level
    }
    
    /**
     */
    fun d(message: String, details: String?) {
        log(Level.DEBUG, DEFAULT_TAG, message, details)
    }
    
    /**
     */
    fun i(message: String, details: String?) {
        log(Level.INFO, DEFAULT_TAG, message, details)
    }
    
    /**
     */
    fun w(message: String, details: String?) {
        log(Level.WARNING, DEFAULT_TAG, message, details, null)
    }
    
    /**
     */
    fun e(message: String, error: Throwable?) {
        log(Level.ERROR, DEFAULT_TAG, message, error?.message, error)
    }
    
    /**
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
        
        val now = System.currentTimeMillis()
        if (level != Level.ERROR && level != Level.WARNING) {
            val throttleKey = "$tag:$message"
            val lastTime = lastLogTimestamps[throttleKey]
            if (lastTime != null && (now - lastTime) < MIN_THROTTLE_INTERVAL_MS) {
                return
            }
            lastLogTimestamps[throttleKey] = now
        }

        if (now - lastCleanupTime > CLEANUP_INTERVAL_MS) {
            lastCleanupTime = now
            lastLogTimestamps.entries.removeAll { (now - it.value) > CLEANUP_INTERVAL_MS }
            lastFlutterTimestamps.entries.removeAll { (now - it.value) > FLUTTER_THROTTLE_INTERVAL_MS }
        }
        
        val fullTag = "$TAG:$tag"
        val fullMessage = buildString {
            append(message)
            if (details != null) {
                append(" | $details")
            }
        }
        
        when (level) {
            Level.DEBUG -> Log.d(fullTag, fullMessage, error)
            Level.INFO -> Log.i(fullTag, fullMessage, error)
            Level.WARNING -> Log.w(fullTag, fullMessage, error)
            Level.ERROR -> Log.e(fullTag, fullMessage, error)
        }
        
        if (sendToFlutter) {
            val flutterKey = "$tag:$message"
            val lastFlutterTime = lastFlutterTimestamps[flutterKey]
            if (level == Level.ERROR || level == Level.WARNING ||
                lastFlutterTime == null || (now - lastFlutterTime) >= FLUTTER_THROTTLE_INTERVAL_MS) {
                lastFlutterTimestamps[flutterKey] = now
                sendLogToFlutter(level, tag, message, details, error)
            }
        }
    }
    
    /**
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
    // ============================================================================
    
    /**
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

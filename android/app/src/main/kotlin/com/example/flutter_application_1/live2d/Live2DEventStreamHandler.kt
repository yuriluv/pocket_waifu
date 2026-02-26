package com.example.flutter_application_1.live2d

import android.os.Handler
import android.os.Looper
import com.example.flutter_application_1.live2d.core.Live2DLogger
import io.flutter.plugin.common.EventChannel

/**
 * Live2D Event Stream Handler
 * 
 */
class Live2DEventStreamHandler : EventChannel.StreamHandler {
    
    companion object {
        @Volatile
        private var instance: Live2DEventStreamHandler? = null
        
        fun getInstance(): Live2DEventStreamHandler? = instance
    }
    
    private var eventSink: EventChannel.EventSink? = null
    private val mainHandler = Handler(Looper.getMainLooper())
    
    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        Live2DLogger.i("Event Stream 연결됨", null)
        eventSink = events
        instance = this
    }
    
    override fun onCancel(arguments: Any?) {
        Live2DLogger.i("Event Stream 연결 해제", null)
        eventSink = null
        if (instance == this) {
            instance = null
        }
    }
    
    /**
     */
    fun sendEvent(event: Map<String, Any?>) {
        mainHandler.post {
            try {
                eventSink?.success(event)
            } catch (e: Exception) {
                Live2DLogger.e("이벤트 전송 실패", e)
            }
        }
    }
    
    /**
     * 
     */
    fun sendInteractionEvent(
        type: String,
        x: Float? = null,
        y: Float? = null,
        extras: Map<String, Any?>? = null
    ) {
        val event = mutableMapOf<String, Any?>(
            "type" to type,
            "timestamp" to System.currentTimeMillis()
        )
        
        if (x != null) event["x"] = x
        if (y != null) event["y"] = y
        if (extras != null) event["extras"] = extras
        
        sendEvent(event)
        Live2DLogger.Interaction.d("이벤트 전송", type)
    }
    
    /**
     */
    fun sendSystemEvent(type: String, extras: Map<String, Any?>? = null) {
        sendInteractionEvent(type, extras = extras)
    }
    
    /**
     */
    fun sendOverlayShown() {
        sendSystemEvent("overlayShown")
    }
    
    /**
     */
    fun sendOverlayHidden() {
        sendSystemEvent("overlayHidden")
    }
    
    /**
     */
    fun sendModelLoaded(modelPath: String) {
        sendSystemEvent("modelLoaded", mapOf("path" to modelPath))
    }
    
    /**
     */
    fun sendModelUnloaded() {
        sendSystemEvent("modelUnloaded")
    }
    
    /**
     */
    fun sendMotionStarted(group: String, index: Int) {
        sendSystemEvent("motionStarted", mapOf("group" to group, "index" to index))
    }
    
    /**
     */
    fun sendMotionFinished(group: String, index: Int) {
        sendSystemEvent("motionFinished", mapOf("group" to group, "index" to index))
    }
    
    /**
     */
    fun sendGestureResult(gestureResult: Map<String, Any>) {
        sendEvent(gestureResult)
        Live2DLogger.Interaction.d("제스처 결과 전송", gestureResult["type"].toString())
    }
    
    /**
     */
    fun sendSignalReceived(signalName: String, data: Map<String, Any?>?) {
        sendSystemEvent("signalReceived", mapOf(
            "signal" to signalName,
            "data" to data
        ))
    }
    
    /**
     */
    fun sendError(code: String, message: String, details: Any? = null) {
        mainHandler.post {
            try {
                eventSink?.error(code, message, details)
            } catch (e: Exception) {
                Live2DLogger.e("에러 이벤트 전송 실패", e)
            }
        }
    }
}

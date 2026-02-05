package com.example.flutter_application_1.live2d

import android.os.Handler
import android.os.Looper
import com.example.flutter_application_1.live2d.core.Live2DLogger
import io.flutter.plugin.common.EventChannel

/**
 * Live2D Event Stream Handler
 * 
 * Native에서 Flutter로 이벤트를 전송하기 위한 핸들러입니다.
 * 상호작용 이벤트, 시스템 이벤트 등을 Flutter로 전달합니다.
 */
class Live2DEventStreamHandler : EventChannel.StreamHandler {
    
    companion object {
        // 싱글톤 인스턴스 (어디서든 이벤트 전송 가능하도록)
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
     * Flutter로 이벤트 전송 (Map 형태)
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
     * 상호작용 이벤트 전송
     * 
     * @param type 이벤트 유형 (tap, doubleTap, longPress, swipeUp 등)
     * @param x 터치 X 좌표 (nullable)
     * @param y 터치 Y 좌표 (nullable)
     * @param extras 추가 데이터 (nullable)
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
     * 시스템 이벤트 전송
     */
    fun sendSystemEvent(type: String, extras: Map<String, Any?>? = null) {
        sendInteractionEvent(type, extras = extras)
    }
    
    /**
     * 오버레이 표시됨 이벤트
     */
    fun sendOverlayShown() {
        sendSystemEvent("overlayShown")
    }
    
    /**
     * 오버레이 숨겨짐 이벤트
     */
    fun sendOverlayHidden() {
        sendSystemEvent("overlayHidden")
    }
    
    /**
     * 모델 로드됨 이벤트
     */
    fun sendModelLoaded(modelPath: String) {
        sendSystemEvent("modelLoaded", mapOf("path" to modelPath))
    }
    
    /**
     * 모델 언로드됨 이벤트
     */
    fun sendModelUnloaded() {
        sendSystemEvent("modelUnloaded")
    }
    
    /**
     * 모션 시작됨 이벤트
     */
    fun sendMotionStarted(group: String, index: Int) {
        sendSystemEvent("motionStarted", mapOf("group" to group, "index" to index))
    }
    
    /**
     * 모션 완료됨 이벤트
     */
    fun sendMotionFinished(group: String, index: Int) {
        sendSystemEvent("motionFinished", mapOf("group" to group, "index" to index))
    }
    
    /**
     * 제스처 결과 전송
     */
    fun sendGestureResult(gestureResult: Map<String, Any>) {
        sendEvent(gestureResult)
        Live2DLogger.Interaction.d("제스처 결과 전송", gestureResult["type"].toString())
    }
    
    /**
     * 외부 신호 수신 확인 이벤트
     */
    fun sendSignalReceived(signalName: String, data: Map<String, Any?>?) {
        sendSystemEvent("signalReceived", mapOf(
            "signal" to signalName,
            "data" to data
        ))
    }
    
    /**
     * 에러 이벤트 전송
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

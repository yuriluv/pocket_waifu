package com.example.flutter_application_1.live2d

import android.content.Context
import com.example.flutter_application_1.live2d.core.Live2DLogger
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

/**
 * Live2D Flutter Plugin
 * 
 */
class Live2DPlugin : FlutterPlugin {
    
    companion object {
        private const val CHANNEL_NAME = "com.example.flutter_application_1/live2d"
        private const val EVENT_CHANNEL_NAME = "com.example.flutter_application_1/live2d/events"
    }
    
    private var methodChannel: MethodChannel? = null
    private var eventChannel: EventChannel? = null
    private var methodHandler: Live2DMethodHandler? = null
    private var eventStreamHandler: Live2DEventStreamHandler? = null
    
    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        Live2DLogger.i("Plugin 연결됨", null)
        
        val context = binding.applicationContext
        
        eventStreamHandler = Live2DEventStreamHandler()
        
        methodHandler = Live2DMethodHandler(context, eventStreamHandler!!)
        
        methodChannel = MethodChannel(binding.binaryMessenger, CHANNEL_NAME).also {
            it.setMethodCallHandler(methodHandler)
        }
        
        eventChannel = EventChannel(binding.binaryMessenger, EVENT_CHANNEL_NAME).also {
            it.setStreamHandler(eventStreamHandler)
        }
        
        Live2DLogger.i("Plugin 초기화 완료", null)
    }
    
    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        Live2DLogger.i("Plugin 연결 해제", null)
        
        methodChannel?.setMethodCallHandler(null)
        methodChannel = null
        
        eventChannel?.setStreamHandler(null)
        eventChannel = null
        
        methodHandler?.dispose()
        methodHandler = null
        
        eventStreamHandler = null
    }
}

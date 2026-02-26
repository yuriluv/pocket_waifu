package com.example.flutter_application_1.live2d.core

import android.content.Context
import com.example.flutter_application_1.live2d.cubism.CubismFrameworkManager

/**
 * Live2D Cubism SDK Manager
 * 
 * 
 */
class Live2DManager private constructor() {
    
    companion object {
        @Volatile
        private var instance: Live2DManager? = null
        
        fun getInstance(): Live2DManager {
            return instance ?: synchronized(this) {
                instance ?: Live2DManager().also { instance = it }
            }
        }
    }
    
    /**
     * 
     * 
     */
    fun initialize(context: Context): Boolean {
        Live2DLogger.d("Live2DManager", "Delegating to CubismFrameworkManager")
        return CubismFrameworkManager.initialize(context)
    }
    
    /**
     * 
     */
    fun isSdkAvailable(): Boolean = CubismFrameworkManager.isSdkAvailable()
    
    /**
     * 
     */
    fun isReady(): Boolean = CubismFrameworkManager.isReady()
    
    /**
     * 
     */
    fun dispose() {
        CubismFrameworkManager.dispose()
    }
    
    /**
     */
    fun getVersion(): String = CubismFrameworkManager.getVersionString()
    
    /**
     */
    fun getStatusInfo(): Map<String, Any?> = CubismFrameworkManager.getStatusInfo()
}

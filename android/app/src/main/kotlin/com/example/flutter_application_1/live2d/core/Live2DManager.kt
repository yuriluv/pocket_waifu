package com.example.flutter_application_1.live2d.core

import android.content.Context
import com.example.flutter_application_1.live2d.cubism.CubismFrameworkManager

/**
 * Live2D Cubism SDK Manager
 * 
 * Live2D Cubism SDK의 초기화 및 관리를 담당합니다.
 * 실제 구현은 CubismFrameworkManager에 위임합니다.
 * 
 * 이 클래스는 기존 코드와의 호환성을 위해 유지됩니다.
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
     * Live2D Cubism SDK 초기화
     * 
     * MUST: GL 스레드에서 호출
     * 
     * @param context Android Context (현재 미사용, 향후 확장용)
     * @return 초기화 성공 여부
     */
    fun initialize(context: Context): Boolean {
        Live2DLogger.d("Live2DManager", "Delegating to CubismFrameworkManager")
        return CubismFrameworkManager.initialize(context)
    }
    
    /**
     * SDK 로드 상태 확인
     * 
     * @return 네이티브 라이브러리가 로드되었으면 true
     */
    fun isSdkAvailable(): Boolean = CubismFrameworkManager.isSdkAvailable()
    
    /**
     * 초기화 상태 확인
     * 
     * @return Framework가 초기화되었으면 true
     */
    fun isReady(): Boolean = CubismFrameworkManager.isReady()
    
    /**
     * SDK 정리
     * 
     * MUST: GL 스레드에서 호출
     */
    fun dispose() {
        CubismFrameworkManager.dispose()
    }
    
    /**
     * SDK 버전 정보 반환
     */
    fun getVersion(): String = CubismFrameworkManager.getVersionString()
    
    /**
     * 상태 정보 반환 (디버깅용)
     */
    fun getStatusInfo(): Map<String, Any?> = CubismFrameworkManager.getStatusInfo()
}

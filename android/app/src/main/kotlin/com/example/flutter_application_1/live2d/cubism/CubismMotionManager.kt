package com.example.flutter_application_1.live2d.cubism

import com.example.flutter_application_1.live2d.core.Live2DLogger
import com.example.flutter_application_1.live2d.core.Model3JsonParser
import java.io.File
import java.nio.ByteBuffer
import java.nio.ByteOrder

/**
 * CubismMotionManager - Live2D 모션 관리자
 * 
 * 모션 파일 로드, 재생, 우선순위 관리를 담당합니다.
 * 
 * 기능:
 * - motion3.json 로드 및 파싱
 * - 모션 큐 관리
 * - 우선순위 기반 재생
 * - Idle 루프 자동 재시작
 * - 페이드 인/아웃 처리
 * 
 * SDK 미설치 시 타이머 기반 시뮬레이션으로 동작합니다.
 * 
 * Thread Safety:
 * - update() is called from render thread
 * - startMotion() may be called from any thread
 * - release() must only be called once
 */
class CubismMotionManager(
    private val modelDir: File,
    private val parser: Model3JsonParser
) {
    companion object {
        private const val TAG = "CubismMotion"
        
        // 우선순위
        const val PRIORITY_NONE = 0
        const val PRIORITY_IDLE = 1
        const val PRIORITY_NORMAL = 2
        const val PRIORITY_FORCE = 3
        
        // 기본 페이드 시간
        const val DEFAULT_FADE_IN = 0.5f
        const val DEFAULT_FADE_OUT = 0.5f
    }
    
    // ============================================
    // SDK 모션 객체 (SDK 설치 후 타입 변경)
    // ============================================
    // private val loadedMotions = mutableMapOf<String, CubismMotion>()
    // private var currentMotion: CubismMotion? = null
    // ============================================
    
    // 로드된 모션 데이터 (바이너리)
    private val motionDataCache = mutableMapOf<String, ByteBuffer>()
    
    // 현재 재생 상태
    @Volatile private var currentGroup: String? = null
    @Volatile private var currentIndex: Int = 0
    @Volatile private var currentPriority: Int = PRIORITY_NONE
    @Volatile private var isLooping: Boolean = false
    
    // 모션 타이밍
    @Volatile private var motionTime: Float = 0f
    @Volatile private var motionDuration: Float = 3f  // 기본 모션 길이 추정
    private var fadeInTime: Float = DEFAULT_FADE_IN
    private var fadeOutTime: Float = DEFAULT_FADE_OUT
    
    // 재생 상태
    @Volatile private var isPlaying: Boolean = false
    @Volatile private var motionWeight: Float = 1f  // 페이드용 가중치
    @Volatile private var isReleased: Boolean = false
    
    // Idle 루프를 위한 저장
    private var idleGroup: String? = null
    private var idleIndex: Int = 0
    
    /**
     * 모든 모션 파일 사전 로드 (선택적)
     * 
     * 메모리를 더 사용하지만 재생 시 지연을 줄입니다.
     */
    fun preloadMotions() {
        var loadedCount = 0
        var totalCount = 0
        
        for ((groupName, motions) in parser.motionGroups) {
            for ((index, motionInfo) in motions.withIndex()) {
                totalCount++
                val key = "$groupName:$index"
                
                val motionFile = File(motionInfo.absolutePath)
                if (motionFile.exists()) {
                    try {
                        val buffer = loadMotionFile(motionFile)
                        if (buffer != null) {
                            motionDataCache[key] = buffer
                            loadedCount++
                        }
                    } catch (e: Exception) {
                        Live2DLogger.w("$TAG: Failed to preload", key)
                    }
                }
            }
        }
        
        Live2DLogger.i("$TAG: Preloaded motions", "$loadedCount/$totalCount")
    }
    
    /**
     * 모션 재생 시작
     * 
     * Thread-safe via synchronized block
     * 
     * @param group 모션 그룹 이름 (예: \"Idle\", \"TapBody\")
     * @param index 그룹 내 인덱스
     * @param priority 우선순위 (PRIORITY_* 상수)
     * @param loop 반복 재생 여부
     * @return 재생 시작 성공 여부
     */
    @Synchronized
    fun startMotion(
        group: String,
        index: Int,
        priority: Int = PRIORITY_NORMAL,
        loop: Boolean = false
    ): Boolean {
        if (isReleased) {
            Live2DLogger.d("$TAG: Cannot start - released", null)
            return false
        }
        
        // 우선순위 체크
        if (isPlaying && priority < currentPriority && priority != PRIORITY_FORCE) {
            Live2DLogger.d("$TAG: Motion blocked by priority", "$group:$index (current=$currentPriority)")
            return false
        }
        
        // 모션 그룹 확인
        val motionList = parser.motionGroups[group]
        if (motionList == null) {
            Live2DLogger.w("$TAG: Motion group not found", group)
            return false
        }
        
        if (index >= motionList.size) {
            Live2DLogger.w("$TAG: Motion index out of range", "$group:$index")
            return false
        }
        
        val motionInfo = motionList[index]
        
        // 모션 데이터 로드 (캐시에 없으면)
        val key = "$group:$index"
        if (!motionDataCache.containsKey(key)) {
            val motionFile = File(motionInfo.absolutePath)
            if (!motionFile.exists()) {
                Live2DLogger.w("$TAG: Motion file not found", motionInfo.absolutePath)
                return false
            }
            
            val buffer = loadMotionFile(motionFile)
            if (buffer == null) {
                Live2DLogger.w("$TAG: Failed to load motion", key)
                return false
            }
            motionDataCache[key] = buffer
        }
        
        // ============================================
        // SDK 모션 재생 (SDK 설치 후 활성화)
        // ============================================
        // val motionData = motionDataCache[key]
        // val motion = CubismMotion.create(motionData)
        // if (motion != null) {
        //     motion.setFadeInTime(motionInfo.fadeInTime.takeIf { it > 0 } ?: DEFAULT_FADE_IN)
        //     motion.setFadeOutTime(motionInfo.fadeOutTime.takeIf { it > 0 } ?: DEFAULT_FADE_OUT)
        //     motion.isLoop = loop
        //     currentMotion = motion
        // }
        // ============================================
        
        // 상태 업데이트
        currentGroup = group
        currentIndex = index
        currentPriority = priority
        isLooping = loop
        isPlaying = true
        motionTime = 0f
        motionWeight = 0f  // 페이드 인 시작
        
        // 페이드 시간 설정
        fadeInTime = motionInfo.fadeInTime.takeIf { it > 0 } ?: DEFAULT_FADE_IN
        fadeOutTime = motionInfo.fadeOutTime.takeIf { it > 0 } ?: DEFAULT_FADE_OUT
        
        // 모션 길이 추정 (motion3.json에서 읽거나 기본값 사용)
        motionDuration = estimateMotionDuration(motionInfo)
        
        // Idle 저장 (루프 재시작용)
        if (priority == PRIORITY_IDLE && loop) {
            idleGroup = group
            idleIndex = index
        }
        
        Live2DLogger.d("$TAG: ▶ Motion started", "$group:$index (loop=$loop, duration≈${motionDuration}s)")
        return true
    }
    
    /**
     * 현재 모션 정지
     */
    fun stopMotion() {
        // ============================================
        // SDK 모션 정지 (SDK 설치 후 활성화)
        // ============================================
        // currentMotion?.setIsFinished(true)
        // currentMotion = null
        // ============================================
        
        isPlaying = false
        currentPriority = PRIORITY_NONE
        currentGroup = null
        motionTime = 0f
        
        Live2DLogger.d("$TAG: ■ Motion stopped", null)
    }
    
    /**
     * 모든 모션 정지
     */
    fun stopAllMotions() {
        stopMotion()
        idleGroup = null
        idleIndex = 0
    }
    
    /**
     * 프레임 업데이트
     * 
     * Called from render thread, must be fast
     * 
     * @param deltaTime 프레임 시간 (초)
     */
    fun update(deltaTime: Float) {
        if (isReleased || !isPlaying) return
        
        val dt = deltaTime.coerceIn(0.001f, 0.1f)
        motionTime += dt
        
        // 페이드 인 처리
        if (motionTime < fadeInTime) {
            motionWeight = motionTime / fadeInTime
        }
        // 페이드 아웃 처리 (모션 끝 부분)
        else if (motionTime > (motionDuration - fadeOutTime)) {
            val remaining = motionDuration - motionTime
            motionWeight = (remaining / fadeOutTime).coerceIn(0f, 1f)
        }
        // 중간 구간
        else {
            motionWeight = 1f
        }
        
        // 모션 완료 체크
        if (motionTime >= motionDuration) {
            if (isLooping) {
                // 루프: 처음부터 다시
                motionTime = 0f
                motionWeight = 0f
                Live2DLogger.d("$TAG: ↻ Motion looped", "$currentGroup:$currentIndex")
            } else {
                // 완료: Idle로 복귀
                isPlaying = false
                currentPriority = PRIORITY_NONE
                Live2DLogger.d("$TAG: Motion finished", "$currentGroup:$currentIndex")
                
                // Idle 자동 재시작
                restartIdleMotion()
            }
        }
    }
    
    /**
     * SDK 모델에 모션 적용 (SDK 전용)
     * 
     * SDK 설치 후 LAppModel.update()에서 호출됩니다.
     */
    // fun updateMotion(model: CubismModel, deltaTime: Float): Boolean {
    //     if (currentMotion == null) return false
    //     
    //     val updated = currentMotion!!.updateParameters(model, deltaTime)
    //     
    //     if (currentMotion!!.isFinished()) {
    //         currentMotion = null
    //         currentPriority = PRIORITY_NONE
    //         restartIdleMotion()
    //         return false
    //     }
    //     
    //     return updated
    // }
    
    /**
     * 재생 상태 확인
     */
    fun isMotionPlaying(): Boolean = isPlaying
    
    /**
     * 현재 모션 정보
     */
    fun getCurrentMotion(): String? {
        return if (currentGroup != null) "$currentGroup:$currentIndex" else null
    }
    
    /**
     * 현재 모션 가중치 (페이드용)
     */
    fun getMotionWeight(): Float = motionWeight
    
    /**
     * 리소스 해제
     * 
     * Safe to call multiple times
     */
    @Synchronized
    fun release() {
        if (isReleased) {
            Live2DLogger.d("$TAG: Already released", null)
            return
        }
        
        Live2DLogger.d("$TAG: Releasing motion manager", null)
        
        stopAllMotions()
        
        // ============================================
        // SDK 모션 해제 (SDK 설치 후 활성화)
        // ============================================
        // try {
        //     loadedMotions.values.forEach { it.delete() }
        //     loadedMotions.clear()
        // } catch (e: Exception) {
        //     Live2DLogger.w("$TAG: SDK motion release error", e.message)
        // }
        // ============================================
        
        motionDataCache.clear()
        isReleased = true
        
        Live2DLogger.i("$TAG: ✓ Released", "cache cleared")
    }
    
    // === Private Methods ===
    
    /**
     * 모션 파일 로드
     */
    private fun loadMotionFile(file: File): ByteBuffer? {
        return try {
            val bytes = file.readBytes()
            val buffer = ByteBuffer.allocateDirect(bytes.size)
            buffer.order(ByteOrder.nativeOrder())
            buffer.put(bytes)
            buffer.position(0)
            buffer
        } catch (e: Exception) {
            Live2DLogger.e("$TAG: Failed to read motion file", e)
            null
        }
    }
    
    /**
     * 모션 길이 추정 (motion3.json 파싱 또는 기본값)
     */
    private fun estimateMotionDuration(motionInfo: Model3JsonParser.MotionInfo): Float {
        // TODO: motion3.json을 실제로 파싱하여 Meta.Duration 읽기
        // 현재는 기본값 사용
        return when {
            motionInfo.file.contains("idle", ignoreCase = true) -> 3f + (Math.random() * 2f).toFloat()
            motionInfo.file.contains("tap", ignoreCase = true) -> 1.5f
            else -> 2f
        }
    }
    
    /**
     * Idle 모션 자동 재시작
     * 
     * Called when a non-idle motion completes to resume idle animation
     */
    private fun restartIdleMotion() {
        if (isReleased) return
        
        if (idleGroup != null) {
            Live2DLogger.d("$TAG: Restarting idle motion", "$idleGroup:$idleIndex")
            startMotion(idleGroup!!, idleIndex, PRIORITY_IDLE, loop = true)
        }
    }
}

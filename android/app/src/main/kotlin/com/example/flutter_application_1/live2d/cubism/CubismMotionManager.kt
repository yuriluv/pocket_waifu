package com.example.flutter_application_1.live2d.cubism

import com.example.flutter_application_1.live2d.core.Live2DLogger
import com.example.flutter_application_1.live2d.core.Model3JsonParser
import java.io.File
import java.nio.ByteBuffer
import java.nio.ByteOrder

/**
 * 
 * 
 * 
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
        
        const val PRIORITY_NONE = 0
        const val PRIORITY_IDLE = 1
        const val PRIORITY_NORMAL = 2
        const val PRIORITY_FORCE = 3
        
        const val DEFAULT_FADE_IN = 0.5f
        const val DEFAULT_FADE_OUT = 0.5f
    }
    
    // ============================================
    // ============================================
    // private val loadedMotions = mutableMapOf<String, CubismMotion>()
    // private var currentMotion: CubismMotion? = null
    // ============================================
    
    private val motionDataCache = mutableMapOf<String, ByteBuffer>()
    
    @Volatile private var currentGroup: String? = null
    @Volatile private var currentIndex: Int = 0
    @Volatile private var currentPriority: Int = PRIORITY_NONE
    @Volatile private var isLooping: Boolean = false
    
    @Volatile private var motionTime: Float = 0f
    @Volatile private var motionDuration: Float = 3f
    private var fadeInTime: Float = DEFAULT_FADE_IN
    private var fadeOutTime: Float = DEFAULT_FADE_OUT
    
    @Volatile private var isPlaying: Boolean = false
    @Volatile private var motionWeight: Float = 1f
    @Volatile private var isReleased: Boolean = false
    
    private var idleGroup: String? = null
    private var idleIndex: Int = 0
    
    /**
     * 
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
     * 
     * Thread-safe via synchronized block
     * 
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
        
        if (isPlaying && priority < currentPriority && priority != PRIORITY_FORCE) {
            Live2DLogger.d("$TAG: Motion blocked by priority", "$group:$index (current=$currentPriority)")
            return false
        }
        
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
        
        currentGroup = group
        currentIndex = index
        currentPriority = priority
        isLooping = loop
        isPlaying = true
        motionTime = 0f
        motionWeight = 0f
        
        fadeInTime = motionInfo.fadeInTime.takeIf { it > 0 } ?: DEFAULT_FADE_IN
        fadeOutTime = motionInfo.fadeOutTime.takeIf { it > 0 } ?: DEFAULT_FADE_OUT
        
        motionDuration = estimateMotionDuration(motionInfo)
        
        if (priority == PRIORITY_IDLE && loop) {
            idleGroup = group
            idleIndex = index
        }
        
        Live2DLogger.d("$TAG: ▶ Motion started", "$group:$index (loop=$loop, duration≈${motionDuration}s)")
        return true
    }
    
    /**
     */
    fun stopMotion() {
        // ============================================
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
     */
    fun stopAllMotions() {
        stopMotion()
        idleGroup = null
        idleIndex = 0
    }
    
    /**
     * 
     * Called from render thread, must be fast
     * 
     */
    fun update(deltaTime: Float) {
        if (isReleased || !isPlaying) return
        
        val dt = deltaTime.coerceIn(0.001f, 0.1f)
        motionTime += dt
        
        if (motionTime < fadeInTime) {
            motionWeight = motionTime / fadeInTime
        }
        else if (motionTime > (motionDuration - fadeOutTime)) {
            val remaining = motionDuration - motionTime
            motionWeight = (remaining / fadeOutTime).coerceIn(0f, 1f)
        }
        else {
            motionWeight = 1f
        }
        
        if (motionTime >= motionDuration) {
            if (isLooping) {
                motionTime = 0f
                motionWeight = 0f
                Live2DLogger.d("$TAG: ↻ Motion looped", "$currentGroup:$currentIndex")
            } else {
                isPlaying = false
                currentPriority = PRIORITY_NONE
                Live2DLogger.d("$TAG: Motion finished", "$currentGroup:$currentIndex")
                
                restartIdleMotion()
            }
        }
    }
    
    /**
     * 
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
     */
    fun isMotionPlaying(): Boolean = isPlaying
    
    /**
     */
    fun getCurrentMotion(): String? {
        return if (currentGroup != null) "$currentGroup:$currentIndex" else null
    }
    
    /**
     */
    fun getMotionWeight(): Float = motionWeight
    
    /**
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
     */
    private fun estimateMotionDuration(motionInfo: Model3JsonParser.MotionInfo): Float {
        return when {
            motionInfo.file.contains("idle", ignoreCase = true) -> 3f + (Math.random() * 2f).toFloat()
            motionInfo.file.contains("tap", ignoreCase = true) -> 1.5f
            else -> 2f
        }
    }
    
    /**
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

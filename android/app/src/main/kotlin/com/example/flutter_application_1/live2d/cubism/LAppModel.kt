package com.example.flutter_application_1.live2d.cubism

import android.content.Context
import android.opengl.GLES20
import com.example.flutter_application_1.live2d.core.Live2DLogger
import com.example.flutter_application_1.live2d.core.Model3JsonParser
import java.io.File
import java.io.FileInputStream
import java.nio.ByteBuffer
import java.nio.ByteOrder

/**
 * 
 * 
 * 
 */
class LAppModel(
    private val modelDir: File,
    private val parser: Model3JsonParser
) {
    companion object {
        private const val TAG = "LAppModel"
        
        const val PRIORITY_NONE = 0
        const val PRIORITY_IDLE = 1
        const val PRIORITY_NORMAL = 2
        const val PRIORITY_FORCE = 3
    }
    
    // ============================================
    // ============================================
    @Volatile private var isSdkRenderingActive = false
    
    // Lifecycle state
    @Volatile private var isModelLoaded = false
    @Volatile private var isRendererInitialized = false
    @Volatile private var isReleased = false  // Prevents double-release
    
    private var mocBuffer: ByteBuffer? = null
    
    private val textureIds = mutableListOf<Int>()
    
    private val textureManager = CubismTextureManager()
    
    private var motionManager: CubismMotionManager? = null
    
    private var modelOpacity = 1.0f
    
    private var eyeBlinkTime = 0f
    private var nextBlinkTime = 3f
    private var isBlinking = false
    private var blinkProgress = 0f
    
    private var breathTime = 0f
    
    /**
     * 
     * 
     */
    fun loadModel(): Boolean {
        if (isReleased) {
            Live2DLogger.w("$TAG: Cannot load - already released", null)
            return false
        }
        
        if (isModelLoaded) {
            Live2DLogger.d("$TAG: Model already loaded", null)
            return true
        }
        
        Live2DLogger.d("$TAG: Loading model from", modelDir.absolutePath)
        
        try {
            val mocPath = parser.mocFile
            if (mocPath == null) {
                Live2DLogger.w("$TAG: moc3 path is null", null)
                return false
            }
            
            val mocFile = File(mocPath)
            if (!mocFile.exists()) {
                Live2DLogger.w("$TAG: moc3 file not found", mocPath)
                return false
            }
            
            mocBuffer = loadMocFile(mocFile)
            if (mocBuffer == null) {
                Live2DLogger.w("$TAG: Failed to load moc3 binary", null)
                return false
            }
            
            Live2DLogger.d("$TAG: moc3 loaded", "${mocFile.length()} bytes")
            
            // ============================================
            // ============================================
            if (CubismFrameworkManager.isSdkRenderingReady()) {
                Live2DLogger.i("$TAG: [Phase7-2] Creating CubismMoc via JNI", null)

                if (!Live2DNativeBridge.ensureLoaded()) {
                    Live2DLogger.e("$TAG: [Phase7-2] JNI library not loaded", null)
                    return false
                }

                val createResult = Live2DNativeBridge.nativeCreateModel(mocPath)
                if (!createResult) {
                    Live2DLogger.e("$TAG: [Phase7-2] nativeCreateModel failed", null)
                } else {
                    Live2DLogger.i("$TAG: [Phase7-2] moc3 loaded successfully", null)

                    val drawableCount = Live2DNativeBridge.nativeGetDrawableCount()
                    val paramCount = Live2DNativeBridge.nativeGetParameterCount()
                    val partCount = Live2DNativeBridge.nativeGetPartCount()
                    val canvasWidth = Live2DNativeBridge.nativeGetCanvasWidth()
                    val canvasHeight = Live2DNativeBridge.nativeGetCanvasHeight()

                    Live2DLogger.i("$TAG: [Phase7-2] Live2D model created", null)
                    Live2DLogger.i("$TAG: [Phase7-2]   Drawables: $drawableCount", null)
                    Live2DLogger.i("$TAG: [Phase7-2]   Parameters: $paramCount", null)
                    Live2DLogger.i("$TAG: [Phase7-2]   Parts: $partCount", null)
                    Live2DLogger.d("$TAG: [Phase7-2] Canvas size: ${canvasWidth}x${canvasHeight}", null)

                    isSdkRenderingActive = true
                    Live2DLogger.i("$TAG: [Phase7-2] SDK rendering mode ACTIVATED", null)
                }
            } else {
                Live2DLogger.w("$TAG: [Phase7-2] SDK not ready, moc3 loaded but model not created", null)
            }
            
            motionManager = CubismMotionManager(modelDir, parser)
            motionManager?.preloadMotions()
            
            isModelLoaded = true
            Live2DLogger.i("$TAG: ✓ Model loaded successfully", null)
            
            return true
            
        } catch (e: Exception) {
            Live2DLogger.e("$TAG: Model load exception", e)
            return false
        }
    }
    
    /**
     * 
     */
    fun initializeRenderer(): Boolean {
        if (!isModelLoaded) {
            Live2DLogger.e("$TAG: Model not loaded", null)
            return false
        }
        
        if (isRendererInitialized) {
            Live2DLogger.w("$TAG: Renderer already initialized", null)
            return true
        }
        
        try {
            for ((index, texturePath) in parser.textures.withIndex()) {
                val textureId = loadTexture(texturePath)
                textureIds.add(textureId)
                
                if (textureId != 0) {
                    Live2DLogger.d("$TAG: Texture[$index]", "ID=$textureId")
                } else {
                    Live2DLogger.w("$TAG: Failed to load texture[$index]", texturePath)
                }
            }
            
            // ============================================
            // ============================================
            if (isSdkRenderingActive) {
                Live2DLogger.i("$TAG: [Phase7-2] Initializing CubismRenderer (JNI)", null)

                val rendererResult = Live2DNativeBridge.nativeCreateRenderer()
                if (!rendererResult) {
                    Live2DLogger.e("$TAG: [Phase7-2] nativeCreateRenderer failed", null)
                    isSdkRenderingActive = false
                } else {
                    var boundTextureCount = 0
                    textureIds.forEachIndexed { index, textureId ->
                        if (textureId != 0) {
                            Live2DNativeBridge.nativeBindTexture(index, textureId)
                            boundTextureCount++
                        }
                    }

                    Live2DLogger.i("$TAG: [Phase7-2] CubismRenderer initialized", null)
                    Live2DLogger.i("$TAG: [Phase7-2]   Textures bound: $boundTextureCount", null)
                    Live2DLogger.i("$TAG: [Phase7-2]   Premultiplied alpha: true", null)
                }
            }

            isRendererInitialized = true
            Live2DLogger.i("$TAG: ✓ Renderer initialized", "textures=${textureIds.count { it != 0 }}, sdkMode=$isSdkRenderingActive")
            
            return true
            
        } catch (e: Exception) {
            Live2DLogger.e("$TAG: Renderer init exception", e)
            return false
        }
    }
    
    /**
     * 
     * Safe: Returns immediately if model not ready or released
     * 
     */
    fun update(deltaTime: Float) {
        if (isReleased || !isModelLoaded) return
        
        val dt = deltaTime.coerceIn(0.001f, 0.1f)
        
        // ============================================
        // ============================================
        if (isSdkRenderingActive) {
            try {
                Live2DNativeBridge.nativeUpdate()
            } catch (e: Exception) {
                Live2DLogger.w("$TAG: [Phase7-2] Model update exception", e.message)
            }
        }
        
        motionManager?.update(dt)
        
        updateEyeBlinkTimer(dt)
        updateBreathTimer(dt)
    }
    
    /**
     * 
     * Safe: Returns immediately if not ready or released
     * 
     */
    fun draw(mvpMatrix: FloatArray) {
        if (isReleased || !isModelLoaded || !isRendererInitialized) return
        
        // ============================================
        // ============================================
        if (isSdkRenderingActive) {
            try {
                Live2DNativeBridge.nativeDraw(mvpMatrix)
                return
            } catch (e: Exception) {
                Live2DLogger.w("$TAG: [Phase7-2] Draw exception", e.message)
            }
        }
        
    }
    
    /**
     */
    fun isSdkRendering(): Boolean = isSdkRenderingActive
    
    /**
     */
    fun startIdleMotion(): Boolean {
        motionManager?.let { mm ->
            val idleNames = listOf("Idle", "idle", "IDLE", "待機")
            
            for (name in idleNames) {
                if (mm.startMotion(name, 0, PRIORITY_IDLE, loop = true)) {
                    Live2DLogger.d("$TAG: Started idle motion", name)
                    return true
                }
            }
            
            parser.motionGroups.keys.firstOrNull()?.let { firstGroup ->
                if (mm.startMotion(firstGroup, 0, PRIORITY_IDLE, loop = true)) {
                    Live2DLogger.d("$TAG: Started first motion as idle", firstGroup)
                    return true
                }
            }
        }
        return false
    }
    
    /**
     */
    fun playMotion(group: String, index: Int, priority: Int): Boolean {
        return motionManager?.startMotion(group, index, priority) ?: false
    }
    
    /**
     */
    fun setOpacity(opacity: Float) {
        modelOpacity = opacity.coerceIn(0f, 1f)
    }
    
    /**
     */
    fun isLoaded(): Boolean = isModelLoaded
    
    /**
     */
    fun isRendererReady(): Boolean = isRendererInitialized
    
    /**
     */
    fun getFirstTextureId(): Int = textureIds.getOrNull(0) ?: 0
    
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
        
        Live2DLogger.d("$TAG: [Phase7-2] Releasing model", modelDir.name)
        
        try {
            motionManager?.release()
            motionManager = null
            
            try {
                textureManager.release()
                Live2DLogger.d("$TAG: TextureManager released", null)
            } catch (e: Exception) {
                Live2DLogger.w("$TAG: TextureManager release error", e.message)
            }
            textureIds.clear()
            
            // ============================================
            // ============================================
            try {
                Live2DLogger.d("$TAG: [Phase7-2] Releasing native model", null)
                Live2DNativeBridge.nativeReleaseModel()
                Live2DLogger.d("$TAG: [Phase7-2] Native model released", null)
            } catch (e: Exception) {
                Live2DLogger.w("$TAG: [Phase7-2] Native model release error", e.message)
            }

            isSdkRenderingActive = false
            
            mocBuffer = null
            
            isRendererInitialized = false
            isModelLoaded = false
            isReleased = true
            
            Live2DLogger.i("$TAG: [Phase7-2] ✓ Model released", modelDir.name)
            
        } catch (e: Exception) {
            Live2DLogger.e("$TAG: Release exception", e)
            isReleased = true  // Mark as released anyway to prevent retries
        }
    }
    
    // === Private Methods ===
    
    /**
     */
    private fun loadMocFile(file: File): ByteBuffer? {
        return try {
            val bytes = file.readBytes()
            val buffer = ByteBuffer.allocateDirect(bytes.size)
            buffer.order(ByteOrder.nativeOrder())
            buffer.put(bytes)
            buffer.position(0)
            buffer
        } catch (e: Exception) {
            Live2DLogger.e("$TAG: Failed to read moc3", e)
            null
        }
    }
    
    /**
     * 
     */
    private fun loadTexture(path: String): Int {
        return textureManager.loadTexture(path)
    }
    
    /**
     */
    private fun updateEyeBlinkTimer(dt: Float) {
        eyeBlinkTime += dt
        
        if (!isBlinking && eyeBlinkTime >= nextBlinkTime) {
            isBlinking = true
            blinkProgress = 0f
        }
        
        if (isBlinking) {
            blinkProgress += dt * 10f
            if (blinkProgress >= 1f) {
                isBlinking = false
                eyeBlinkTime = 0f
                nextBlinkTime = 2f + (Math.random() * 4f).toFloat()
            }
        }
    }
    
    /**
     */
    private fun updateBreathTimer(dt: Float) {
        breathTime += dt
    }
    
    // ============================================
    // ============================================
    
    /**
     */
    // private fun updateEyeBlink(model: CubismModel, dt: Float) {
    //     val leftEyeParamId = CubismFramework.getIdManager().getId("ParamEyeLOpen")
    //     val rightEyeParamId = CubismFramework.getIdManager().getId("ParamEyeROpen")
    //     
    //     if (isBlinking) {
    //         val blinkValue = if (blinkProgress < 0.5f) {
    //             1f - (blinkProgress * 2f)
    //         } else {
    //             (blinkProgress - 0.5f) * 2f
    //         }
    //         model.setParameterValue(leftEyeParamId, blinkValue)
    //         model.setParameterValue(rightEyeParamId, blinkValue)
    //     }
    // }
    
    /**
     */
    // private fun updateBreath(model: CubismModel, dt: Float) {
    //     val breathParamId = CubismFramework.getIdManager().getId("ParamBreath")
    //     val breathValue = (kotlin.math.sin(breathTime * 1.57f) + 1f) / 2f
    //     model.setParameterValue(breathParamId, breathValue)
    // }
}

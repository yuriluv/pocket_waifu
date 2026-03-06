package com.example.flutter_application_1.live2d.cubism

import android.content.Context
import android.opengl.GLES20
import com.example.flutter_application_1.live2d.core.Live2DLogger
import com.example.flutter_application_1.live2d.core.Model3JsonParser
import org.json.JSONObject
import java.io.File
import java.io.FileInputStream
import java.nio.ByteBuffer
import java.nio.ByteOrder
import kotlin.math.abs
import kotlin.math.exp
import kotlin.math.sin

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
    private var eyeBlinkEnabled = true
    private var eyeBlinkIntervalSeconds = 3f
    private var breathingEnabled = true
    private var breathCycleSeconds = 3.2f
    private var breathWeight = 1f
    private var lookAtEnabled = true
    private var lookAtTargetX = 0f
    private var lookAtTargetY = 0f
    private var lookAtActive = false
    private var lookAtCurrentX = 0f
    private var lookAtCurrentY = 0f
    private var physicsEnabled = true
    private var physicsFps = 30
    private var physicsDelayScale = 1f
    private var physicsMobilityScale = 1f
    private val availableParameterIds = mutableSetOf<String>()
    private var idleTime = 0f
    private var idlePhaseA = (Math.random().toFloat() * Math.PI.toFloat() * 2f)
    private var idlePhaseB = (Math.random().toFloat() * Math.PI.toFloat() * 2f)
    private var headLagX = 0f
    private var headLagY = 0f
    private var secondsSinceLookAtInput = 999f
    private val idleGazeResumeDelaySeconds = 0.75f

    private data class ExpressionParam(
        val id: String,
        val value: Float,
        val blend: String,
    )

    private data class ActiveExpression(
        val name: String,
        val fadeIn: Float,
        val fadeOut: Float,
        val params: List<ExpressionParam>,
        var weight: Float,
    )

    private val expressionCache = mutableMapOf<String, ActiveExpression>()
    private var currentExpression: ActiveExpression? = null
    private var previousExpression: ActiveExpression? = null
    private val parameterWriteCache = mutableMapOf<String, Float>()
    
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
                    refreshAvailableParameterIds()
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

        if (lookAtEnabled && lookAtActive) {
            secondsSinceLookAtInput = 0f
        } else {
            secondsSinceLookAtInput += dt
        }

        updateLookAt(dt)
        updateIdleMotion(dt)
        updateExpression(dt)

        if (eyeBlinkEnabled) {
            updateEyeBlinkTimer(dt)
        } else {
            applyParameterIfExists("ParamEyeLOpen", 1f)
            applyParameterIfExists("ParamEyeROpen", 1f)
        }

        if (breathingEnabled) {
            updateBreathTimer(dt)
        } else {
            applyParameterIfExists("ParamBreath", 0f)
        }
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
            availableParameterIds.clear()
            parameterWriteCache.clear()
            expressionCache.clear()
            currentExpression = null
            previousExpression = null
            
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
            val blinkValue = if (blinkProgress < 0.5f) {
                1f - (blinkProgress * 2f)
            } else {
                (blinkProgress - 0.5f) * 2f
            }.coerceIn(0f, 1f)
            applyParameterIfExists("ParamEyeLOpen", blinkValue)
            applyParameterIfExists("ParamEyeROpen", blinkValue)

            if (blinkProgress >= 1f) {
                isBlinking = false
                eyeBlinkTime = 0f
                val minInterval = (eyeBlinkIntervalSeconds * 0.6f).coerceAtLeast(0.5f)
                val maxInterval = (eyeBlinkIntervalSeconds * 1.4f).coerceAtLeast(minInterval)
                nextBlinkTime = minInterval + (Math.random().toFloat() * (maxInterval - minInterval))
                applyParameterIfExists("ParamEyeLOpen", 1f)
                applyParameterIfExists("ParamEyeROpen", 1f)
            }
        }
    }
    
    /**
     */
    private fun updateBreathTimer(dt: Float) {
        breathTime += dt
        val angularFrequency = (Math.PI * 2.0 / breathCycleSeconds.coerceAtLeast(1f)).toFloat()
        val base = (sin(breathTime * angularFrequency) + 1f) / 2f
        val breathValue = (base * breathWeight).coerceIn(0f, 1f)
        applyParameterIfExists("ParamBreath", breathValue)
    }

    private fun updateLookAt(dt: Float) {
        val idleGazeEnabled = secondsSinceLookAtInput >= idleGazeResumeDelaySeconds
        val idleGazeX =
            (sin((idleTime * 0.37f) + idlePhaseA) * 0.07f) +
                (sin((idleTime * 0.91f) + idlePhaseB) * 0.03f)
        val idleGazeY =
            (sin((idleTime * 0.29f) + (idlePhaseA * 0.5f)) * 0.04f)
        val targetX = if (lookAtEnabled && lookAtActive) {
            lookAtTargetX
        } else if (idleGazeEnabled) {
            idleGazeX
        } else {
            0f
        }
        val targetY = if (lookAtEnabled && lookAtActive) {
            lookAtTargetY
        } else if (idleGazeEnabled) {
            idleGazeY
        } else {
            0f
        }
        val tau = if (physicsEnabled) {
            (0.11f * physicsDelayScale.coerceIn(0.1f, 3f)).coerceIn(0.04f, 0.35f)
        } else {
            0.06f
        }
        val smoothing = (1f - exp(-dt / tau)).coerceIn(0.02f, 0.85f)

        lookAtCurrentX += (targetX - lookAtCurrentX) * smoothing
        lookAtCurrentY += (targetY - lookAtCurrentY) * smoothing

        val clampedX = lookAtCurrentX.coerceIn(-1f, 1f)
        val clampedY = lookAtCurrentY.coerceIn(-1f, 1f)
        val mobility = physicsMobilityScale.coerceIn(0.1f, 3f)

        val lagSmoothing = (1f - exp(-dt / 0.22f)).coerceIn(0.01f, 0.45f)
        headLagX += ((clampedX * 0.65f) - headLagX) * lagSmoothing
        headLagY += ((clampedY * 0.65f) - headLagY) * lagSmoothing

        applyParameterIfExists("ParamEyeBallX", clampedX)
        applyParameterIfExists("ParamEyeBallY", clampedY)
        applyParameterIfExists(
            "ParamAngleX",
            ((clampedX * 24f * mobility) + (headLagX * 10f)).coerceIn(-30f, 30f),
        )
        applyParameterIfExists(
            "ParamAngleY",
            ((clampedY * 18f * mobility) + (headLagY * 8f)).coerceIn(-30f, 30f),
        )
    }

    private fun updateIdleMotion(dt: Float) {
        idleTime += dt
        val idleSwayX =
            (sin((idleTime * 0.80f) + idlePhaseA) * 3.0f) +
                (sin((idleTime * 1.65f) + idlePhaseB) * 1.2f)
        val idleSwayY =
            (sin((idleTime * 0.55f) + (idlePhaseA * 0.7f)) * 2.0f)
        val bodySway = sin((idleTime * 0.42f) + (idlePhaseB * 0.6f)) * 4.5f
        val breathLinked = sin((breathTime * 0.9f) + idlePhaseA) * 2.0f

        applyParameterIfExists("ParamAngleX", idleSwayX.coerceIn(-10f, 10f), addMode = true)
        applyParameterIfExists("ParamAngleY", idleSwayY.coerceIn(-8f, 8f), addMode = true)
        applyParameterIfExists("ParamBodyAngleX", bodySway.coerceIn(-12f, 12f), addMode = true)
        applyParameterIfExists("ParamAngleZ", breathLinked.coerceIn(-6f, 6f), addMode = true)
    }

    private fun updateExpression(dt: Float) {
        previousExpression?.let { prev ->
            val fadeOut = prev.fadeOut.coerceAtLeast(0.02f)
            prev.weight = (prev.weight - (dt / fadeOut)).coerceIn(0f, 1f)
            applyExpression(prev)
            if (prev.weight <= 0.001f) {
                previousExpression = null
            }
        }

        currentExpression?.let { cur ->
            val fadeIn = cur.fadeIn.coerceAtLeast(0.02f)
            cur.weight = (cur.weight + (dt / fadeIn)).coerceIn(0f, 1f)
            applyExpression(cur)
        }
    }

    private fun applyExpression(expression: ActiveExpression) {
        val weight = expression.weight.coerceIn(0f, 1f)
        if (weight <= 0f) {
            return
        }

        for (param in expression.params) {
            val current = Live2DNativeBridge.safeGetParameterValue(param.id) ?: continue
            val next = when (param.blend) {
                "add" -> current + (param.value * weight)
                "multiply" -> current * (1f + ((param.value - 1f) * weight))
                else -> current + ((param.value - current) * weight)
            }
            applyParameterIfExists(param.id, next)
        }
    }

    fun setExpression(expression: Model3JsonParser.ExpressionInfo): Boolean {
        val cached = expressionCache[expression.name]
        val prepared = cached ?: loadExpression(expression) ?: return false
        val started = prepared.copy(weight = 0f)
        previousExpression = currentExpression
        currentExpression = started
        expressionCache[expression.name] = prepared
        return true
    }

    private fun loadExpression(expression: Model3JsonParser.ExpressionInfo): ActiveExpression? {
        return try {
            val raw = File(expression.absolutePath).readText()
            val json = JSONObject(raw)
            val fadeIn = json.optDouble("FadeInTime", 0.2).toFloat().coerceAtLeast(0.02f)
            val fadeOut = json.optDouble("FadeOutTime", 0.2).toFloat().coerceAtLeast(0.02f)
            val paramsJson = json.optJSONArray("Parameters") ?: return null
            val params = mutableListOf<ExpressionParam>()
            for (index in 0 until paramsJson.length()) {
                val item = paramsJson.optJSONObject(index) ?: continue
                val id = item.optString("Id", "").trim()
                if (id.isEmpty()) continue
                val value = item.optDouble("Value", 0.0).toFloat()
                val blend = item.optString("Blend", "Overwrite").lowercase()
                params.add(ExpressionParam(id = id, value = value, blend = blend))
            }
            if (params.isEmpty()) {
                return null
            }
            ActiveExpression(
                name = expression.name,
                fadeIn = fadeIn,
                fadeOut = fadeOut,
                params = params,
                weight = 0f,
            )
        } catch (t: Throwable) {
            Live2DLogger.w("$TAG: Failed to load expression ${expression.name}", t.message)
            null
        }
    }

    private fun refreshAvailableParameterIds() {
        availableParameterIds.clear()
        parameterWriteCache.clear()
        try {
            availableParameterIds.addAll(Live2DNativeBridge.safeGetParameterIds())
        } catch (t: Throwable) {
            Live2DLogger.w("$TAG: Failed to query parameter IDs", t.message)
        }
    }

    private fun applyParameterIfExists(paramId: String, value: Float, addMode: Boolean = false) {
        if (!isSdkRenderingActive) return
        if (!availableParameterIds.contains(paramId)) return
        try {
            val finalValue = if (addMode) {
                val current = Live2DNativeBridge.safeGetParameterValue(paramId) ?: return
                current + value
            } else {
                value
            }

            val previous = parameterWriteCache[paramId]
            if (previous != null && abs(previous - finalValue) < 0.0005f) {
                return
            }
            Live2DNativeBridge.safeSetParameterValue(paramId, finalValue)
            parameterWriteCache[paramId] = finalValue
        } catch (t: Throwable) {
            Live2DLogger.w("$TAG: Failed to set parameter $paramId", t.message)
        }
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

    fun setEyeBlinkEnabled(enabled: Boolean) {
        eyeBlinkEnabled = enabled
    }

    fun setEyeBlinkInterval(intervalSeconds: Float) {
        eyeBlinkIntervalSeconds = intervalSeconds.coerceIn(0.5f, 12f)
    }

    fun setBreathingEnabled(enabled: Boolean) {
        breathingEnabled = enabled
    }

    fun setBreathConfig(cycleSeconds: Float, weight: Float) {
        breathCycleSeconds = cycleSeconds.coerceIn(1f, 12f)
        breathWeight = weight.coerceIn(0f, 2f)
    }

    fun setLookAtEnabled(enabled: Boolean) {
        lookAtEnabled = enabled
        if (!enabled) {
            lookAtActive = false
            lookAtTargetX = 0f
            lookAtTargetY = 0f
            lookAtCurrentX = 0f
            lookAtCurrentY = 0f
            headLagX = 0f
            headLagY = 0f
            secondsSinceLookAtInput = idleGazeResumeDelaySeconds
        }
    }

    fun setLookAtTarget(x: Float, y: Float) {
        lookAtTargetX = x
        lookAtTargetY = y
        lookAtActive = true
        secondsSinceLookAtInput = 0f
    }

    fun clearLookAtTarget() {
        lookAtActive = false
        lookAtTargetX = 0f
        lookAtTargetY = 0f
    }

    fun setPhysicsEnabled(enabled: Boolean) {
        physicsEnabled = enabled
    }

    fun setPhysicsConfig(fps: Int, delayScale: Float, mobilityScale: Float) {
        physicsFps = fps.coerceIn(1, 120)
        physicsDelayScale = delayScale.coerceIn(0.1f, 3f)
        physicsMobilityScale = mobilityScale.coerceIn(0.1f, 3f)
    }
}

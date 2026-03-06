package com.example.flutter_application_1.live2d.renderer

import android.content.Context
import android.opengl.GLES20
import android.opengl.GLSurfaceView
import android.opengl.Matrix
import com.example.flutter_application_1.live2d.core.Live2DLogger
import com.example.flutter_application_1.live2d.core.Live2DManager
import com.example.flutter_application_1.live2d.core.Live2DModel
import com.example.flutter_application_1.live2d.cubism.CubismFrameworkManager
import com.example.flutter_application_1.live2d.cubism.CubismModel
import com.example.flutter_application_1.live2d.cubism.Live2DNativeBridge
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.nio.FloatBuffer
import javax.microedition.khronos.egl.EGLConfig
import javax.microedition.khronos.opengles.GL10

/**
 * Live2D OpenGL Renderer
 * 
 * 
 */
class Live2DGLRenderer(private val context: Context) : GLSurfaceView.Renderer {

    data class ParameterUpdate(
        val paramId: String,
        val targetValue: Float,
        val durationMs: Int,
        var startValue: Float? = null,
        var elapsedMs: Float = 0f
    )
    
    companion object {
        private const val TAG = "Live2DGLRenderer"
        private const val DEFAULT_FPS = 60
        private const val LOW_POWER_FPS = 30
        
        // ========== FBO Alpha Fix Shader ==========
        
        private const val ALPHA_FIX_VERTEX_SHADER = """
            attribute vec2 aPosition;
            attribute vec2 aTexCoord;
            varying vec2 vTexCoord;
            void main() {
                gl_Position = vec4(aPosition, 0.0, 1.0);
                vTexCoord = aTexCoord;
            }
        """
        
        private const val ALPHA_FIX_FRAGMENT_SHADER = """
            precision mediump float;
            uniform sampler2D uTexture;
            uniform float uCharacterOpacity;
            varying vec2 vTexCoord;
            void main() {
                vec4 c = texture2D(uTexture, vTexCoord);
                if (c.a < 0.004) {
                    gl_FragColor = vec4(0.0, 0.0, 0.0, 0.0);
                } else if (c.a >= 0.5) {
                    gl_FragColor = vec4(c.rgb / c.a * uCharacterOpacity, uCharacterOpacity);
                } else {
                    float newAlpha = min(c.a * 2.0, 1.0) * uCharacterOpacity;
                    gl_FragColor = vec4((c.rgb / c.a) * newAlpha, newAlpha);
                }
            }
        """
    }
    
    private val projectionMatrix = FloatArray(16)
    private val viewMatrix = FloatArray(16)
    private val mvpMatrix = FloatArray(16)
    
    private var surfaceWidth = 0
    private var surfaceHeight = 0
    private var isReady = false
    private var isPaused = false
    
    @Volatile private var isDisposed = false
    
    private var bgRed = 0f
    private var bgGreen = 0f
    private var bgBlue = 0f
    private var bgAlpha = 0f
    
    // ========== FBO Alpha Fix ==========
    private var fbo = 0
    private var fboTexture = 0
    private var fboWidth = 0
    private var fboHeight = 0
    private var alphaFixProgram = 0
    private var alphaFixQuadBuffer: FloatBuffer? = null
    
    @Volatile private var characterOpacity = 1.0f
    
    @Volatile private var relativeCharacterScale = 1.0f
    @Volatile private var characterOffsetPixelX = 0f
    @Volatile private var characterOffsetPixelY = 0f
    @Volatile private var characterRotationDeg = 0
    
    // ============================================
    // ============================================
    //
    // 
    //
    // ============================================
    
    private var cubismModel: CubismModel? = null
    
    private var currentModel: Live2DModel? = null
    
    private var pendingModelPath: String? = null
    private var pendingModelName: String? = null
    
    private var savedModelPath: String? = null
    private var savedModelName: String? = null
    
    private var lastFrameTimeNs = 0L
    private var targetFps = DEFAULT_FPS
    private var frameTimeNs = 1_000_000_000L / targetFps
    
    private var lookAtX = 0f
    private var lookAtY = 0f
    private var isLookAtActive = false
    private var lookAtEnabled = true
    private var eyeBlinkEnabled = true
    private var eyeBlinkIntervalSeconds = 3f
    private var breathingEnabled = true
    private var breathCycleSeconds = 3.2f
    private var breathWeight = 1.0f
    private var physicsEnabled = true
    private var physicsFps = 30
    private var physicsDelayScale = 1.0f
    private var physicsMobilityScale = 1.0f
    
    private var placeholderShader: PlaceholderShader? = null
    private var textureRenderer: TextureModelRenderer? = null
    
    private var enableFpsLimit = true
    private var lowPowerMode = false

    private val pendingParameterUpdates = mutableListOf<ParameterUpdate>()
    
    @Volatile private var fboPathLogged = false
    
    private var frameCount = 0L
    private var lastMetricTime = 0L
    private var droppedFrames = 0L
    private var measuredFps = 0f
    private var lowFpsWarnCooldownUntilMs = 0L
    private val editedMvpMatrix = FloatArray(16)
    
    @Volatile private var isOverlayInvisible = false
    
    override fun onSurfaceCreated(gl: GL10?, config: EGLConfig?) {
        Live2DLogger.Renderer.i("Surface created", "OpenGL ES 2.0 초기화 시작")
        
        val wasReady = isReady
        
        GLES20.glClearColor(bgRed, bgGreen, bgBlue, bgAlpha)
        GLES20.glEnable(GLES20.GL_BLEND)
        GLES20.glBlendFunc(GLES20.GL_SRC_ALPHA, GLES20.GL_ONE_MINUS_SRC_ALPHA)
        
        GLES20.glDisable(GLES20.GL_DEPTH_TEST)
        
        val glVersion = GLES20.glGetString(GLES20.GL_VERSION)
        val glVendor = GLES20.glGetString(GLES20.GL_VENDOR)
        val glRenderer = GLES20.glGetString(GLES20.GL_RENDERER)
        Live2DLogger.GL.i("OpenGL 정보", "Version: $glVersion, Vendor: $glVendor, Renderer: $glRenderer")
        
        // ============================================
        // ============================================
        val sdkResult = CubismFrameworkManager.initialize(context)
        val sdkStatus = CubismFrameworkManager.getStatusInfo()
        Live2DLogger.Renderer.i("Cubism Framework", 
            "초기화=${if (sdkResult) "성공" else "실패"}, " +
            "SDK=${sdkStatus["sdkLoaded"]}, mode=${sdkStatus["mode"]}")
        
        if (CubismFrameworkManager.isSdkRenderingReady()) {
            Live2DLogger.Renderer.i("[Phase7-2] SDK rendering READY", 
                "version=${CubismFrameworkManager.getVersionString()}")
        } else {
            Live2DLogger.Renderer.w("[Phase7-2] SDK rendering NOT ready", 
                "fallback mode active")
        }
        
        placeholderShader = PlaceholderShader()
        val shaderResult = placeholderShader?.initialize() ?: false
        Live2DLogger.GL.d("플레이스홀더 셰이더", if (shaderResult) "초기화 성공" else "초기화 실패")
        
        textureRenderer = TextureModelRenderer()
        val textureResult = textureRenderer?.initialize() ?: false
        Live2DLogger.GL.d("텍스처 렌더러", if (textureResult) "초기화 성공" else "초기화 실패")
        
        initAlphaFixShader()
        Live2DLogger.GL.d("Alpha Fix 셰이더", if (alphaFixProgram != 0) "초기화 성공" else "초기화 실패")
        
        isReady = true
        lastFrameTimeNs = System.nanoTime()
        lastMetricTime = System.currentTimeMillis()
        frameCount = 0L
        droppedFrames = 0L
        Live2DLogger.Renderer.i("렌더러 준비 완료", "isReady=true")
        
        if (wasReady && savedModelPath != null && savedModelName != null) {
            Live2DLogger.Model.d("Surface 재생성", "모델 복원: $savedModelName")
            loadModelInternal(savedModelPath!!, savedModelName!!)
        }
        else if (pendingModelPath != null && pendingModelName != null) {
            Live2DLogger.Model.d("대기 중인 모델 로드 시작", "path=$pendingModelPath, name=$pendingModelName")
            loadModelInternal(pendingModelPath!!, pendingModelName!!)
            pendingModelPath = null
            pendingModelName = null
        }
        
        checkGLError("onSurfaceCreated")
    }
    
    override fun onSurfaceChanged(gl: GL10?, width: Int, height: Int) {
        Live2DLogger.Renderer.i("Surface 크기 변경", "${width}x${height}")
        
        surfaceWidth = width
        surfaceHeight = height
        
        GLES20.glViewport(0, 0, width, height)
        
        val ratio = width.toFloat() / height.toFloat()
        Matrix.orthoM(projectionMatrix, 0, -ratio, ratio, -1f, 1f, -1f, 1f)
        
        Matrix.setLookAtM(viewMatrix, 0,
            0f, 0f, 1f,  // eye
            0f, 0f, 0f,  // center
            0f, 1f, 0f)  // up
        
        Matrix.multiplyMM(mvpMatrix, 0, projectionMatrix, 0, viewMatrix, 0)
        
        initFBO(width, height)
    }
    
    override fun onDrawFrame(gl: GL10?) {
        if (!isReady || isPaused || isDisposed) return

        var nowNs = System.nanoTime()
        var elapsedNs = nowNs - lastFrameTimeNs

        if (enableFpsLimit && elapsedNs < frameTimeNs) {
            val waitNs = frameTimeNs - elapsedNs
            val waitMs = waitNs / 1_000_000L
            val extraNs = (waitNs % 1_000_000L).toInt()
            try {
                if (waitMs > 0L || extraNs > 0) {
                    Thread.sleep(waitMs, extraNs)
                }
            } catch (_: InterruptedException) {
                Thread.currentThread().interrupt()
            }
            nowNs = System.nanoTime()
            elapsedNs = nowNs - lastFrameTimeNs
        }
        lastFrameTimeNs = nowNs
        val currentTime = System.currentTimeMillis()
        
        frameCount++
        if (currentTime - lastMetricTime >= 5000L) {
            measuredFps = frameCount * 1000f / (currentTime - lastMetricTime).coerceAtLeast(1L)
            if (measuredFps < targetFps * 0.7f && currentTime >= lowFpsWarnCooldownUntilMs) {
                Live2DLogger.Renderer.w("FPS 저하 감지", "measured=%.1f, target=$targetFps, dropped=$droppedFrames".format(measuredFps))
                lowFpsWarnCooldownUntilMs = currentTime + 30_000L
            }
            frameCount = 0L
            droppedFrames = 0L
            lastMetricTime = currentTime
        }

        val deltaTime = ((elapsedNs.coerceIn(4_000_000L, 100_000_000L)).toFloat() / 1_000_000_000f)
        processPendingParameterUpdates(deltaTime * 1000f)
        
        GLES20.glClearColor(0f, 0f, 0f, 0f)
        GLES20.glEnable(GLES20.GL_BLEND)
        GLES20.glBlendFunc(GLES20.GL_SRC_ALPHA, GLES20.GL_ONE_MINUS_SRC_ALPHA)
        GLES20.glDisable(GLES20.GL_DEPTH_TEST)
        
        GLES20.glClear(GLES20.GL_COLOR_BUFFER_BIT)
        
        // ============================================
        // ============================================
        
        System.arraycopy(mvpMatrix, 0, editedMvpMatrix, 0, 16)
        
        val hasEditTransform = characterOffsetPixelX != 0f || characterOffsetPixelY != 0f ||
                characterRotationDeg != 0 || relativeCharacterScale != 1.0f
        
        if (hasEditTransform && surfaceHeight > 0) {
            val pixelToGL = 2.0f / surfaceHeight
            val glOffsetX = characterOffsetPixelX * pixelToGL
            val glOffsetY = -characterOffsetPixelY * pixelToGL
            
            Matrix.translateM(editedMvpMatrix, 0, glOffsetX, glOffsetY, 0f)
            if (characterRotationDeg != 0) {
                Matrix.rotateM(editedMvpMatrix, 0, characterRotationDeg.toFloat(), 0f, 0f, 1f)
            }
            if (relativeCharacterScale != 1.0f) {
                Matrix.scaleM(editedMvpMatrix, 0, relativeCharacterScale, relativeCharacterScale, 1f)
            }
        }
        
        cubismModel?.let { model ->
            if (model.isReady()) {
                if (isLookAtActive && lookAtEnabled) {
                    model.setLookAtTarget(lookAtX, lookAtY)
                } else {
                    model.clearLookAtTarget()
                }
                
                val usingSdk = model.isUsingSdk()
                val fboReady = fbo != 0 && alphaFixProgram != 0
                
                if (!fboPathLogged) {
                    fboPathLogged = true
                    Live2DLogger.Renderer.i("FBO Alpha Fix 진단",
                        "usingSdk=$usingSdk, fbo=$fbo, shader=$alphaFixProgram, " +
                        "fboSize=${fboWidth}x${fboHeight}, path=${if (usingSdk && fboReady) "FBO" else "DIRECT"}")
                }
                
                if (usingSdk && fboReady) {
                    GLES20.glBindFramebuffer(GLES20.GL_FRAMEBUFFER, fbo)
                    GLES20.glViewport(0, 0, fboWidth, fboHeight)
                    GLES20.glClearColor(0f, 0f, 0f, 0f)
                    GLES20.glClear(GLES20.GL_COLOR_BUFFER_BIT)
                    
                    GLES20.glEnable(GLES20.GL_BLEND)
                    GLES20.glBlendFunc(GLES20.GL_ONE, GLES20.GL_ONE_MINUS_SRC_ALPHA)
                    model.update(deltaTime)
                    model.draw(editedMvpMatrix)
                    
                    GLES20.glBindFramebuffer(GLES20.GL_FRAMEBUFFER, 0)
                    GLES20.glViewport(0, 0, surfaceWidth, surfaceHeight)
                    drawFBOWithAlphaFix()
                    return
                }
                
                GLES20.glEnable(GLES20.GL_BLEND)
                GLES20.glBlendFunc(GLES20.GL_ONE, GLES20.GL_ONE_MINUS_SRC_ALPHA)
                model.update(deltaTime)
                model.draw(editedMvpMatrix)
                
                if (model.isUsingSdk()) {
                    GLES20.glEnable(GLES20.GL_BLEND)
                    GLES20.glBlendFunc(GLES20.GL_SRC_ALPHA, GLES20.GL_ONE_MINUS_SRC_ALPHA)
                    return
                }
            }
        }
        
        cubismModel?.let { model ->
            val texturePath = model.getFirstTexturePath()
            if (texturePath != null && textureRenderer?.hasLoadedTexture() == true) {
                textureRenderer?.render(
                    editedMvpMatrix,
                    model.getX(),
                    model.getY(),
                    model.getScale(),
                    model.getRotation(),
                    model.getOpacity()
                )
                return
            }
        }
        
        currentModel?.let { model ->
            if (isLookAtActive && lookAtEnabled) {
                model.lookAt(lookAtX, lookAtY)
            }
            model.update(deltaTime)
            
            val texturePath = model.getFirstTexturePath()
            if (texturePath != null && textureRenderer?.hasLoadedTexture() == true) {
                textureRenderer?.render(
                    editedMvpMatrix,
                    model.getX(),
                    model.getY(),
                    model.getScale(),
                    model.getRotation(),
                    model.getOpacity()
                )
            } else {
                renderModelPlaceholder(model)
            }
            return
        }
        
        renderNoModelPlaceholder()
    }
    
    /**
     */
    private fun renderModelPlaceholder(model: Live2DModel) {
        placeholderShader?.let { shader ->
            shader.use()
            shader.setMVPMatrix(mvpMatrix)
            shader.setModelTransform(
                model.getX(),
                model.getY(),
                model.getScale(),
                model.getRotation()
            )
            shader.setColor(0.3f, 0.5f, 0.9f, model.getOpacity() * 0.8f)
            shader.drawCircle(0f, 0f, 0.35f)
            
            shader.setColor(1f, 1f, 1f, model.getOpacity())
            shader.drawCircle(0f, 0f, 0.05f)
        }
    }
    
    /**
     */
    private fun renderNoModelPlaceholder() {
        placeholderShader?.let { shader ->
            shader.use()
            shader.setMVPMatrix(mvpMatrix)
            shader.setModelTransform(0f, 0f, 1f, 0f)
            shader.setColor(0.4f, 0.4f, 0.4f, 0.6f)
            shader.drawCircle(0f, 0f, 0.25f)
        }
    }
    
    /**
     */
    fun loadModel(modelPath: String, modelName: String): Boolean {
        if (!isReady) {
            pendingModelPath = modelPath
            pendingModelName = modelName
            Live2DLogger.Model.d("모델 로드 대기", "Surface 준비 안됨, name=$modelName")
            return true
        }
        
        return loadModelInternal(modelPath, modelName)
    }
    
    private fun loadModelInternal(modelPath: String, modelName: String): Boolean {
        try {
            Live2DLogger.Model.i("모델 로드 시작", "path=$modelPath, name=$modelName")
            
            // ============================================
            // ============================================
            
            cubismModel?.let {
                Live2DLogger.Model.d("기존 CubismModel 해제", it.modelName)
                it.release()
            }
            cubismModel = null
            
            currentModel?.let {
                Live2DLogger.Model.d("기존 Live2DModel 해제", it.modelName)
                it.dispose()
            }
            currentModel = null
            
            savedModelPath = modelPath
            savedModelName = modelName
            
            val newCubismModel = CubismModel(modelPath, modelName)
            if (newCubismModel.load()) {
                cubismModel = newCubismModel
                
                val texturePath = newCubismModel.getFirstTexturePath()
                if (texturePath != null) {
                    Live2DLogger.Model.d("텍스처 로드", texturePath)
                    textureRenderer?.loadTexture(texturePath)
                }
                
                val info = newCubismModel.getInfo()
                applyBehaviorSettingsToModel(newCubismModel)
                Live2DLogger.Model.i(
                    "CubismModel 로드 성공",
                    "name=$modelName, sdk=${info["sdkMode"]}, textures=${info["textureCount"]}"
                )
                
                if (newCubismModel.isUsingSdk()) {
                    Live2DLogger.Model.i("[Phase7-2] Live2D model rendered", 
                        "REAL SDK rendering active for $modelName")
                } else {
                    Live2DLogger.Model.w("[Phase7-2] Fallback rendering", 
                        "Texture preview mode for $modelName")
                }
                
                return true
            }
            
            Live2DLogger.Model.w("CubismModel 실패", "Live2DModel로 폴백")
            newCubismModel.release()
            
            val legacyModel = Live2DModel(modelPath, modelName)
            if (legacyModel.load()) {
                currentModel = legacyModel
                
                val texturePath = legacyModel.getFirstTexturePath()
                if (texturePath != null) {
                    textureRenderer?.loadTexture(texturePath)
                }
                
                val info = legacyModel.getDetailedInfo()
                Live2DLogger.Model.i(
                    "Live2DModel 로드 성공 (폴백)",
                    "name=$modelName, textures=${info["textureCount"]}"
                )
                return true
            }
            
            Live2DLogger.Model.e("모델 로드 실패", "name=$modelName, path=$modelPath")
            return false
            
        } catch (e: Exception) {
            Live2DLogger.Model.e("모델 로드 예외", "name=$modelName", e)
            return false
        }
    }
    
    /**
     */
    fun playMotion(motionName: String, loop: Boolean): Boolean {
        cubismModel?.let { model ->
            val parts = motionName.split(":")
            val group = parts[0]
            val index = parts.getOrNull(1)?.toIntOrNull() ?: 0
            val priority = if (loop) CubismModel.PRIORITY_IDLE else CubismModel.PRIORITY_NORMAL
            return model.playMotion(group, index, priority)
        }
        return currentModel?.playMotion(motionName, loop) ?: false
    }
    
    /**
     */
    fun setExpression(expressionName: String): Boolean {
        cubismModel?.let { return it.setExpression(expressionName) }
        return currentModel?.setExpression(expressionName) ?: false
    }
    
    /**
     */
    fun setModelScale(scale: Float) {
        cubismModel?.setScale(scale)
        currentModel?.setScale(scale)
    }

    /**
     */
    fun setModelOpacity(opacity: Float) {
        cubismModel?.setOpacity(opacity)
        currentModel?.setOpacity(opacity)
    }
    
    /**
     */
    fun setCharacterOpacity(opacity: Float) {
        characterOpacity = opacity.coerceIn(0f, 1f)
        cubismModel?.setOpacity(opacity)
        currentModel?.setOpacity(opacity)
    }    
    /**
     */
    fun setRelativeScale(scale: Float) {
        relativeCharacterScale = scale.coerceIn(0.1f, 3.0f)
    }
    
    /**
     */
    fun setCharacterOffset(xPixel: Float, yPixel: Float) {
        characterOffsetPixelX = xPixel
        characterOffsetPixelY = yPixel
    }
    
    /**
     */
    fun setCharacterRotation(degrees: Int) {
        characterRotationDeg = degrees % 360
    }    
    /**
     */
    fun setModelPosition(x: Float, y: Float) {
        cubismModel?.setPosition(x, y)
        currentModel?.setPosition(x, y)
    }
    
    /**
     */
    fun setBackgroundColor(r: Float, g: Float, b: Float, a: Float) {
        bgRed = r
        bgGreen = g
        bgBlue = b
        bgAlpha = a
        
        if (isReady) {
            GLES20.glClearColor(bgRed, bgGreen, bgBlue, bgAlpha)
        }
    }
    
    /**
     */
    fun onTouch(x: Float, y: Float) {
        if (!lookAtEnabled) {
            return
        }
        lookAtX = x
        lookAtY = y
        isLookAtActive = true
    }
    
    /**
     */
    fun onTouchEnd() {
        isLookAtActive = false
        lookAtX = 0f
        lookAtY = 0f
    }
    
    /**
     */
    fun setTargetFps(fps: Int) {
        targetFps = fps.coerceIn(15, 60)
        frameTimeNs = 1_000_000_000L / targetFps
        Live2DLogger.Renderer.d("FPS 설정", "$targetFps fps")
    }
    
    /**
     */
    fun setLowPowerMode(enabled: Boolean) {
        lowPowerMode = enabled
        targetFps = if (enabled) LOW_POWER_FPS else DEFAULT_FPS
        frameTimeNs = 1_000_000_000L / targetFps
        Live2DLogger.Renderer.d("저전력 모드", if (enabled) "활성화 (${LOW_POWER_FPS}fps)" else "비활성화 (${DEFAULT_FPS}fps)")
    }

    /**
     */
    fun setParameterValue(paramId: String, value: Float, durationMs: Int) {
        Live2DLogger.Renderer.d("파라미터 설정", "$paramId = $value ($durationMs ms)")
        pendingParameterUpdates.removeAll { it.paramId == paramId }
        pendingParameterUpdates.add(
            ParameterUpdate(
                paramId = paramId,
                targetValue = value,
                durationMs = durationMs.coerceAtLeast(0)
            )
        )
    }

    fun setEyeBlinkEnabled(enabled: Boolean) {
        eyeBlinkEnabled = enabled
        cubismModel?.setEyeBlinkEnabled(enabled)
    }

    fun setEyeBlinkInterval(intervalSeconds: Float) {
        val clamped = intervalSeconds.coerceIn(0.5f, 12f)
        eyeBlinkIntervalSeconds = clamped
        cubismModel?.setEyeBlinkInterval(clamped)
    }

    fun setBreathingEnabled(enabled: Boolean) {
        breathingEnabled = enabled
        cubismModel?.setBreathingEnabled(enabled)
    }

    fun setBreathConfig(cycleSeconds: Float, weight: Float) {
        val clampedCycle = cycleSeconds.coerceIn(1f, 12f)
        val clampedWeight = weight.coerceIn(0f, 2f)
        breathCycleSeconds = clampedCycle
        breathWeight = clampedWeight
        cubismModel?.setBreathConfig(clampedCycle, clampedWeight)
    }

    fun setLookAtEnabled(enabled: Boolean) {
        lookAtEnabled = enabled
        cubismModel?.setLookAtEnabled(enabled)
        if (!enabled) {
            isLookAtActive = false
            lookAtX = 0f
            lookAtY = 0f
        }
    }

    fun setPhysicsEnabled(enabled: Boolean) {
        physicsEnabled = enabled
        cubismModel?.setPhysicsEnabled(enabled)
    }

    fun setPhysicsConfig(fps: Int, delayScale: Float, mobilityScale: Float) {
        physicsFps = fps.coerceIn(1, 120)
        physicsDelayScale = delayScale.coerceIn(0.1f, 3f)
        physicsMobilityScale = mobilityScale.coerceIn(0.1f, 3f)
        cubismModel?.setPhysicsConfig(physicsFps, physicsDelayScale, physicsMobilityScale)
    }

    private fun processPendingParameterUpdates(deltaMs: Float) {
        if (pendingParameterUpdates.isEmpty()) return
        val iterator = pendingParameterUpdates.iterator()
        while (iterator.hasNext()) {
            val update = iterator.next()
            if (update.durationMs <= 0) {
                Live2DNativeBridge.safeSetParameterValue(update.paramId, update.targetValue)
                iterator.remove()
                continue
            }

            if (update.startValue == null) {
                update.startValue = Live2DNativeBridge.safeGetParameterValue(update.paramId) ?: update.targetValue
            }

            update.elapsedMs += deltaMs
            val progress = (update.elapsedMs / update.durationMs.toFloat()).coerceIn(0f, 1f)
            val start = update.startValue ?: update.targetValue
            val currentValue = start + ((update.targetValue - start) * progress)
            Live2DNativeBridge.safeSetParameterValue(update.paramId, currentValue)

            if (progress >= 1f) {
                iterator.remove()
            }
        }
    }
    
    /**
     */
    fun getMeasuredFps(): Float = measuredFps
    
    /**
     */
    fun setFpsLimitEnabled(enabled: Boolean) {
        enableFpsLimit = enabled
    }
    
    /**
     */
    fun getModelInfo(): Map<String, Any>? {
        cubismModel?.let { return it.getInfo() }
        return currentModel?.getDetailedInfo()
    }
    
    /**
     */
    fun onPause() {
        isPaused = true
    }
    
    /**
     */
    fun onResume() {
        isPaused = false
        lastFrameTimeNs = System.nanoTime()
    }
    
    /**
     */
    fun beforeSurfaceDestroyed() {
        cubismModel?.let {
            savedModelPath = savedModelPath ?: it.getModelPath()
            savedModelName = it.modelName
        }
        currentModel?.let {
            savedModelPath = savedModelPath ?: it.modelPath
            savedModelName = it.modelName
        }
    }
    
    /**
     * 
     * Safe to call multiple times - double-dispose guard prevents issues
     */
    fun dispose() {
        if (isDisposed) {
            Live2DLogger.Renderer.d("이미 정리됨", "dispose() 재호출 무시")
            return
        }
        
        synchronized(this) {
            if (isDisposed) return  // Double-check under lock
            isDisposed = true
            
            disposeFBO()
            disposeAlphaFixShader()
            
            cubismModel?.release()
            cubismModel = null
            
            currentModel?.dispose()
            currentModel = null
            pendingParameterUpdates.clear()
            
            placeholderShader?.dispose()
            placeholderShader = null
            textureRenderer?.dispose()
            textureRenderer = null
            
            savedModelPath = null
            savedModelName = null
            isReady = false
        }
        
        Live2DLogger.Renderer.i("렌더러 정리됨", null)
    }
    
    // ============================================================================
    // ============================================================================
    
    /**
     *
     */
    private fun initFBO(width: Int, height: Int) {
        if (width <= 0 || height <= 0) return
        if (fboWidth == width && fboHeight == height && fbo != 0) return
        
        disposeFBO()
        
        val texIds = IntArray(1)
        GLES20.glGenTextures(1, texIds, 0)
        fboTexture = texIds[0]
        
        GLES20.glBindTexture(GLES20.GL_TEXTURE_2D, fboTexture)
        GLES20.glTexParameteri(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_MIN_FILTER, GLES20.GL_LINEAR)
        GLES20.glTexParameteri(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_MAG_FILTER, GLES20.GL_LINEAR)
        GLES20.glTexParameteri(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_WRAP_S, GLES20.GL_CLAMP_TO_EDGE)
        GLES20.glTexParameteri(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_WRAP_T, GLES20.GL_CLAMP_TO_EDGE)
        GLES20.glTexImage2D(
            GLES20.GL_TEXTURE_2D, 0, GLES20.GL_RGBA,
            width, height, 0,
            GLES20.GL_RGBA, GLES20.GL_UNSIGNED_BYTE, null
        )
        
        val fboIds = IntArray(1)
        GLES20.glGenFramebuffers(1, fboIds, 0)
        fbo = fboIds[0]
        
        GLES20.glBindFramebuffer(GLES20.GL_FRAMEBUFFER, fbo)
        GLES20.glFramebufferTexture2D(
            GLES20.GL_FRAMEBUFFER, GLES20.GL_COLOR_ATTACHMENT0,
            GLES20.GL_TEXTURE_2D, fboTexture, 0
        )
        
        val status = GLES20.glCheckFramebufferStatus(GLES20.GL_FRAMEBUFFER)
        if (status != GLES20.GL_FRAMEBUFFER_COMPLETE) {
            Live2DLogger.GL.e("FBO 생성 실패", "status=0x${Integer.toHexString(status)}")
            disposeFBO()
        } else {
            fboWidth = width
            fboHeight = height
            Live2DLogger.GL.d("FBO 생성 완료", "${width}x${height}")
        }
        
        GLES20.glBindFramebuffer(GLES20.GL_FRAMEBUFFER, 0)
        GLES20.glBindTexture(GLES20.GL_TEXTURE_2D, 0)
    }
    
    /**
     */
    private fun disposeFBO() {
        if (fbo != 0) {
            GLES20.glDeleteFramebuffers(1, intArrayOf(fbo), 0)
            fbo = 0
        }
        if (fboTexture != 0) {
            GLES20.glDeleteTextures(1, intArrayOf(fboTexture), 0)
            fboTexture = 0
        }
        fboWidth = 0
        fboHeight = 0
    }
    
    /**
     */
    private fun initAlphaFixShader() {
        val vertShader = compileShader(GLES20.GL_VERTEX_SHADER, ALPHA_FIX_VERTEX_SHADER)
        if (vertShader == 0) return
        
        val fragShader = compileShader(GLES20.GL_FRAGMENT_SHADER, ALPHA_FIX_FRAGMENT_SHADER)
        if (fragShader == 0) {
            GLES20.glDeleteShader(vertShader)
            return
        }
        
        alphaFixProgram = GLES20.glCreateProgram()
        GLES20.glAttachShader(alphaFixProgram, vertShader)
        GLES20.glAttachShader(alphaFixProgram, fragShader)
        GLES20.glLinkProgram(alphaFixProgram)
        
        val linkStatus = IntArray(1)
        GLES20.glGetProgramiv(alphaFixProgram, GLES20.GL_LINK_STATUS, linkStatus, 0)
        if (linkStatus[0] == 0) {
            val log = GLES20.glGetProgramInfoLog(alphaFixProgram)
            Live2DLogger.GL.e("Alpha Fix 프로그램 링크 실패", log)
            GLES20.glDeleteProgram(alphaFixProgram)
            alphaFixProgram = 0
        }
        
        GLES20.glDeleteShader(vertShader)
        GLES20.glDeleteShader(fragShader)
        
        val quadData = floatArrayOf(
            -1f, -1f,  0f, 0f,
             1f, -1f,  1f, 0f,
            -1f,  1f,  0f, 1f,
             1f,  1f,  1f, 1f
        )
        alphaFixQuadBuffer = ByteBuffer.allocateDirect(quadData.size * 4)
            .order(ByteOrder.nativeOrder())
            .asFloatBuffer()
            .apply { put(quadData); position(0) }
    }
    
    /**
     */
    private fun disposeAlphaFixShader() {
        if (alphaFixProgram != 0) {
            GLES20.glDeleteProgram(alphaFixProgram)
            alphaFixProgram = 0
        }
        alphaFixQuadBuffer = null
    }
    
    /**
     *
     */
    private fun drawFBOWithAlphaFix() {
        val quadBuf = alphaFixQuadBuffer ?: return
        
        GLES20.glDisable(GLES20.GL_BLEND)
        
        GLES20.glUseProgram(alphaFixProgram)
        
        GLES20.glActiveTexture(GLES20.GL_TEXTURE0)
        GLES20.glBindTexture(GLES20.GL_TEXTURE_2D, fboTexture)
        GLES20.glUniform1i(
            GLES20.glGetUniformLocation(alphaFixProgram, "uTexture"), 0
        )
        
        GLES20.glUniform1f(
            GLES20.glGetUniformLocation(alphaFixProgram, "uCharacterOpacity"),
            characterOpacity
        )
        
        val posLoc = GLES20.glGetAttribLocation(alphaFixProgram, "aPosition")
        val texLoc = GLES20.glGetAttribLocation(alphaFixProgram, "aTexCoord")
        
        quadBuf.position(0)
        GLES20.glEnableVertexAttribArray(posLoc)
        GLES20.glVertexAttribPointer(posLoc, 2, GLES20.GL_FLOAT, false, 16, quadBuf)
        
        quadBuf.position(2)
        GLES20.glEnableVertexAttribArray(texLoc)
        GLES20.glVertexAttribPointer(texLoc, 2, GLES20.GL_FLOAT, false, 16, quadBuf)
        
        GLES20.glDrawArrays(GLES20.GL_TRIANGLE_STRIP, 0, 4)
        
        GLES20.glDisableVertexAttribArray(posLoc)
        GLES20.glDisableVertexAttribArray(texLoc)
        
        GLES20.glEnable(GLES20.GL_BLEND)
        GLES20.glBlendFunc(GLES20.GL_SRC_ALPHA, GLES20.GL_ONE_MINUS_SRC_ALPHA)
        GLES20.glBindTexture(GLES20.GL_TEXTURE_2D, 0)
    }
    
    /**
     */
    private fun compileShader(type: Int, source: String): Int {
        val shader = GLES20.glCreateShader(type)
        GLES20.glShaderSource(shader, source)
        GLES20.glCompileShader(shader)
        
        val compiled = IntArray(1)
        GLES20.glGetShaderiv(shader, GLES20.GL_COMPILE_STATUS, compiled, 0)
        if (compiled[0] == 0) {
            val log = GLES20.glGetShaderInfoLog(shader)
            Live2DLogger.GL.e("셰이더 컴파일 실패", log)
            GLES20.glDeleteShader(shader)
            return 0
        }
        return shader
    }
    
    /**
     */
    private fun checkGLError(operation: String) {
        var error: Int
        while (GLES20.glGetError().also { error = it } != GLES20.GL_NO_ERROR) {
            Live2DLogger.GL.e("GL Error", "$operation: $error")
        }
    }

    private fun applyBehaviorSettingsToModel(model: CubismModel) {
        model.setEyeBlinkEnabled(eyeBlinkEnabled)
        model.setEyeBlinkInterval(eyeBlinkIntervalSeconds)
        model.setBreathingEnabled(breathingEnabled)
        model.setBreathConfig(breathCycleSeconds, breathWeight)
        model.setLookAtEnabled(lookAtEnabled)
        model.setPhysicsEnabled(physicsEnabled)
        model.setPhysicsConfig(physicsFps, physicsDelayScale, physicsMobilityScale)
    }
}

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
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.nio.FloatBuffer
import javax.microedition.khronos.egl.EGLConfig
import javax.microedition.khronos.opengles.GL10

/**
 * Live2D OpenGL Renderer
 * 
 * OpenGL ES 2.0을 사용한 Live2D 모델 렌더러
 * 
 * Phase 7: CubismModel 통합
 * - SDK 사용 가능 시: CubismModel로 실제 Live2D 렌더링
 * - SDK 미설치 시: 기존 TextureModelRenderer로 폴백
 */
class Live2DGLRenderer(private val context: Context) : GLSurfaceView.Renderer {
    
    companion object {
        private const val TAG = "Live2DGLRenderer"
        private const val DEFAULT_FPS = 60
        private const val LOW_POWER_FPS = 30
        
        // ========== FBO Alpha Fix Shader ==========
        // WHY: Cubism SDK의 DrawModel()이 렌더링한 캐릭터의 프레임버퍼 알파가
        // 정확히 1.0이 아닐 수 있습니다. FBO에 렌더링 후 이 셰이더로
        // 캐릭터 영역의 알파를 1.0으로 강제하여 Android 컴포지터에서
        // 캐릭터가 완전 불투명하게 표시되도록 합니다.
        
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
                    // 투명 픽셀: 그대로 유지
                    gl_FragColor = vec4(0.0, 0.0, 0.0, 0.0);
                } else if (c.a >= 0.5) {
                    // 캐릭터 몸체: 완전 불투명
                    // Unpremultiply RGB후 alpha=1.0으로 출력
                    // uCharacterOpacity 적용 (premultiplied alpha 형식)
                    gl_FragColor = vec4(c.rgb / c.a * uCharacterOpacity, uCharacterOpacity);
                } else {
                    // 가장자리: 부드러운 전환 유지 + 약간 부스트
                    float newAlpha = min(c.a * 2.0, 1.0) * uCharacterOpacity;
                    gl_FragColor = vec4((c.rgb / c.a) * newAlpha, newAlpha);
                }
            }
        """
    }
    
    // OpenGL 변환 행렬
    private val projectionMatrix = FloatArray(16)
    private val viewMatrix = FloatArray(16)
    private val mvpMatrix = FloatArray(16)
    
    // 렌더링 상태
    private var surfaceWidth = 0
    private var surfaceHeight = 0
    private var isReady = false
    private var isPaused = false
    
    // WHY: Double-dispose 방지 플래그
    // dispose()가 여러 번 호출될 수 있는 경우 (예: 빠른 토글, 예외 복구)
    // 한 번만 실행되도록 보장합니다.
    @Volatile private var isDisposed = false
    
    // 배경색 (기본값: 투명)
    private var bgRed = 0f
    private var bgGreen = 0f
    private var bgBlue = 0f
    private var bgAlpha = 0f
    
    // ========== FBO Alpha Fix ==========
    // WHY: SDK 렌더링 결과의 알파 채널을 보정하기 위해
    // FBO에 먼저 렌더링한 후, 알파 보정 셰이더로 화면에 출력합니다.
    private var fbo = 0
    private var fboTexture = 0
    private var fboWidth = 0
    private var fboHeight = 0
    private var alphaFixProgram = 0
    private var alphaFixQuadBuffer: FloatBuffer? = null
    
    // ========== 캐릭터 투명도 (GL 레벨) ==========
    // 윈도우 알파(터치스루)와 독립적으로 캐릭터의 시각적 투명도를 제어
    @Volatile private var characterOpacity = 1.0f
    
    // ============================================
    // Live2D 모델 (Phase 7: 이중 모드 지원)
    // ============================================
    //
    // WHY dual model references 존재하는 이유:
    // - cubismModel: CubismModel 래퍼 - SDK가 있으면 LAppModel로 실제 Live2D 렌더링
    // - currentModel: Legacy Live2DModel - 이전 텍스처 기반 폴백 시스템과의 호환성
    // 
    // 이 이중 구조는 마이그레이션 과정에서 생겼습니다. SDK 설치 전에는 
    // TextureModelRenderer가 currentModel을 사용하고, SDK 설치 후에는
    // cubismModel이 실제 렌더링을 담당합니다.
    //
    // 향후 Phase 9에서 통합을 고려할 수 있지만, 현재는 폴백 경로가 
    // 안정적으로 작동하므로 이 구조를 유지합니다.
    // ============================================
    
    // Cubism SDK 모델 (실제 Live2D 렌더링)
    private var cubismModel: CubismModel? = null
    
    // 폴백 모델 (텍스처 프리뷰용)
    private var currentModel: Live2DModel? = null
    
    // 대기 중인 모델 정보
    private var pendingModelPath: String? = null
    private var pendingModelName: String? = null
    
    // Surface 재생성 시 복원용
    private var savedModelPath: String? = null
    private var savedModelName: String? = null
    
    // 프레임 타이밍
    private var lastFrameTime = 0L
    private var targetFps = DEFAULT_FPS
    private var frameTimeMs = 1000L / targetFps
    
    // 시선 추적 좌표
    private var lookAtX = 0f
    private var lookAtY = 0f
    private var isLookAtActive = false
    
    // 렌더러들
    private var placeholderShader: PlaceholderShader? = null
    private var textureRenderer: TextureModelRenderer? = null
    
    // FPS 제한 설정
    private var enableFpsLimit = true
    private var lowPowerMode = false
    
    // FBO 경로 진단 (한 번만 로깅)
    @Volatile private var fboPathLogged = false
    
    // ========== 최적화: 프레임 메트릭 ==========
    private var frameCount = 0L
    private var lastMetricTime = 0L
    private var droppedFrames = 0L
    private var measuredFps = 0f
    
    // 화면 가시성 기반 절전
    @Volatile private var isOverlayInvisible = false
    
    override fun onSurfaceCreated(gl: GL10?, config: EGLConfig?) {
        Live2DLogger.Renderer.i("Surface created", "OpenGL ES 2.0 초기화 시작")
        
        // Surface 재생성 여부 확인
        val wasReady = isReady
        
        // OpenGL 설정
        GLES20.glClearColor(bgRed, bgGreen, bgBlue, bgAlpha)
        GLES20.glEnable(GLES20.GL_BLEND)
        GLES20.glBlendFunc(GLES20.GL_SRC_ALPHA, GLES20.GL_ONE_MINUS_SRC_ALPHA)
        
        // WHY: 2D Live2D 렌더링에 depth test는 불필요하며,
        // 오히려 투명 배경 합성에 간섭할 수 있습니다.
        GLES20.glDisable(GLES20.GL_DEPTH_TEST)
        
        // OpenGL 버전 정보 로깅
        val glVersion = GLES20.glGetString(GLES20.GL_VERSION)
        val glVendor = GLES20.glGetString(GLES20.GL_VENDOR)
        val glRenderer = GLES20.glGetString(GLES20.GL_RENDERER)
        Live2DLogger.GL.i("OpenGL 정보", "Version: $glVersion, Vendor: $glVendor, Renderer: $glRenderer")
        
        // ============================================
        // Phase 7: Cubism Framework 초기화
        // ============================================
        val sdkResult = CubismFrameworkManager.initialize(context)
        val sdkStatus = CubismFrameworkManager.getStatusInfo()
        Live2DLogger.Renderer.i("Cubism Framework", 
            "초기화=${if (sdkResult) "성공" else "실패"}, " +
            "SDK=${sdkStatus["sdkLoaded"]}, mode=${sdkStatus["mode"]}")
        
        // Phase 7-2: SDK 렌더링 준비 상태 확인
        if (CubismFrameworkManager.isSdkRenderingReady()) {
            Live2DLogger.Renderer.i("[Phase7-2] SDK rendering READY", 
                "version=${CubismFrameworkManager.getVersionString()}")
        } else {
            Live2DLogger.Renderer.w("[Phase7-2] SDK rendering NOT ready", 
                "fallback mode active")
        }
        
        // 플레이스홀더 셰이더 초기화 (폴백용)
        placeholderShader = PlaceholderShader()
        val shaderResult = placeholderShader?.initialize() ?: false
        Live2DLogger.GL.d("플레이스홀더 셰이더", if (shaderResult) "초기화 성공" else "초기화 실패")
        
        // 텍스처 렌더러 초기화 (폴백용)
        textureRenderer = TextureModelRenderer()
        val textureResult = textureRenderer?.initialize() ?: false
        Live2DLogger.GL.d("텍스처 렌더러", if (textureResult) "초기화 성공" else "초기화 실패")
        
        // ========== FBO Alpha Fix 초기화 ==========
        initAlphaFixShader()
        Live2DLogger.GL.d("Alpha Fix 셰이더", if (alphaFixProgram != 0) "초기화 성공" else "초기화 실패")
        
        isReady = true
        lastFrameTime = System.currentTimeMillis()
        lastMetricTime = lastFrameTime
        frameCount = 0L
        droppedFrames = 0L
        Live2DLogger.Renderer.i("렌더러 준비 완료", "isReady=true")
        
        // Surface 재생성 시 모델 복원
        if (wasReady && savedModelPath != null && savedModelName != null) {
            Live2DLogger.Model.d("Surface 재생성", "모델 복원: $savedModelName")
            loadModelInternal(savedModelPath!!, savedModelName!!)
        }
        // 대기 중인 모델 로드 (최초 생성 시)
        else if (pendingModelPath != null && pendingModelName != null) {
            Live2DLogger.Model.d("대기 중인 모델 로드 시작", "path=$pendingModelPath, name=$pendingModelName")
            loadModelInternal(pendingModelPath!!, pendingModelName!!)
            pendingModelPath = null
            pendingModelName = null
        }
        
        // GL 에러 체크
        checkGLError("onSurfaceCreated")
    }
    
    override fun onSurfaceChanged(gl: GL10?, width: Int, height: Int) {
        Live2DLogger.Renderer.i("Surface 크기 변경", "${width}x${height}")
        
        surfaceWidth = width
        surfaceHeight = height
        
        GLES20.glViewport(0, 0, width, height)
        
        // 투영 행렬 설정 (정규화 좌표계 -1~1)
        val ratio = width.toFloat() / height.toFloat()
        Matrix.orthoM(projectionMatrix, 0, -ratio, ratio, -1f, 1f, -1f, 1f)
        
        // 뷰 행렬 설정 (카메라)
        Matrix.setLookAtM(viewMatrix, 0,
            0f, 0f, 1f,  // eye
            0f, 0f, 0f,  // center
            0f, 1f, 0f)  // up
        
        // MVP 행렬 계산
        Matrix.multiplyMM(mvpMatrix, 0, projectionMatrix, 0, viewMatrix, 0)
        
        // FBO 크기 재생성
        initFBO(width, height)
    }
    
    override fun onDrawFrame(gl: GL10?) {
        if (!isReady || isPaused || isDisposed) return
        
        // FPS 제한 (프레임 스킵 방식)
        val currentTime = System.currentTimeMillis()
        val elapsed = currentTime - lastFrameTime
        
        // 목표 프레임 시간보다 빠르면 이전 프레임 유지
        if (enableFpsLimit && elapsed < frameTimeMs) {
            droppedFrames++
            return
        }
        lastFrameTime = currentTime
        
        // ========== 프레임 메트릭 수집 (5초 간격) ==========
        frameCount++
        if (currentTime - lastMetricTime >= 5000L) {
            measuredFps = frameCount * 1000f / (currentTime - lastMetricTime).coerceAtLeast(1L)
            if (measuredFps < targetFps * 0.7f) {
                Live2DLogger.Renderer.w("FPS 저하 감지", "measured=%.1f, target=$targetFps, dropped=$droppedFrames".format(measuredFps))
            }
            frameCount = 0L
            droppedFrames = 0L
            lastMetricTime = currentTime
        }
        
        // 델타 타임 계산 (초 단위, 안전 범위 제한)
        val deltaTime = (elapsed.coerceIn(1L, 100L) / 1000f)
        
        // ========== 매 프레임 투명 배경 강제 적용 ==========
        GLES20.glClearColor(0f, 0f, 0f, 0f)
        GLES20.glEnable(GLES20.GL_BLEND)
        GLES20.glBlendFunc(GLES20.GL_SRC_ALPHA, GLES20.GL_ONE_MINUS_SRC_ALPHA)
        GLES20.glDisable(GLES20.GL_DEPTH_TEST)
        
        // 화면 클리어
        GLES20.glClear(GLES20.GL_COLOR_BUFFER_BIT)
        
        // ============================================
        // Phase 7: 이중 모드 렌더링
        // ============================================
        
        // 1. CubismModel 시도 (SDK 모드)
        cubismModel?.let { model ->
            if (model.isReady()) {
                // 시선 추적 적용
                if (isLookAtActive) {
                    // TODO: SDK 설치 후 시선 추적 구현
                }
                
                // SDK 렌더링 시 FBO를 통한 알파 보정 적용
                val usingSdk = model.isUsingSdk()
                val fboReady = fbo != 0 && alphaFixProgram != 0
                
                // 한 번만 FBO 경로 진단 로깅
                if (!fboPathLogged) {
                    fboPathLogged = true
                    Live2DLogger.Renderer.i("FBO Alpha Fix 진단",
                        "usingSdk=$usingSdk, fbo=$fbo, shader=$alphaFixProgram, " +
                        "fboSize=${fboWidth}x${fboHeight}, path=${if (usingSdk && fboReady) "FBO" else "DIRECT"}")
                }
                
                if (usingSdk && fboReady) {
                    // ======== FBO에 렌더링 ========
                    GLES20.glBindFramebuffer(GLES20.GL_FRAMEBUFFER, fbo)
                    GLES20.glViewport(0, 0, fboWidth, fboHeight)
                    GLES20.glClearColor(0f, 0f, 0f, 0f)
                    GLES20.glClear(GLES20.GL_COLOR_BUFFER_BIT)
                    
                    GLES20.glEnable(GLES20.GL_BLEND)
                    GLES20.glBlendFunc(GLES20.GL_ONE, GLES20.GL_ONE_MINUS_SRC_ALPHA)
                    model.update(deltaTime)
                    model.draw(mvpMatrix)
                    
                    // ======== FBO 텍스처를 화면에 알파 보정하여 출력 ========
                    GLES20.glBindFramebuffer(GLES20.GL_FRAMEBUFFER, 0)
                    GLES20.glViewport(0, 0, surfaceWidth, surfaceHeight)
                    drawFBOWithAlphaFix()
                    return
                }
                
                // FBO 없을 때 폴백 (직접 렌더링)
                GLES20.glEnable(GLES20.GL_BLEND)
                GLES20.glBlendFunc(GLES20.GL_ONE, GLES20.GL_ONE_MINUS_SRC_ALPHA)
                model.update(deltaTime)
                model.draw(mvpMatrix)
                
                if (model.isUsingSdk()) {
                    GLES20.glEnable(GLES20.GL_BLEND)
                    GLES20.glBlendFunc(GLES20.GL_SRC_ALPHA, GLES20.GL_ONE_MINUS_SRC_ALPHA)
                    return
                }
            }
        }
        
        // 2. 폴백: 텍스처 기반 렌더링
        cubismModel?.let { model ->
            val texturePath = model.getFirstTexturePath()
            if (texturePath != null && textureRenderer?.hasLoadedTexture() == true) {
                textureRenderer?.render(
                    mvpMatrix,
                    model.getX(),
                    model.getY(),
                    model.getScale(),
                    model.getRotation(),
                    model.getOpacity()
                )
                return
            }
        }
        
        // 3. 레거시 Live2DModel 폴백
        currentModel?.let { model ->
            if (isLookAtActive) {
                model.lookAt(lookAtX, lookAtY)
            }
            model.update(deltaTime)
            
            val texturePath = model.getFirstTexturePath()
            if (texturePath != null && textureRenderer?.hasLoadedTexture() == true) {
                textureRenderer?.render(
                    mvpMatrix,
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
        
        // 4. 모델 없음: 대기 상태 플레이스홀더
        renderNoModelPlaceholder()
    }
    
    /**
     * 모델 플레이스홀더 렌더링 (텍스처 로드 실패 시)
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
            // 파란색 원 (모델 정보는 있지만 텍스처 없음)
            shader.setColor(0.3f, 0.5f, 0.9f, model.getOpacity() * 0.8f)
            shader.drawCircle(0f, 0f, 0.35f)
            
            // 중앙에 작은 점 (로드 상태 표시)
            shader.setColor(1f, 1f, 1f, model.getOpacity())
            shader.drawCircle(0f, 0f, 0.05f)
        }
    }
    
    /**
     * 대기 상태 플레이스홀더 렌더링
     */
    private fun renderNoModelPlaceholder() {
        placeholderShader?.let { shader ->
            shader.use()
            shader.setMVPMatrix(mvpMatrix)
            shader.setModelTransform(0f, 0f, 1f, 0f)
            // 회색 원 (대기 중)
            shader.setColor(0.4f, 0.4f, 0.4f, 0.6f)
            shader.drawCircle(0f, 0f, 0.25f)
        }
    }
    
    /**
     * 모델 로드
     */
    fun loadModel(modelPath: String, modelName: String): Boolean {
        if (!isReady) {
            // Surface가 준비되지 않았으면 대기
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
            // Phase 7: CubismModel 우선 시도
            // ============================================
            
            // 기존 모델들 해제
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
            
            // 모델 정보 저장 (Surface 재생성 시 복원용)
            savedModelPath = modelPath
            savedModelName = modelName
            
            // CubismModel로 로드 시도
            val newCubismModel = CubismModel(modelPath, modelName)
            if (newCubismModel.load()) {
                cubismModel = newCubismModel
                
                // 텍스처 로드 (폴백 렌더링용)
                val texturePath = newCubismModel.getFirstTexturePath()
                if (texturePath != null) {
                    Live2DLogger.Model.d("텍스처 로드", texturePath)
                    textureRenderer?.loadTexture(texturePath)
                }
                
                val info = newCubismModel.getInfo()
                Live2DLogger.Model.i(
                    "CubismModel 로드 성공",
                    "name=$modelName, sdk=${info["sdkMode"]}, textures=${info["textureCount"]}"
                )
                
                // Phase 7-2: SDK 렌더링 상태 확인
                if (newCubismModel.isUsingSdk()) {
                    Live2DLogger.Model.i("[Phase7-2] Live2D model rendered", 
                        "REAL SDK rendering active for $modelName")
                } else {
                    Live2DLogger.Model.w("[Phase7-2] Fallback rendering", 
                        "Texture preview mode for $modelName")
                }
                
                return true
            }
            
            // CubismModel 실패 시 레거시 Live2DModel 폴백
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
     * 모션 재생
     */
    fun playMotion(motionName: String, loop: Boolean): Boolean {
        // CubismModel 우선
        cubismModel?.let { model ->
            // 모션 그룹과 인덱스 파싱 (예: "Idle:0" 또는 "Idle")
            val parts = motionName.split(":")
            val group = parts[0]
            val index = parts.getOrNull(1)?.toIntOrNull() ?: 0
            val priority = if (loop) CubismModel.PRIORITY_IDLE else CubismModel.PRIORITY_NORMAL
            return model.playMotion(group, index, priority)
        }
        // 폴백
        return currentModel?.playMotion(motionName, loop) ?: false
    }
    
    /**
     * 표정 설정
     */
    fun setExpression(expressionName: String): Boolean {
        cubismModel?.let { return it.setExpression(expressionName) }
        return currentModel?.setExpression(expressionName) ?: false
    }
    
    /**
     * 스케일 설정
     */
    fun setModelScale(scale: Float) {
        cubismModel?.setScale(scale)
        currentModel?.setScale(scale)
    }

    /**
     * 모델 투명도 설정 (레거시, 폴백 렌더러용)
     */
    fun setModelOpacity(opacity: Float) {
        cubismModel?.setOpacity(opacity)
        currentModel?.setOpacity(opacity)
    }
    
    /**
     * 캐릭터 시각적 투명도 설정 (GL 레벨)
     * FBO 알파 보정 셰이더의 uCharacterOpacity uniform으로 적용
     * 윈도우 알파(터치스루)와 독립적으로 동작
     */
    fun setCharacterOpacity(opacity: Float) {
        characterOpacity = opacity.coerceIn(0f, 1f)
        // 폴백 렌더러에도 적용
        cubismModel?.setOpacity(opacity)
        currentModel?.setOpacity(opacity)
    }
    
    /**
     * 위치 설정
     */
    fun setModelPosition(x: Float, y: Float) {
        cubismModel?.setPosition(x, y)
        currentModel?.setPosition(x, y)
    }
    
    /**
     * 배경색 설정
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
     * 터치 이벤트 (시선 추적용)
     */
    fun onTouch(x: Float, y: Float) {
        lookAtX = x
        lookAtY = y
        isLookAtActive = true
    }
    
    /**
     * 터치 종료
     */
    fun onTouchEnd() {
        isLookAtActive = false
        lookAtX = 0f
        lookAtY = 0f
    }
    
    /**
     * FPS 설정
     */
    fun setTargetFps(fps: Int) {
        targetFps = fps.coerceIn(15, 60)
        frameTimeMs = 1000L / targetFps
        Live2DLogger.Renderer.d("FPS 설정", "$targetFps fps")
    }
    
    /**
     * 저전력 모드 설정
     */
    fun setLowPowerMode(enabled: Boolean) {
        lowPowerMode = enabled
        targetFps = if (enabled) LOW_POWER_FPS else DEFAULT_FPS
        frameTimeMs = 1000L / targetFps
        Live2DLogger.Renderer.d("저전력 모드", if (enabled) "활성화 (${LOW_POWER_FPS}fps)" else "비활성화 (${DEFAULT_FPS}fps)")
    }
    
    /**
     * 현재 측정 FPS 반환 (디버깅/모니터링용)
     */
    fun getMeasuredFps(): Float = measuredFps
    
    /**
     * FPS 제한 설정
     */
    fun setFpsLimitEnabled(enabled: Boolean) {
        enableFpsLimit = enabled
    }
    
    /**
     * 모델 정보 반환
     */
    fun getModelInfo(): Map<String, Any>? {
        cubismModel?.let { return it.getInfo() }
        return currentModel?.getDetailedInfo()
    }
    
    /**
     * 일시정지
     */
    fun onPause() {
        isPaused = true
    }
    
    /**
     * 재개
     */
    fun onResume() {
        isPaused = false
        lastFrameTime = System.currentTimeMillis()
    }
    
    /**
     * Surface 파괴 전 호출 (상태 저장)
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
     * 리소스 해제
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
            
            // FBO 해제
            disposeFBO()
            disposeAlphaFixShader()
            
            // CubismModel 해제
            cubismModel?.release()
            cubismModel = null
            
            // 레거시 모델 해제
            currentModel?.dispose()
            currentModel = null
            
            // 렌더러 해제
            placeholderShader?.dispose()
            placeholderShader = null
            textureRenderer?.dispose()
            textureRenderer = null
            
            // 상태 초기화
            savedModelPath = null
            savedModelName = null
            isReady = false
        }
        
        Live2DLogger.Renderer.i("렌더러 정리됨", null)
    }
    
    // ============================================================================
    // FBO Alpha Fix — 캐릭터 알파 채널 보정
    // ============================================================================
    
    /**
     * FBO 생성/재생성
     *
     * WHY: SDK 렌더링 결과를 FBO에 먼저 그린 후, 알파 보정 셰이더로
     * 화면에 출력합니다. 이를 통해 캐릭터 영역은 완전 불투명(alpha=1.0),
     * 배경은 완전 투명(alpha=0.0)으로 보장합니다.
     */
    private fun initFBO(width: Int, height: Int) {
        if (width <= 0 || height <= 0) return
        if (fboWidth == width && fboHeight == height && fbo != 0) return  // 크기 동일하면 재사용
        
        disposeFBO()
        
        // FBO 텍스처 생성
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
        
        // FBO 생성
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
        
        // 기본 프레임버퍼 복원
        GLES20.glBindFramebuffer(GLES20.GL_FRAMEBUFFER, 0)
        GLES20.glBindTexture(GLES20.GL_TEXTURE_2D, 0)
    }
    
    /**
     * FBO 해제
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
     * Alpha Fix 셰이더 및 풀스크린 쿼드 초기화
     */
    private fun initAlphaFixShader() {
        // 셰이더 컴파일
        val vertShader = compileShader(GLES20.GL_VERTEX_SHADER, ALPHA_FIX_VERTEX_SHADER)
        if (vertShader == 0) return
        
        val fragShader = compileShader(GLES20.GL_FRAGMENT_SHADER, ALPHA_FIX_FRAGMENT_SHADER)
        if (fragShader == 0) {
            GLES20.glDeleteShader(vertShader)
            return
        }
        
        // 프로그램 링크
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
        
        // 풀스크린 쿼드 버텍스 (position xy + texcoord uv)
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
     * Alpha Fix 셰이더 해제
     */
    private fun disposeAlphaFixShader() {
        if (alphaFixProgram != 0) {
            GLES20.glDeleteProgram(alphaFixProgram)
            alphaFixProgram = 0
        }
        alphaFixQuadBuffer = null
    }
    
    /**
     * FBO 텍스처를 알파 보정하여 화면에 출력
     *
     * WHY: SDK가 FBO에 렌더링한 결과의 알파 채널이 정확히 1.0이 아닐 수 있습니다.
     * 이 메서드는 알파 보정 셰이더를 사용하여:
     * - 캐릭터 몸체(alpha >= 0.5): 완전 불투명(alpha=1.0)으로 강제
     * - 가장자리(0.004 < alpha < 0.5): 부드러운 전환 유지 + 부스트
     * - 투명(alpha < 0.004): 그대로 투명 유지
     */
    private fun drawFBOWithAlphaFix() {
        val quadBuf = alphaFixQuadBuffer ?: return
        
        // 블렌딩 비활성화 — FBO 텍스처를 직접 출력 (이미 알파 보정 완료)
        GLES20.glDisable(GLES20.GL_BLEND)
        
        GLES20.glUseProgram(alphaFixProgram)
        
        // FBO 텍스처 바인딩
        GLES20.glActiveTexture(GLES20.GL_TEXTURE0)
        GLES20.glBindTexture(GLES20.GL_TEXTURE_2D, fboTexture)
        GLES20.glUniform1i(
            GLES20.glGetUniformLocation(alphaFixProgram, "uTexture"), 0
        )
        
        // 캐릭터 투명도 uniform 설정 (윈도우 알파와 독립)
        GLES20.glUniform1f(
            GLES20.glGetUniformLocation(alphaFixProgram, "uCharacterOpacity"),
            characterOpacity
        )
        
        // 풀스크린 쿼드 렌더링
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
        
        // GL 상태 복원
        GLES20.glEnable(GLES20.GL_BLEND)
        GLES20.glBlendFunc(GLES20.GL_SRC_ALPHA, GLES20.GL_ONE_MINUS_SRC_ALPHA)
        GLES20.glBindTexture(GLES20.GL_TEXTURE_2D, 0)
    }
    
    /**
     * 셰이더 컴파일 헬퍼
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
     * GL 에러 체크
     */
    private fun checkGLError(operation: String) {
        var error: Int
        while (GLES20.glGetError().also { error = it } != GLES20.GL_NO_ERROR) {
            Live2DLogger.GL.e("GL Error", "$operation: $error")
        }
    }
}

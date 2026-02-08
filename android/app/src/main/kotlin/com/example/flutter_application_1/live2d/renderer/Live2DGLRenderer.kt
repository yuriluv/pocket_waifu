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
        
        // 화면 클리어
        GLES20.glClear(GLES20.GL_COLOR_BUFFER_BIT or GLES20.GL_DEPTH_BUFFER_BIT)
        
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
                
                // 모델 업데이트 및 렌더링
                model.update(deltaTime)
                model.draw(mvpMatrix)
                
                // SDK가 실제로 렌더링하면 여기서 반환
                if (model.isUsingSdk()) {
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

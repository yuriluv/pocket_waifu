package com.example.flutter_application_1.live2d.renderer

import android.content.Context
import android.opengl.GLES20
import android.opengl.GLSurfaceView
import android.opengl.Matrix
import com.example.flutter_application_1.live2d.core.Live2DLogger
import com.example.flutter_application_1.live2d.core.Live2DManager
import com.example.flutter_application_1.live2d.core.Live2DModel
import javax.microedition.khronos.egl.EGLConfig
import javax.microedition.khronos.opengles.GL10

/**
 * Live2D OpenGL Renderer
 * 
 * OpenGL ES 2.0을 사용한 Live2D 모델 렌더러
 * 텍스처 기반 렌더링을 지원합니다.
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
    
    // 배경색 (기본값: 투명)
    private var bgRed = 0f
    private var bgGreen = 0f
    private var bgBlue = 0f
    private var bgAlpha = 0f
    
    // Live2D 모델
    private var currentModel: Live2DModel? = null
    private var pendingModelPath: String? = null
    private var pendingModelName: String? = null
    
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
    
    override fun onSurfaceCreated(gl: GL10?, config: EGLConfig?) {
        Live2DLogger.Renderer.i("Surface created", "OpenGL ES 2.0 초기화 시작")
        
        // OpenGL 설정
        GLES20.glClearColor(bgRed, bgGreen, bgBlue, bgAlpha)
        GLES20.glEnable(GLES20.GL_BLEND)
        GLES20.glBlendFunc(GLES20.GL_SRC_ALPHA, GLES20.GL_ONE_MINUS_SRC_ALPHA)
        
        // OpenGL 버전 정보 로깅
        val glVersion = GLES20.glGetString(GLES20.GL_VERSION)
        val glVendor = GLES20.glGetString(GLES20.GL_VENDOR)
        val glRenderer = GLES20.glGetString(GLES20.GL_RENDERER)
        Live2DLogger.GL.i("OpenGL 정보", "Version: $glVersion, Vendor: $glVendor, Renderer: $glRenderer")
        
        // Live2D SDK 초기화
        val sdkInitResult = Live2DManager.getInstance().initialize(context)
        Live2DLogger.Renderer.i("Live2D Manager 초기화", if (sdkInitResult) "성공" else "실패")
        
        // 플레이스홀더 셰이더 초기화
        placeholderShader = PlaceholderShader()
        val shaderResult = placeholderShader?.initialize() ?: false
        Live2DLogger.GL.i("플레이스홀더 셰이더", if (shaderResult) "초기화 성공" else "초기화 실패")
        
        // 텍스처 렌더러 초기화
        textureRenderer = TextureModelRenderer()
        val textureResult = textureRenderer?.initialize() ?: false
        Live2DLogger.GL.i("텍스처 렌더러", if (textureResult) "초기화 성공" else "초기화 실패")
        
        isReady = true
        lastFrameTime = System.currentTimeMillis()
        Live2DLogger.Renderer.i("렌더러 준비 완료", "isReady=true")
        
        // 대기 중인 모델 로드
        pendingModelPath?.let { path ->
            pendingModelName?.let { name ->
                Live2DLogger.Model.d("대기 중인 모델 로드 시작", "path=$path, name=$name")
                loadModelInternal(path, name)
                pendingModelPath = null
                pendingModelName = null
            }
        }
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
        if (!isReady || isPaused) return
        
        // FPS 제한 (프레임 스킵 방식)
        val currentTime = System.currentTimeMillis()
        val elapsed = currentTime - lastFrameTime
        
        // 목표 프레임 시간보다 빠르면 이전 프레임 유지 (다시 그리기만 함)
        if (enableFpsLimit && elapsed < frameTimeMs) {
            // 화면 클리어만 하고 이전 내용 유지 (버퍼 스왑은 GLSurfaceView가 처리)
            return
        }
        lastFrameTime = currentTime
        
        // 델타 타임 계산 (실제 경과 시간 사용)
        val deltaTime = elapsed.coerceAtLeast(1L) / 1000f
        
        // 화면 클리어
        GLES20.glClear(GLES20.GL_COLOR_BUFFER_BIT or GLES20.GL_DEPTH_BUFFER_BIT)
        
        // 모델 업데이트 및 렌더링
        currentModel?.let { model ->
            // 시선 추적 적용
            if (isLookAtActive) {
                model.lookAt(lookAtX, lookAtY)
            }
            
            // 모델 업데이트
            model.update(deltaTime)
            
            // 텍스처 기반 렌더링 시도
            val texturePath = model.getFirstTexturePath()
            if (texturePath != null && textureRenderer?.hasLoadedTexture() == true) {
                // 텍스처 렌더링
                textureRenderer?.render(
                    mvpMatrix,
                    model.getX(),
                    model.getY(),
                    model.getScale(),
                    model.getRotation(),
                    model.getOpacity()
                )
            } else {
                // 플레이스홀더 렌더링 (모델 있지만 텍스처 없음)
                renderModelPlaceholder(model)
            }
        } ?: run {
            // 모델 없을 때 대기 상태 플레이스홀더
            renderNoModelPlaceholder()
        }
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
            
            // 기존 모델 해제
            currentModel?.let {
                Live2DLogger.Model.d("기존 모델 해제", it.modelName)
                it.dispose()
            }
            
            // 새 모델 생성 및 로드
            val model = Live2DModel(modelPath, modelName)
            if (model.load()) {
                currentModel = model
                
                // 텍스처 로드 시도
                val texturePath = model.getFirstTexturePath()
                if (texturePath != null) {
                    Live2DLogger.Model.d("텍스처 로드 시도", texturePath)
                    textureRenderer?.loadTexture(texturePath)
                }
                
                val info = model.getDetailedInfo()
                Live2DLogger.Model.i(
                    "모델 로드 성공", 
                    "name=$modelName, textures=${info["textureCount"]}, " +
                    "motionGroups=${info["motionGroupCount"]}, expressions=${info["expressionCount"]}"
                )
                return true
            } else {
                Live2DLogger.Model.e("모델 로드 실패", "name=$modelName, path=$modelPath")
                return false
            }
        } catch (e: Exception) {
            Live2DLogger.Model.e("모델 로드 예외", "name=$modelName", e)
            return false
        }
    }
    
    /**
     * 모션 재생
     */
    fun playMotion(motionName: String, loop: Boolean): Boolean {
        return currentModel?.playMotion(motionName, loop) ?: false
    }
    
    /**
     * 표정 설정
     */
    fun setExpression(expressionName: String): Boolean {
        return currentModel?.setExpression(expressionName) ?: false
    }
    
    /**
     * 스케일 설정
     */
    fun setModelScale(scale: Float) {
        currentModel?.setScale(scale)
    }
    
    /**
     * 위치 설정
     */
    fun setModelPosition(x: Float, y: Float) {
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
        Live2DLogger.Renderer.d("저전력 모드", if (enabled) "활성화" else "비활성화")
    }
    
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
     * 리소스 해제
     */
    fun dispose() {
        currentModel?.dispose()
        currentModel = null
        placeholderShader?.dispose()
        placeholderShader = null
        textureRenderer?.dispose()
        textureRenderer = null
        isReady = false
        Live2DLogger.Renderer.i("렌더러 정리됨", null)
    }
}

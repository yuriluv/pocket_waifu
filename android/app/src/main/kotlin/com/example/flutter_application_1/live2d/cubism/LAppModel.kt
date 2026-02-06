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
 * LAppModel - Live2D Cubism SDK 모델 래퍼
 * 
 * Cubism SDK for Native를 직접 사용하여 Live2D 모델을 로드하고 렌더링합니다.
 * 
 * 핵심 기능:
 * - moc3 파일 로드 (바이너리)
 * - 텍스처 바인딩
 * - 모션 재생 (Idle 루프)
 * - 프레임 업데이트
 * - OpenGL 렌더링
 * 
 * SDK 미설치 시 모든 메서드는 안전하게 실패합니다.
 */
class LAppModel(
    private val modelDir: File,
    private val parser: Model3JsonParser
) {
    companion object {
        private const val TAG = "LAppModel"
        
        // 모션 우선순위
        const val PRIORITY_NONE = 0
        const val PRIORITY_IDLE = 1
        const val PRIORITY_NORMAL = 2
        const val PRIORITY_FORCE = 3
    }
    
    // ============================================
    // Phase 7-2: SDK 렌더링 상태 (JNI 기반)
    // ============================================
    @Volatile private var isSdkRenderingActive = false
    
    // Lifecycle state
    @Volatile private var isModelLoaded = false
    @Volatile private var isRendererInitialized = false
    @Volatile private var isReleased = false  // Prevents double-release
    
    // moc3 데이터
    private var mocBuffer: ByteBuffer? = null
    
    // 텍스처 ID 배열
    private val textureIds = mutableListOf<Int>()
    
    // 텍스처 관리자 (단일 인스턴스 재사용 - 메모리 누수 방지)
    // WHY: loadTexture()가 호출될 때마다 새 CubismTextureManager를 생성하면
    // 불필요한 객체 할당이 발생합니다. 단일 인스턴스를 재사용합니다.
    private val textureManager = CubismTextureManager()
    
    // 모션 관리자
    private var motionManager: CubismMotionManager? = null
    
    // 모델 파라미터 (캐시)
    private var modelOpacity = 1.0f
    
    // 자동 눈 깜빡임 타이머
    private var eyeBlinkTime = 0f
    private var nextBlinkTime = 3f
    private var isBlinking = false
    private var blinkProgress = 0f
    
    // 자동 호흡 타이머
    private var breathTime = 0f
    
    /**
     * 모델 로드
     * 
     * MUST: GL 스레드에서 호출
     * 
     * @return 성공 여부
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
            // 1. moc3 파일 로드
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
            
            // moc3 바이너리 읽기
            mocBuffer = loadMocFile(mocFile)
            if (mocBuffer == null) {
                Live2DLogger.w("$TAG: Failed to load moc3 binary", null)
                return false
            }
            
            Live2DLogger.d("$TAG: moc3 loaded", "${mocFile.length()} bytes")
            
            // ============================================
            // Phase 7-2: SDK 모델 생성 (JNI)
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
            
            // 2. 모션 관리자 초기화
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
     * 렌더러 초기화 (텍스처 바인딩 포함)
     * 
     * MUST: GL 스레드에서 호출
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
            // 텍스처 로드
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
            // Phase 7-2: SDK 렌더러 초기화 (JNI)
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
     * 모델 업데이트 (매 프레임)
     * 
     * Safe: Returns immediately if model not ready or released
     * 
     * @param deltaTime 이전 프레임과의 시간 차이 (초)
     */
    fun update(deltaTime: Float) {
        if (isReleased || !isModelLoaded) return
        
        val dt = deltaTime.coerceIn(0.001f, 0.1f)
        
        // ============================================
        // Phase 7-2: SDK 모델 업데이트 (실제 구현)
        // ============================================
        if (isSdkRenderingActive) {
            try {
                // Phase 7-2: 기본 모델 갱신만 수행
                // 모션/물리/눈깜빡임은 Phase 7-3에서 구현
                Live2DNativeBridge.nativeUpdate()
            } catch (e: Exception) {
                Live2DLogger.w("$TAG: [Phase7-2] Model update exception", e.message)
            }
        }
        
        // 폴백: 모션 타이머만 업데이트
        motionManager?.update(dt)
        
        // 자동 동작 타이머 업데이트
        updateEyeBlinkTimer(dt)
        updateBreathTimer(dt)
    }
    
    /**
     * 모델 렌더링
     * 
     * MUST: GL 스레드에서 호출
     * Safe: Returns immediately if not ready or released
     * 
     * @param mvpMatrix MVP 변환 행렬 (4x4)
     */
    fun draw(mvpMatrix: FloatArray) {
        if (isReleased || !isModelLoaded || !isRendererInitialized) return
        
        // ============================================
        // Phase 7-2: SDK 렌더링 (실제 구현)
        // ============================================
        if (isSdkRenderingActive) {
            try {
                // MVP 행렬 설정 및 모델 렌더링 (JNI)
                Live2DNativeBridge.nativeDraw(mvpMatrix)
                return
            } catch (e: Exception) {
                Live2DLogger.w("$TAG: [Phase7-2] Draw exception", e.message)
                // 폴백 렌더링으로 진행
            }
        }
        
        // 폴백: SDK 렌더링 불가 시 아무것도 그리지 않음
        // (폴백 렌더링은 Live2DGLRenderer에서 처리)
    }
    
    /**
     * SDK 렌더링 활성 여부
     */
    fun isSdkRendering(): Boolean = isSdkRenderingActive
    
    /**
     * Idle 모션 시작
     */
    fun startIdleMotion(): Boolean {
        motionManager?.let { mm ->
            // 일반적인 Idle 그룹명 시도
            val idleNames = listOf("Idle", "idle", "IDLE", "待機")
            
            for (name in idleNames) {
                if (mm.startMotion(name, 0, PRIORITY_IDLE, loop = true)) {
                    Live2DLogger.d("$TAG: Started idle motion", name)
                    return true
                }
            }
            
            // Idle을 못 찾으면 첫 번째 모션 그룹 시도
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
     * 모션 재생
     */
    fun playMotion(group: String, index: Int, priority: Int): Boolean {
        return motionManager?.startMotion(group, index, priority) ?: false
    }
    
    /**
     * 불투명도 설정
     */
    fun setOpacity(opacity: Float) {
        modelOpacity = opacity.coerceIn(0f, 1f)
    }
    
    /**
     * 로드 상태
     */
    fun isLoaded(): Boolean = isModelLoaded
    
    /**
     * 렌더러 초기화 상태
     */
    fun isRendererReady(): Boolean = isRendererInitialized
    
    /**
     * 첫 번째 텍스처 ID 반환 (폴백용)
     */
    fun getFirstTextureId(): Int = textureIds.getOrNull(0) ?: 0
    
    /**
     * 리소스 해제
     * 
     * MUST: GL 스레드에서 호출
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
            // 모션 관리자 해제
            motionManager?.release()
            motionManager = null
            
            // 텍스처 해제
            // NOTE: textureManager가 실제 GL 텍스처를 관리합니다.
            // textureIds는 LAppModel의 로컬 캐시이므로 여기서는 목록만 정리합니다.
            try {
                textureManager.release()
                Live2DLogger.d("$TAG: TextureManager released", null)
            } catch (e: Exception) {
                Live2DLogger.w("$TAG: TextureManager release error", e.message)
            }
            textureIds.clear()
            
            // ============================================
            // Phase 7-2: SDK 리소스 해제 (JNI)
            // ============================================
            try {
                Live2DLogger.d("$TAG: [Phase7-2] Releasing native model", null)
                Live2DNativeBridge.nativeReleaseModel()
                Live2DLogger.d("$TAG: [Phase7-2] Native model released", null)
            } catch (e: Exception) {
                Live2DLogger.w("$TAG: [Phase7-2] Native model release error", e.message)
            }

            isSdkRenderingActive = false
            
            // moc 버퍼 해제
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
     * moc3 파일 로드
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
     * 텍스처 로드
     * 
     * WHY: 인스턴스 레벨의 textureManager를 재사용하여 불필요한
     * 객체 생성을 방지합니다. 이전에는 매 호출마다 새 manager를 
     * 생성했는데, 이는 메모리 누수의 원인이 될 수 있습니다.
     */
    private fun loadTexture(path: String): Int {
        return textureManager.loadTexture(path)
    }
    
    /**
     * 눈 깜빡임 타이머 업데이트 (폴백용)
     */
    private fun updateEyeBlinkTimer(dt: Float) {
        eyeBlinkTime += dt
        
        if (!isBlinking && eyeBlinkTime >= nextBlinkTime) {
            isBlinking = true
            blinkProgress = 0f
        }
        
        if (isBlinking) {
            blinkProgress += dt * 10f // 0.1초에 완료
            if (blinkProgress >= 1f) {
                isBlinking = false
                eyeBlinkTime = 0f
                nextBlinkTime = 2f + (Math.random() * 4f).toFloat() // 2~6초 랜덤
            }
        }
    }
    
    /**
     * 호흡 타이머 업데이트 (폴백용)
     */
    private fun updateBreathTimer(dt: Float) {
        breathTime += dt
        // 호흡 사이클: 약 4초
        // sin 함수로 부드러운 움직임
    }
    
    // ============================================
    // SDK 활성화 후 사용할 메서드들 (현재 미사용)
    // ============================================
    
    /**
     * 눈 깜빡임 파라미터 업데이트 (SDK 전용)
     */
    // private fun updateEyeBlink(model: CubismModel, dt: Float) {
    //     // 눈 파라미터 ID (일반적인 이름들)
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
     * 호흡 파라미터 업데이트 (SDK 전용)
     */
    // private fun updateBreath(model: CubismModel, dt: Float) {
    //     val breathParamId = CubismFramework.getIdManager().getId("ParamBreath")
    //     val breathValue = (kotlin.math.sin(breathTime * 1.57f) + 1f) / 2f
    //     model.setParameterValue(breathParamId, breathValue)
    // }
}

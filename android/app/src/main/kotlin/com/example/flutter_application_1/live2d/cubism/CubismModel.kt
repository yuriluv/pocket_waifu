package com.example.flutter_application_1.live2d.cubism

import android.opengl.Matrix
import com.example.flutter_application_1.live2d.core.Live2DLogger
import com.example.flutter_application_1.live2d.core.Model3JsonParser
import java.io.File

/**
 * Cubism SDK 모델 래퍼 (Facade)
 * 
 * Live2D 모델의 로딩, 업데이트, 렌더링을 캡슐화합니다.
 * SDK 사용 가능 시 LAppModel에 위임, 아니면 폴백 모드로 동작합니다.
 * 
 * Phase 7 구조:
 * - isSdkMode = true: LAppModel을 통한 실제 SDK 렌더링
 * - isSdkMode = false: TextureModelRenderer를 통한 텍스처 프리뷰
 * 
 * 지원 기능:
 * - moc3 파일 로딩 (SDK 모드)
 * - 텍스처 바인딩
 * - 모션 관리 (Idle 자동 재생)
 * - 변환 (위치, 스케일, 회전)
 * - 렌더링
 */
class CubismModel(
    private val modelPath: String,
    val modelName: String
) {
    companion object {
        private const val TAG = "CubismModel"
        
        // 모션 우선순위
        const val PRIORITY_NONE = 0
        const val PRIORITY_IDLE = 1
        const val PRIORITY_NORMAL = 2
        const val PRIORITY_FORCE = 3
    }
    
    // 모델 디렉토리
    private val modelDir: File = File(modelPath).parentFile ?: File("")
    
    // SDK 모델 래퍼 (SDK 모드에서만 사용)
    private var lappModel: LAppModel? = null
    
    // 텍스처 관리자 (폴백 모드에서만 사용)
    private val textureManager = CubismTextureManager()
    
    // JSON 파서
    private var parser: Model3JsonParser? = null
    
    // 상태
    private var isLoaded = false
    private var isSdkMode = false
    
    // 변환 파라미터
    private var posX = 0f
    private var posY = 0f
    private var scale = 1f
    private var rotation = 0f
    private var opacity = 1f
    
    // 모션 상태 (폴백 모드용)
    private var currentMotionGroup: String? = null
    private var currentMotionIndex: Int = 0
    private var isMotionLooping = false
    private var motionTime = 0f
    
    // 모델 행렬
    private val modelMatrix = FloatArray(16)
    private val mvpMatrix = FloatArray(16)
    
    /**
     * 모델 로드
     * 
     * MUST: GL 스레드에서 호출
     * 
     * @return 로드 성공 여부
     */
    fun load(): Boolean {
        if (isLoaded) {
            Live2DLogger.w("$TAG: Model already loaded", modelName)
            return true
        }
        
        Live2DLogger.i("$TAG: Loading model", modelName)
        Live2DLogger.d("$TAG: Path", modelPath)
        
        try {
            // 1. model3.json 파싱
            parser = Model3JsonParser(modelPath)
            if (parser?.parse() != true) {
                Live2DLogger.e("$TAG: Failed to parse model3.json", null)
                return false
            }
            
            val p = parser!!
            Live2DLogger.d("$TAG: Parsed", "moc=${p.mocFile != null}, textures=${p.textures.size}")
            
            // 2. moc3 파일 확인
            val mocPath = p.mocFile
            if (mocPath == null) {
                Live2DLogger.e("$TAG: moc3 file not specified in model3.json", null)
                return false
            }
            
            if (!File(mocPath).exists()) {
                Live2DLogger.e("$TAG: moc3 file not found: $mocPath", null)
                return false
            }
            
            // 3. SDK 모드 확인
            isSdkMode = CubismFrameworkManager.isSdkAvailable()
            
            if (isSdkMode) {
                // SDK 모드: LAppModel 사용
                Live2DLogger.i("$TAG: SDK mode", "Using LAppModel")
                
                lappModel = LAppModel(modelDir, p)
                
                if (!lappModel!!.loadModel()) {
                    Live2DLogger.w("$TAG: LAppModel load failed", "falling back to texture mode")
                    lappModel = null
                    isSdkMode = false
                } else {
                    // 렌더러 초기화 (텍스처 바인딩)
                    if (!lappModel!!.initializeRenderer()) {
                        Live2DLogger.w("$TAG: LAppModel renderer init failed", null)
                    }
                }
            }
            
            if (!isSdkMode) {
                // 폴백 모드: 텍스처만 로드
                Live2DLogger.i("$TAG: Fallback mode", "Texture preview only")
                
                if (p.textures.isNotEmpty()) {
                    textureManager.loadTextures(p.textures)
                    Live2DLogger.d("$TAG: Textures loaded", "${textureManager.getValidTextureCount()}")
                }
            }
            
            isLoaded = true
            Live2DLogger.i("$TAG: ✓ Model loaded", "$modelName (mode: ${if (isSdkMode) "SDK" else "Fallback"})")
            
            // 4. Idle 모션 자동 시작
            autoStartIdleMotion()
            
            return true
            
        } catch (e: Exception) {
            Live2DLogger.e("$TAG: Model load exception", e)
            release()
            return false
        }
    }
    
    /**
     * Idle 모션 자동 시작
     */
    private fun autoStartIdleMotion() {
        // SDK 모드: LAppModel에 위임
        lappModel?.let {
            if (it.startIdleMotion()) {
                Live2DLogger.d("$TAG: SDK idle motion started", null)
                return
            }
        }
        
        // 폴백 모드: 모션 그룹 시뮬레이션
        val idleGroupNames = listOf("Idle", "idle", "IDLE", "待機", "idle_00", "Idle_00")
        
        for (groupName in idleGroupNames) {
            if (playMotion(groupName, 0, PRIORITY_IDLE)) {
                Live2DLogger.d("$TAG: Auto-started idle motion", groupName)
                return
            }
        }
        
        // Idle을 못 찾으면 첫 번째 모션 그룹 시도
        parser?.motionGroups?.keys?.firstOrNull()?.let { firstGroup ->
            if (playMotion(firstGroup, 0, PRIORITY_IDLE)) {
                Live2DLogger.d("$TAG: Auto-started first motion", firstGroup)
            }
        }
    }
    
    /**
     * 모델 업데이트 (매 프레임 호출)
     * 
     * @param deltaTime 이전 프레임과의 시간 차이 (초)
     */
    fun update(deltaTime: Float) {
        if (!isLoaded) return
        
        val safeDelta = deltaTime.coerceIn(0.001f, 0.1f)
        
        val model = lappModel
        if (isSdkMode && model != null) {
            // SDK 모드: LAppModel에 위임 (로컬 변수로 NPE 방지)
            try {
                model.update(safeDelta)
                model.setOpacity(opacity)
            } catch (e: Exception) {
                Live2DLogger.e("$TAG: SDK update error - Switching to fallback", e)
                lappModel = null
                isSdkMode = false
            }
        } else {
            // 폴백 모드: 타이머만 업데이트
            motionTime += safeDelta
        }
    }
    
    /**
     * 모델 렌더링
     * 
     * MUST: GL 스레드에서 호출
     * 
     * @param projectionMatrix 프로젝션 행렬 (4x4)
     */
    fun draw(projectionMatrix: FloatArray) {
        if (!isLoaded) return
        
        // 모델 행렬 계산
        Matrix.setIdentityM(modelMatrix, 0)
        Matrix.translateM(modelMatrix, 0, posX, posY, 0f)
        Matrix.scaleM(modelMatrix, 0, scale, scale, 1f)
        Matrix.rotateM(modelMatrix, 0, rotation, 0f, 0f, 1f)
        
        // MVP 행렬 계산
        Matrix.multiplyMM(mvpMatrix, 0, projectionMatrix, 0, modelMatrix, 0)
        
        val model = lappModel
        if (isSdkMode && model != null) {
            // SDK 모드: LAppModel로 렌더링 (로컬 변수로 NPE 방지)
            try {
                model.draw(mvpMatrix)
            } catch (e: Exception) {
                Live2DLogger.e("$TAG: SDK draw error - Frame skipped", e)
            }
        }
        
        // 폴백 모드: 렌더링은 Live2DGLRenderer에서 TextureModelRenderer로 처리
    }
    
    /**
     * 모션 재생
     * 
     * @param group 모션 그룹 이름 (예: "Idle", "TapBody")
     * @param index 그룹 내 모션 인덱스
     * @param priority 우선순위 (PRIORITY_* 상수)
     * @return 재생 시작 성공 여부
     */
    fun playMotion(group: String, index: Int, priority: Int = PRIORITY_NORMAL): Boolean {
        if (!isLoaded) return false
        
        // SDK 모드: LAppModel에 위임
        if (isSdkMode && lappModel != null) {
            return lappModel!!.playMotion(group, index, priority)
        }
        
        // 폴백 모드: 모션 그룹 확인만 하고 상태 업데이트
        val motionGroups = parser?.motionGroups ?: return false
        val motions = motionGroups[group] ?: return false
        
        if (index >= motions.size) {
            Live2DLogger.w("$TAG: Motion index out of range", "$group[$index]")
            return false
        }
        
        currentMotionGroup = group
        currentMotionIndex = index
        isMotionLooping = group.equals("Idle", ignoreCase = true)
        motionTime = 0f
        
        Live2DLogger.d("$TAG: Motion started (fallback)", "$group[$index] (loop=$isMotionLooping)")
        return true
    }
    
    /**
     * 표정 설정
     * 
     * @param expressionName 표정 이름
     * @return 설정 성공 여부
     */
    fun setExpression(expressionName: String): Boolean {
        if (!isLoaded) return false
        
        val expressions = parser?.expressions ?: return false
        val expression = expressions.find { it.name == expressionName } ?: return false
        
        // SDK 모드에서는 LAppModel이 처리 (향후 구현)
        // 현재는 로그만 출력
        
        Live2DLogger.d("$TAG: Expression set", expressionName)
        return true
    }
    
    // === Transform Setters ===
    
    fun setPosition(x: Float, y: Float) {
        posX = x
        posY = y
    }
    
    fun setScale(s: Float) {
        scale = s.coerceIn(0.1f, 5f)
    }
    
    fun setRotation(degrees: Float) {
        rotation = degrees % 360f
    }
    
    fun setOpacity(o: Float) {
        opacity = o.coerceIn(0f, 1f)
    }
    
    // === Getters ===
    
    fun getX() = posX
    fun getY() = posY
    fun getScale() = scale
    fun getRotation() = rotation
    fun getOpacity() = opacity
    fun isReady() = isLoaded
    
    /**
     * SDK 렌더링 사용 여부 (Phase 7-2)
     * 
     * LAppModel이 실제로 SDK 렌더링을 수행 중인 경우에만 true 반환.
     * isSdkMode만으로는 불충분함 - 실제 렌더러 초기화까지 완료되어야 함.
     */
    fun isUsingSdk(): Boolean {
        return isSdkMode && (lappModel?.isSdkRendering() == true)
    }
    
    fun getModelPath() = modelPath
    
    /**
     * 첫 번째 텍스처 경로 반환 (폴백 모드용)
     */
    fun getFirstTexturePath(): String? {
        return parser?.textures?.firstOrNull()
    }
    
    /**
     * 첫 번째 텍스처 ID 반환
     */
    fun getFirstTextureId(): Int {
        return textureManager.getTextureId(0)
    }
    
    /**
     * 모델 정보 반환
     */
    fun getInfo(): Map<String, Any> {
        val p = parser
        return mapOf(
            "name" to modelName,
            "path" to modelPath,
            "loaded" to isLoaded,
            "sdkMode" to isSdkMode,
            "hasMoc" to (p?.mocFile != null),
            "textureCount" to (p?.textures?.size ?: 0),
            "motionGroups" to (p?.motionGroups?.mapValues { it.value.size } ?: emptyMap()),
            "expressions" to (p?.expressions?.map { it.name } ?: emptyList()),
            "currentMotion" to "${currentMotionGroup ?: "none"}[$currentMotionIndex]",
            "position" to mapOf("x" to posX, "y" to posY),
            "scale" to scale,
            "opacity" to opacity
        )
    }
    
    /**
     * 모든 리소스 해제
     * 
     * MUST: GL 스레드에서 호출
     */
    fun release() {
        if (!isLoaded) return
        
        Live2DLogger.d("$TAG: Releasing model", modelName)
        
        // 1. LAppModel 해제 (SDK 모드)
        try {
            lappModel?.release()
        } catch (e: Exception) {
            Live2DLogger.e("$TAG: LAppModel release error", e)
        } finally {
            lappModel = null
        }
        
        // 2. 텍스처 해제 (폴백 모드)
        try {
            textureManager.release()
        } catch (e: Exception) {
            Live2DLogger.e("$TAG: Texture release error", e)
        }
        
        // 3. 상태 초기화
        parser = null
        isLoaded = false
        isSdkMode = false
        currentMotionGroup = null
        currentMotionIndex = 0
        motionTime = 0f
        
        Live2DLogger.d("$TAG: ✓ Model released", modelName)
    }
}

package com.example.flutter_application_1.live2d.core

import java.io.File

/**
 * Live2D Model 래퍼 클래스
 * 
 * 개별 Live2D 모델의 로딩, 업데이트, 렌더링을 담당합니다.
 * model3.json을 파싱하여 텍스처, 모션, 표정 정보를 관리합니다.
 */
class Live2DModel(
    val modelPath: String,
    val modelName: String
) {
    // 모델 상태
    private var isLoaded = false
    private var currentMotion: String? = null
    private var currentExpression: String? = null
    
    // 모델 파라미터
    private var modelScale = 1.0f
    private var modelX = 0.0f
    private var modelY = 0.0f
    private var modelRotation = 0.0f
    private var modelOpacity = 1.0f
    
    // model3.json 파서
    private var jsonParser: Model3JsonParser? = null
    
    // 파싱된 데이터
    private val availableMotionGroups = mutableMapOf<String, List<String>>()
    private val availableExpressions = mutableListOf<String>()
    private val texturesPaths = mutableListOf<String>()
    private var mocFilePath: String? = null
    
    // 확장된 모델 정보
    data class ModelInfo(
        val name: String,
        val path: String,
        val motions: List<String>,
        val expressions: List<String>,
        val parameterCount: Int,
        val textureCount: Int = 0,
        val motionGroups: Map<String, Int> = emptyMap(),
        val hasMoc: Boolean = false
    )
    
    /**
     * 모델 로드
     */
    fun load(): Boolean {
        if (isLoaded) {
            Live2DLogger.Model.d("모델 이미 로드됨", modelName)
            return true
        }
        
        try {
            val modelFile = File(modelPath)
            if (!modelFile.exists()) {
                Live2DLogger.Model.e("모델 파일을 찾을 수 없음: $modelPath", null)
                return false
            }
            
            // model3.json 파싱
            jsonParser = Model3JsonParser(modelPath)
            val parseResult = jsonParser?.parse() ?: false
            
            if (parseResult) {
                // 파싱 결과 적용
                applyParsedData()
                validateParsedResources()
                Live2DLogger.Model.i(
                    "모델 로드됨",
                    "name=$modelName, textures=${texturesPaths.size}, " +
                    "motionGroups=${availableMotionGroups.size}, expressions=${availableExpressions.size}"
                )
            } else {
                // 파싱 실패 시 폴더 스캔으로 폴백
                Live2DLogger.Model.w("model3.json 파싱 실패, 폴더 스캔으로 폴백", modelName)
                scanMotionsAndExpressionsFromFolders(modelFile.parentFile)
            }
            
            isLoaded = true
            return true
        } catch (e: Exception) {
            Live2DLogger.Model.e("모델 로드 실패: $modelName", e)
            return false
        }
    }
    
    /**
     * 파싱된 데이터 적용
     */
    private fun applyParsedData() {
        val parser = jsonParser ?: return
        
        // 텍스처 경로
        texturesPaths.clear()
        texturesPaths.addAll(parser.textures)
        
        // Moc 파일 경로
        mocFilePath = parser.mocFile
        
        // 모션 그룹
        availableMotionGroups.clear()
        parser.motionGroups.forEach { (groupName, motions) ->
            availableMotionGroups[groupName] = motions.map { it.file }
        }
        
        // 표정
        availableExpressions.clear()
        availableExpressions.addAll(parser.expressions.map { it.name })
    }

    /**
     * 파싱된 리소스 유효성 검증
     */
    private fun validateParsedResources() {
        mocFilePath?.let { moc ->
            if (!File(moc).exists()) {
                Live2DLogger.Model.w("moc3 파일 없음", moc)
            }
        } ?: Live2DLogger.Model.w("moc3 파일 누락", modelName)

        val missingTextures = texturesPaths.filterNot { File(it).exists() }
        if (missingTextures.isNotEmpty()) {
            Live2DLogger.Model.w("누락된 텍스처", "count=${missingTextures.size}")
        }
    }
    
    /**
     * 폴더 기반 모션/표정 스캔 (폴백)
     */
    private fun scanMotionsAndExpressionsFromFolders(modelDir: File?) {
        if (modelDir == null || !modelDir.exists()) return
        
        availableMotionGroups.clear()
        availableExpressions.clear()
        
        // motions 폴더 스캔
        val motionsDir = File(modelDir, "motions")
        if (motionsDir.exists()) {
            val motionFiles = mutableListOf<String>()
            motionsDir.listFiles()?.forEach { file ->
                if (file.extension == "motion3" || file.extension == "json") {
                    motionFiles.add(file.nameWithoutExtension)
                }
            }
            if (motionFiles.isNotEmpty()) {
                availableMotionGroups["default"] = motionFiles
            }
        }
        
        // motion3.json 파일 직접 스캔
        modelDir.listFiles()?.forEach { file ->
            if (file.name.endsWith(".motion3.json")) {
                val existing = availableMotionGroups["default"]?.toMutableList() ?: mutableListOf()
                existing.add(file.nameWithoutExtension)
                availableMotionGroups["default"] = existing
            }
        }
        
        // expressions 폴더 스캔
        val expressionsDir = File(modelDir, "expressions")
        if (expressionsDir.exists()) {
            expressionsDir.listFiles()?.forEach { file ->
                if (file.extension == "exp3" || file.extension == "json") {
                    availableExpressions.add(file.nameWithoutExtension)
                }
            }
        }
        
        // exp3.json 파일 직접 스캔
        modelDir.listFiles()?.forEach { file ->
            if (file.name.endsWith(".exp3.json")) {
                availableExpressions.add(file.nameWithoutExtension.removeSuffix(".exp3"))
            }
        }
        
        // 텍스처 파일 스캔
        texturesPaths.clear()
        val textureExtensions = listOf("png", "jpg", "jpeg")
        modelDir.listFiles()?.forEach { file ->
            if (file.extension.lowercase() in textureExtensions && 
                (file.name.contains("texture") || file.name.startsWith("texture"))) {
                texturesPaths.add(file.absolutePath)
            }
        }
        
        // textures 폴더 스캔
        val texturesDir = File(modelDir, "textures")
        if (texturesDir.exists()) {
            texturesDir.listFiles()?.forEach { file ->
                if (file.extension.lowercase() in textureExtensions) {
                    texturesPaths.add(file.absolutePath)
                }
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
        
        // TODO: 실제 SDK 통합 시 구현
        // - 모션 업데이트
        // - 물리 연산
        // - 포즈 업데이트
        // - 표정 업데이트
    }
    
    /**
     * 모션 재생
     * 
     * @param motionName 재생할 모션 이름 (그룹:인덱스 또는 그룹명)
     * @param loop 반복 여부
     * @param priority 우선순위 (높을수록 우선)
     */
    fun playMotion(motionName: String, loop: Boolean = false, priority: Int = 2): Boolean {
        if (!isLoaded) {
            Live2DLogger.Model.w("모션 재생 불가", "모델 미로드 상태")
            return false
        }
        
        // 모션 그룹에서 검색
        val hasMotion = availableMotionGroups.any { (_, motions) ->
            motions.any { it.contains(motionName, ignoreCase = true) }
        }
        
        if (!hasMotion && motionName != "idle") {
            Live2DLogger.Model.w("모션을 찾을 수 없음", motionName)
        }
        
        currentMotion = motionName
        Live2DLogger.Model.d("모션 재생", "$motionName (loop=$loop, priority=$priority)")
        return true
    }
    
    /**
     * 표정 설정
     * 
     * @param expressionName 표정 이름
     */
    fun setExpression(expressionName: String): Boolean {
        if (!isLoaded) {
            Live2DLogger.Model.w("표정 설정 불가", "모델 미로드 상태")
            return false
        }
        
        if (expressionName !in availableExpressions) {
            Live2DLogger.Model.w("표정을 찾을 수 없음", expressionName)
        }
        
        currentExpression = expressionName
        Live2DLogger.Model.d("표정 설정", expressionName)
        return true
    }
    
    /**
     * 스케일 설정
     */
    fun setScale(scale: Float) {
        modelScale = scale.coerceIn(0.1f, 5.0f)
        Live2DLogger.Model.d("모델 스케일", "$modelScale")
    }
    
    /**
     * 위치 설정
     */
    fun setPosition(x: Float, y: Float) {
        modelX = x
        modelY = y
        Live2DLogger.Model.d("모델 위치", "($modelX, $modelY)")
    }
    
    /**
     * 회전 설정
     */
    fun setRotation(degrees: Float) {
        modelRotation = degrees % 360f
        Live2DLogger.Model.d("모델 회전", "$modelRotation°")
    }
    
    /**
     * 투명도 설정
     */
    fun setOpacity(opacity: Float) {
        modelOpacity = opacity.coerceIn(0f, 1f)
        Live2DLogger.Model.d("모델 투명도", "$modelOpacity")
    }
    
    /**
     * 시선 추적 (LookAt)
     * 
     * @param x 화면 좌표 X (-1.0 ~ 1.0)
     * @param y 화면 좌표 Y (-1.0 ~ 1.0)
     */
    fun lookAt(x: Float, y: Float) {
        if (!isLoaded) return
        
        // TODO: 실제 SDK 통합 시 구현
        // 파라미터 PARAM_EYE_BALL_X, PARAM_EYE_BALL_Y 설정
        // 파라미터 PARAM_ANGLE_X, PARAM_ANGLE_Y 설정
    }
    
    /**
     * 모델 정보 반환 (확장됨)
     */
    fun getInfo(): ModelInfo {
        // 모든 모션 이름 플래튼
        val allMotions = availableMotionGroups.flatMap { (group, motions) ->
            motions.map { "$group:$it" }
        }
        
        return ModelInfo(
            name = modelName,
            path = modelPath,
            motions = allMotions,
            expressions = availableExpressions.toList(),
            parameterCount = 0,
            textureCount = texturesPaths.size,
            motionGroups = availableMotionGroups.mapValues { it.value.size },
            hasMoc = mocFilePath != null
        )
    }
    
    /**
     * 확장된 모델 정보 반환 (Flutter용)
     */
    fun getDetailedInfo(): Map<String, Any> {
        return mapOf(
            "name" to modelName,
            "path" to modelPath,
            "loaded" to isLoaded,
            "hasMoc" to (mocFilePath != null),
            "mocFile" to (mocFilePath ?: ""),
            "textureCount" to texturesPaths.size,
            "textures" to texturesPaths,
            "motionGroups" to availableMotionGroups.mapValues { (_, motions) ->
                motions.map { it }
            },
            "motionGroupCount" to availableMotionGroups.size,
            "totalMotionCount" to availableMotionGroups.values.sumOf { it.size },
            "expressions" to availableExpressions.toList(),
            "expressionCount" to availableExpressions.size,
            "currentMotion" to (currentMotion ?: ""),
            "currentExpression" to (currentExpression ?: ""),
            "scale" to modelScale,
            "x" to modelX,
            "y" to modelY,
            "rotation" to modelRotation,
            "opacity" to modelOpacity
        )
    }
    
    /**
     * 첫 번째 텍스처 경로 반환 (렌더링용)
     */
    fun getFirstTexturePath(): String? {
        return texturesPaths.firstOrNull()
    }
    
    /**
     * 모든 텍스처 경로 반환
     */
    fun getTexturePaths(): List<String> {
        return texturesPaths.toList()
    }
    
    /**
     * 모션 그룹 목록 반환
     */
    fun getMotionGroups(): Map<String, List<String>> {
        return availableMotionGroups.toMap()
    }
    
    /**
     * 표정 목록 반환
     */
    fun getExpressions(): List<String> {
        return availableExpressions.toList()
    }
    
    /**
     * 현재 상태
     */
    fun getScale(): Float = modelScale
    fun getX(): Float = modelX
    fun getY(): Float = modelY
    fun getRotation(): Float = modelRotation
    fun getOpacity(): Float = modelOpacity
    fun getCurrentMotion(): String? = currentMotion
    fun getCurrentExpression(): String? = currentExpression
    fun isModelLoaded(): Boolean = isLoaded
    
    /**
     * 모델 해제
     */
    fun dispose() {
        if (!isLoaded) return
        
        isLoaded = false
        currentMotion = null
        currentExpression = null
        availableMotionGroups.clear()
        availableExpressions.clear()
        texturesPaths.clear()
        mocFilePath = null
        jsonParser = null
        
        Live2DLogger.Model.i("모델 정리됨", modelName)
    }
}

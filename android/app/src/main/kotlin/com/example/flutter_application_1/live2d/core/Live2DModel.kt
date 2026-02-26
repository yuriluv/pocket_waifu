package com.example.flutter_application_1.live2d.core

import java.io.File

/**
 * 
 */
class Live2DModel(
    val modelPath: String,
    val modelName: String
) {
    private var isLoaded = false
    private var currentMotion: String? = null
    private var currentExpression: String? = null
    
    private var modelScale = 1.0f
    private var modelX = 0.0f
    private var modelY = 0.0f
    private var modelRotation = 0.0f
    private var modelOpacity = 1.0f
    
    private var jsonParser: Model3JsonParser? = null
    
    private val availableMotionGroups = mutableMapOf<String, List<String>>()
    private val availableExpressions = mutableListOf<String>()
    private val texturesPaths = mutableListOf<String>()
    private var mocFilePath: String? = null
    
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
            
            jsonParser = Model3JsonParser(modelPath)
            val parseResult = jsonParser?.parse() ?: false
            
            if (parseResult) {
                applyParsedData()
                validateParsedResources()
                Live2DLogger.Model.i(
                    "모델 로드됨",
                    "name=$modelName, textures=${texturesPaths.size}, " +
                    "motionGroups=${availableMotionGroups.size}, expressions=${availableExpressions.size}"
                )
            } else {
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
     */
    private fun applyParsedData() {
        val parser = jsonParser ?: return
        
        texturesPaths.clear()
        texturesPaths.addAll(parser.textures)
        
        mocFilePath = parser.mocFile
        
        availableMotionGroups.clear()
        parser.motionGroups.forEach { (groupName, motions) ->
            availableMotionGroups[groupName] = motions.map { it.file }
        }
        
        availableExpressions.clear()
        availableExpressions.addAll(parser.expressions.map { it.name })
    }

    /**
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
     */
    private fun scanMotionsAndExpressionsFromFolders(modelDir: File?) {
        if (modelDir == null || !modelDir.exists()) return
        
        availableMotionGroups.clear()
        availableExpressions.clear()
        
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
        
        modelDir.listFiles()?.forEach { file ->
            if (file.name.endsWith(".motion3.json")) {
                val existing = availableMotionGroups["default"]?.toMutableList() ?: mutableListOf()
                existing.add(file.nameWithoutExtension)
                availableMotionGroups["default"] = existing
            }
        }
        
        val expressionsDir = File(modelDir, "expressions")
        if (expressionsDir.exists()) {
            expressionsDir.listFiles()?.forEach { file ->
                if (file.extension == "exp3" || file.extension == "json") {
                    availableExpressions.add(file.nameWithoutExtension)
                }
            }
        }
        
        modelDir.listFiles()?.forEach { file ->
            if (file.name.endsWith(".exp3.json")) {
                availableExpressions.add(file.nameWithoutExtension.removeSuffix(".exp3"))
            }
        }
        
        texturesPaths.clear()
        val textureExtensions = listOf("png", "jpg", "jpeg")
        modelDir.listFiles()?.forEach { file ->
            if (file.extension.lowercase() in textureExtensions && 
                (file.name.contains("texture") || file.name.startsWith("texture"))) {
                texturesPaths.add(file.absolutePath)
            }
        }
        
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
     * 
     */
    fun update(deltaTime: Float) {
        if (!isLoaded) return
        
    }
    
    /**
     * 
     */
    fun playMotion(motionName: String, loop: Boolean = false, priority: Int = 2): Boolean {
        if (!isLoaded) {
            Live2DLogger.Model.w("모션 재생 불가", "모델 미로드 상태")
            return false
        }
        
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
     * 
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
     */
    fun setScale(scale: Float) {
        modelScale = scale.coerceIn(0.1f, 5.0f)
        Live2DLogger.Model.d("모델 스케일", "$modelScale")
    }
    
    /**
     */
    fun setPosition(x: Float, y: Float) {
        modelX = x
        modelY = y
        Live2DLogger.Model.d("모델 위치", "($modelX, $modelY)")
    }
    
    /**
     */
    fun setRotation(degrees: Float) {
        modelRotation = degrees % 360f
        Live2DLogger.Model.d("모델 회전", "$modelRotation°")
    }
    
    /**
     */
    fun setOpacity(opacity: Float) {
        modelOpacity = opacity.coerceIn(0f, 1f)
        Live2DLogger.Model.d("모델 투명도", "$modelOpacity")
    }
    
    /**
     * 
     */
    fun lookAt(x: Float, y: Float) {
        if (!isLoaded) return
        
    }
    
    /**
     */
    fun getInfo(): ModelInfo {
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
     */
    fun getFirstTexturePath(): String? {
        return texturesPaths.firstOrNull()
    }
    
    /**
     */
    fun getTexturePaths(): List<String> {
        return texturesPaths.toList()
    }
    
    /**
     */
    fun getMotionGroups(): Map<String, List<String>> {
        return availableMotionGroups.toMap()
    }
    
    /**
     */
    fun getExpressions(): List<String> {
        return availableExpressions.toList()
    }
    
    /**
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

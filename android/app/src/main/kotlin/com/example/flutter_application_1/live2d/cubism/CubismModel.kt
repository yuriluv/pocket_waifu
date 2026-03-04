package com.example.flutter_application_1.live2d.cubism

import android.opengl.Matrix
import com.example.flutter_application_1.live2d.core.Live2DLogger
import com.example.flutter_application_1.live2d.core.Model3JsonParser
import java.io.File

/**
 * 
 * 
 * 
 */
class CubismModel(
    private val modelPath: String,
    val modelName: String
) {
    companion object {
        private const val TAG = "CubismModel"
        
        const val PRIORITY_NONE = 0
        const val PRIORITY_IDLE = 1
        const val PRIORITY_NORMAL = 2
        const val PRIORITY_FORCE = 3
    }
    
    private val modelDir: File = File(modelPath).parentFile ?: File("")
    
    private var lappModel: LAppModel? = null
    
    private val textureManager = CubismTextureManager()
    
    private var parser: Model3JsonParser? = null
    
    private var isLoaded = false
    private var isSdkMode = false
    
    private var posX = 0f
    private var posY = 0f
    private var scale = 1f
    private var rotation = 0f
    private var opacity = 1f
    
    private var currentMotionGroup: String? = null
    private var currentMotionIndex: Int = 0
    private var isMotionLooping = false
    private var motionTime = 0f
    
    private val modelMatrix = FloatArray(16)
    private val mvpMatrix = FloatArray(16)
    
    /**
     * 
     * 
     */
    fun load(): Boolean {
        if (isLoaded) {
            Live2DLogger.w("$TAG: Model already loaded", modelName)
            return true
        }
        
        Live2DLogger.i("$TAG: Loading model", modelName)
        Live2DLogger.d("$TAG: Path", modelPath)
        
        try {
            parser = Model3JsonParser(modelPath)
            if (parser?.parse() != true) {
                Live2DLogger.e("$TAG: Failed to parse model3.json", null)
                return false
            }
            
            val p = parser!!
            Live2DLogger.d("$TAG: Parsed", "moc=${p.mocFile != null}, textures=${p.textures.size}")
            
            val mocPath = p.mocFile
            if (mocPath == null) {
                Live2DLogger.e("$TAG: moc3 file not specified in model3.json", null)
                return false
            }
            
            if (!File(mocPath).exists()) {
                Live2DLogger.e("$TAG: moc3 file not found: $mocPath", null)
                return false
            }
            
            isSdkMode = CubismFrameworkManager.isSdkAvailable()
            
            if (isSdkMode) {
                Live2DLogger.i("$TAG: SDK mode", "Using LAppModel")
                
                lappModel = LAppModel(modelDir, p)
                
                if (!lappModel!!.loadModel()) {
                    Live2DLogger.w("$TAG: LAppModel load failed", "falling back to texture mode")
                    lappModel = null
                    isSdkMode = false
                } else {
                    if (!lappModel!!.initializeRenderer()) {
                        Live2DLogger.w("$TAG: LAppModel renderer init failed", null)
                    }
                }
            }
            
            if (!isSdkMode) {
                Live2DLogger.i("$TAG: Fallback mode", "Texture preview only")
                
                if (p.textures.isNotEmpty()) {
                    textureManager.loadTextures(p.textures)
                    Live2DLogger.d("$TAG: Textures loaded", "${textureManager.getValidTextureCount()}")
                }
            }
            
            isLoaded = true
            Live2DLogger.i("$TAG: ✓ Model loaded", "$modelName (mode: ${if (isSdkMode) "SDK" else "Fallback"})")
            
            autoStartIdleMotion()
            
            return true
            
        } catch (e: Exception) {
            Live2DLogger.e("$TAG: Model load exception", e)
            release()
            return false
        }
    }
    
    /**
     */
    private fun autoStartIdleMotion() {
        lappModel?.let {
            if (it.startIdleMotion()) {
                Live2DLogger.d("$TAG: SDK idle motion started", null)
                return
            }
        }
        
        val idleGroupNames = listOf("Idle", "idle", "IDLE", "待機", "idle_00", "Idle_00")
        
        for (groupName in idleGroupNames) {
            if (playMotion(groupName, 0, PRIORITY_IDLE)) {
                Live2DLogger.d("$TAG: Auto-started idle motion", groupName)
                return
            }
        }
        
        parser?.motionGroups?.keys?.firstOrNull()?.let { firstGroup ->
            if (playMotion(firstGroup, 0, PRIORITY_IDLE)) {
                Live2DLogger.d("$TAG: Auto-started first motion", firstGroup)
            }
        }
    }
    
    /**
     * 
     */
    fun update(deltaTime: Float) {
        if (!isLoaded) return
        
        val safeDelta = deltaTime.coerceIn(0.001f, 0.1f)
        
        val model = lappModel
        if (isSdkMode && model != null) {
            try {
                model.update(safeDelta)
                model.setOpacity(opacity)
            } catch (e: Exception) {
                Live2DLogger.e("$TAG: SDK update error - Switching to fallback", e)
                lappModel = null
                isSdkMode = false
            }
        } else {
            motionTime += safeDelta
        }
    }
    
    /**
     * 
     * 
     */
    fun draw(projectionMatrix: FloatArray) {
        if (!isLoaded) return
        
        Matrix.setIdentityM(modelMatrix, 0)
        Matrix.translateM(modelMatrix, 0, posX, posY, 0f)
        Matrix.scaleM(modelMatrix, 0, scale, scale, 1f)
        Matrix.rotateM(modelMatrix, 0, rotation, 0f, 0f, 1f)
        
        Matrix.multiplyMM(mvpMatrix, 0, projectionMatrix, 0, modelMatrix, 0)
        
        val model = lappModel
        if (isSdkMode && model != null) {
            try {
                model.draw(mvpMatrix)
            } catch (e: Exception) {
                Live2DLogger.e("$TAG: SDK draw error - Frame skipped", e)
            }
        }
        
    }
    
    /**
     * 
     */
    fun playMotion(group: String, index: Int, priority: Int = PRIORITY_NORMAL): Boolean {
        if (!isLoaded) return false
        
        if (isSdkMode && lappModel != null) {
            return lappModel!!.playMotion(group, index, priority)
        }
        
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
     * 
     */
    fun setExpression(expressionName: String): Boolean {
        if (!isLoaded) return false
        
        val expressions = parser?.expressions ?: return false
        val expression = expressions.find { it.name == expressionName } ?: return false
        
        
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
     * 
     */
    fun isUsingSdk(): Boolean {
        return isSdkMode && (lappModel?.isSdkRendering() == true)
    }
    
    fun getModelPath() = modelPath
    
    /**
     */
    fun getFirstTexturePath(): String? {
        return parser?.textures?.firstOrNull()
    }
    
    /**
     */
    fun getFirstTextureId(): Int {
        return textureManager.getTextureId(0)
    }
    
    /**
     */
    fun getInfo(): Map<String, Any> {
        val p = parser
        val parameterInfo = mutableListOf<Map<String, Any>>()
        if (isSdkMode) {
            try {
                val ids = Live2DNativeBridge.safeGetParameterIds()
                for (id in ids) {
                    val current = Live2DNativeBridge.safeGetParameterValue(id) ?: continue
                    parameterInfo.add(
                        mapOf(
                            "id" to id,
                            "value" to current.toDouble(),
                        )
                    )
                }
            } catch (_: Throwable) {
            }
        }

        return mapOf(
            "name" to modelName,
            "path" to modelPath,
            "loaded" to isLoaded,
            "sdkMode" to isSdkMode,
            "hasMoc" to (p?.mocFile != null),
            "textureCount" to (p?.textures?.size ?: 0),
            "motionGroups" to (p?.motionGroups?.mapValues { it.value.size } ?: emptyMap()),
            "expressions" to (p?.expressions?.map { it.name } ?: emptyList()),
            "parameters" to parameterInfo,
            "currentMotion" to "${currentMotionGroup ?: "none"}[$currentMotionIndex]",
            "position" to mapOf("x" to posX, "y" to posY),
            "scale" to scale,
            "opacity" to opacity
        )
    }
    
    /**
     * 
     */
    fun release() {
        if (!isLoaded) return
        
        Live2DLogger.d("$TAG: Releasing model", modelName)
        
        try {
            lappModel?.release()
        } catch (e: Exception) {
            Live2DLogger.e("$TAG: LAppModel release error", e)
        } finally {
            lappModel = null
        }
        
        try {
            textureManager.release()
        } catch (e: Exception) {
            Live2DLogger.e("$TAG: Texture release error", e)
        }
        
        parser = null
        isLoaded = false
        isSdkMode = false
        currentMotionGroup = null
        currentMotionIndex = 0
        motionTime = 0f
        
        Live2DLogger.d("$TAG: ✓ Model released", modelName)
    }
}

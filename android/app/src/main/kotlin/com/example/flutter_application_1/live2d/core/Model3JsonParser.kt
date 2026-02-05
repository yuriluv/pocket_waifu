package com.example.flutter_application_1.live2d.core

import org.json.JSONArray
import org.json.JSONObject
import java.io.File

/**
 * model3.json 파서
 * 
 * Live2D 모델의 model3.json 파일을 파싱하여
 * 모션, 표정, 텍스처 등의 정보를 추출합니다.
 */
class Model3JsonParser(private val modelJsonPath: String) {
    
    private var jsonObject: JSONObject? = null
    private val modelDir: File = File(modelJsonPath).parentFile ?: File("")
    
    // 파싱된 데이터
    var version: Int = 0
        private set
    var mocFile: String? = null
        private set
    var textures: List<String> = emptyList()
        private set
    var physics: String? = null
        private set
    var pose: String? = null
        private set
    var displayInfo: DisplayInfo? = null
        private set
    var motionGroups: Map<String, List<MotionInfo>> = emptyMap()
        private set
    var expressions: List<ExpressionInfo> = emptyList()
        private set
    var hitAreas: List<HitAreaInfo> = emptyList()
        private set
    
    // === 데이터 클래스 ===
    
    data class DisplayInfo(
        val width: Int,
        val height: Int,
        val centerX: Float,
        val centerY: Float
    )
    
    data class MotionInfo(
        val file: String,
        val sound: String? = null,
        val fadeInTime: Float = 0f,
        val fadeOutTime: Float = 0f,
        val absolutePath: String = ""
    )
    
    data class ExpressionInfo(
        val name: String,
        val file: String,
        val absolutePath: String = ""
    )
    
    data class HitAreaInfo(
        val id: String,
        val name: String
    )
    
    /**
     * model3.json 파싱
     */
    fun parse(): Boolean {
        try {
            val file = File(modelJsonPath)
            if (!file.exists()) {
                Live2DLogger.Model.e("model3.json 파일 없음: $modelJsonPath", null as String?)
                return false
            }
            
            val content = file.readText()
            jsonObject = JSONObject(content)
            
            parseVersion()
            parseFileReferences()
            parseMotions()
            parseExpressions()
            parseHitAreas()
            
            Live2DLogger.Model.i(
                "model3.json 파싱 완료",
                "moc=${mocFile != null}, textures=${textures.size}, " +
                "motionGroups=${motionGroups.size}, expressions=${expressions.size}"
            )
            
            return true
        } catch (e: Exception) {
            Live2DLogger.Model.e("model3.json 파싱 실패: $modelJsonPath", e)
            return false
        }
    }
    
    private fun parseVersion() {
        version = jsonObject?.optInt("Version", 3) ?: 3
    }
    
    private fun parseFileReferences() {
        val fileRefs = jsonObject?.optJSONObject("FileReferences") ?: return
        
        // Moc 파일
        mocFile = fileRefs.optString("Moc", null)?.let { resolveRelativePath(it) }
        
        // 텍스처 목록
        val texturesArray = fileRefs.optJSONArray("Textures")
        textures = parseStringArray(texturesArray).map { resolveRelativePath(it) }
        
        // Physics
        physics = fileRefs.optString("Physics", null)?.let { resolveRelativePath(it) }
        
        // Pose
        pose = fileRefs.optString("Pose", null)?.let { resolveRelativePath(it) }
        
        // DisplayInfo
        fileRefs.optJSONObject("DisplayInfo")?.let { di ->
            displayInfo = DisplayInfo(
                width = di.optInt("Width", 0),
                height = di.optInt("Height", 0),
                centerX = di.optDouble("CenterX", 0.0).toFloat(),
                centerY = di.optDouble("CenterY", 0.0).toFloat()
            )
        }
    }
    
    private fun parseMotions() {
        val fileRefs = jsonObject?.optJSONObject("FileReferences") ?: return
        val motionsObj = fileRefs.optJSONObject("Motions") ?: return
        
        val result = mutableMapOf<String, List<MotionInfo>>()
        
        val keys = motionsObj.keys()
        while (keys.hasNext()) {
            val groupName = keys.next()
            val motionsArray = motionsObj.optJSONArray(groupName) ?: continue
            
            val motionList = mutableListOf<MotionInfo>()
            for (i in 0 until motionsArray.length()) {
                val motionObj = motionsArray.optJSONObject(i) ?: continue
                val filePath = motionObj.optString("File", "") 
                
                if (filePath.isNotEmpty()) {
                    motionList.add(MotionInfo(
                        file = filePath,
                        sound = motionObj.optString("Sound", null),
                        fadeInTime = motionObj.optDouble("FadeInTime", 0.0).toFloat(),
                        fadeOutTime = motionObj.optDouble("FadeOutTime", 0.0).toFloat(),
                        absolutePath = resolveRelativePath(filePath)
                    ))
                }
            }
            
            if (motionList.isNotEmpty()) {
                result[groupName] = motionList
            }
        }
        
        motionGroups = result
    }
    
    private fun parseExpressions() {
        val fileRefs = jsonObject?.optJSONObject("FileReferences") ?: return
        val expArray = fileRefs.optJSONArray("Expressions") ?: return
        
        val result = mutableListOf<ExpressionInfo>()
        
        for (i in 0 until expArray.length()) {
            val expObj = expArray.optJSONObject(i) ?: continue
            val name = expObj.optString("Name", "")
            val file = expObj.optString("File", "")
            
            if (name.isNotEmpty() && file.isNotEmpty()) {
                result.add(ExpressionInfo(
                    name = name,
                    file = file,
                    absolutePath = resolveRelativePath(file)
                ))
            }
        }
        
        expressions = result
    }
    
    private fun parseHitAreas() {
        val hitAreasArray = jsonObject?.optJSONArray("HitAreas") ?: return
        
        val result = mutableListOf<HitAreaInfo>()
        
        for (i in 0 until hitAreasArray.length()) {
            val hitObj = hitAreasArray.optJSONObject(i) ?: continue
            val id = hitObj.optString("Id", "")
            val name = hitObj.optString("Name", "")
            
            if (id.isNotEmpty() && name.isNotEmpty()) {
                result.add(HitAreaInfo(id, name))
            }
        }
        
        hitAreas = result
    }
    
    private fun parseStringArray(array: JSONArray?): List<String> {
        if (array == null) return emptyList()
        
        val result = mutableListOf<String>()
        for (i in 0 until array.length()) {
            val value = array.optString(i, null)
            if (!value.isNullOrEmpty()) {
                result.add(value)
            }
        }
        return result
    }
    
    private fun resolveRelativePath(relativePath: String): String {
        return File(modelDir, relativePath).absolutePath
    }
    
    /**
     * 모든 모션 그룹 이름 반환
     */
    fun getMotionGroupNames(): List<String> {
        return motionGroups.keys.toList()
    }
    
    /**
     * 특정 모션 그룹의 모션 수 반환
     */
    fun getMotionCount(groupName: String): Int {
        return motionGroups[groupName]?.size ?: 0
    }
    
    /**
     * 전체 모션 수 반환
     */
    fun getTotalMotionCount(): Int {
        return motionGroups.values.sumOf { it.size }
    }
    
    /**
     * 모든 표정 이름 반환
     */
    fun getExpressionNames(): List<String> {
        return expressions.map { it.name }
    }
    
    /**
     * 요약 정보 반환
     */
    fun getSummary(): Map<String, Any> {
        return mapOf(
            "version" to version,
            "hasMoc" to (mocFile != null),
            "textureCount" to textures.size,
            "motionGroupCount" to motionGroups.size,
            "totalMotionCount" to getTotalMotionCount(),
            "expressionCount" to expressions.size,
            "hitAreaCount" to hitAreas.size,
            "motionGroups" to motionGroups.mapValues { it.value.size },
            "expressionNames" to getExpressionNames()
        )
    }
}

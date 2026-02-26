package com.example.flutter_application_1.live2d.cubism

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.opengl.GLES20
import android.opengl.GLUtils
import com.example.flutter_application_1.live2d.core.Live2DLogger
import java.io.File
import java.util.concurrent.Executors

/**
 * 
 *
 */
class CubismTextureManager {
    
    companion object {
        private const val TAG = "CubismTexture"
        
        private var maxTextureSize = 4096

        private val globalTextureCache = HashMap<String, Int>(8)

        /**
         */
        fun invalidateGlobalCache() {
            globalTextureCache.clear()
            Live2DLogger.d("$TAG: Global texture cache invalidated", null)
        }
    }
    
    private val textureIds = mutableListOf<Int>()
    
    private val textureInfo = mutableMapOf<Int, TextureInfo>()
    
    data class TextureInfo(
        val path: String,
        val width: Int,
        val height: Int,
        val textureId: Int
    )
    
    /**
     */
    fun queryMaxTextureSize() {
        val size = IntArray(1)
        GLES20.glGetIntegerv(GLES20.GL_MAX_TEXTURE_SIZE, size, 0)
        maxTextureSize = size[0]
        Live2DLogger.d(TAG, "GL_MAX_TEXTURE_SIZE: $maxTextureSize")
    }
    
    /**
     * 
     * 
     */
    fun loadTextures(texturePaths: List<String>): List<Int> {
        release()
        
        Live2DLogger.i(TAG, "Loading ${texturePaths.size} textures...")
        
        for ((index, path) in texturePaths.withIndex()) {
            val textureId = loadSingleTexture(path, index)
            textureIds.add(textureId)
            
            if (textureId != 0) {
                Live2DLogger.d(TAG, "  [$index] ✓ Loaded: ${File(path).name} -> ID: $textureId")
            } else {
                Live2DLogger.w(TAG, "  [$index] ✗ Failed: ${File(path).name}")
            }
        }
        
        val successCount = textureIds.count { it != 0 }
        Live2DLogger.i(TAG, "Textures loaded: $successCount/${texturePaths.size}")
        
        return textureIds.toList()
    }
    
    /**
     * 
     * 
     * 
     */
    fun loadTexture(path: String): Int {
        val index = textureIds.size
        val textureId = loadSingleTexture(path, index)
        
        if (textureId != 0) {
            textureIds.add(textureId)
            Live2DLogger.d(TAG, "Loaded single texture: ${File(path).name} -> ID: $textureId")
        } else {
            Live2DLogger.w(TAG, "Failed to load texture: ${File(path).name}")
        }
        
        return textureId
    }
    
    /**
     */
    private fun loadSingleTexture(path: String, index: Int): Int {
        globalTextureCache[path]?.let { cachedId ->
            if (GLES20.glIsTexture(cachedId)) {
                Live2DLogger.d(TAG, "Texture cache hit: ${File(path).name} -> ID: $cachedId")
                textureInfo[cachedId] = TextureInfo(path, 0, 0, cachedId)
                return cachedId
            } else {
                globalTextureCache.remove(path)
            }
        }

        val file = File(path)
        if (!file.exists()) {
            Live2DLogger.w(TAG, "Texture file not found: $path")
            return 0
        }
        
        val bitmap = decodeBitmapOptimized(path) ?: return 0
        
        val textureId = uploadBitmapToGL(bitmap, path)
        bitmap.recycle()

        if (textureId != 0) {
            globalTextureCache[path] = textureId
        }
        
        return textureId
    }

    /**
     *
     */
    private fun decodeBitmapOptimized(path: String): Bitmap? {
        val boundsOptions = BitmapFactory.Options().apply {
            inJustDecodeBounds = true
        }
        BitmapFactory.decodeFile(path, boundsOptions)

        val originalWidth = boundsOptions.outWidth
        val originalHeight = boundsOptions.outHeight
        if (originalWidth <= 0 || originalHeight <= 0) {
            Live2DLogger.w(TAG, "Invalid bitmap dimensions: $path")
            return null
        }

        var sampleSize = 1
        if (originalWidth > maxTextureSize || originalHeight > maxTextureSize) {
            sampleSize = calculateSampleSize(originalWidth, originalHeight, maxTextureSize)
            Live2DLogger.d(TAG, "Downsampling: ${originalWidth}x${originalHeight} /$sampleSize")
        }

        val options = BitmapFactory.Options().apply {
            inScaled = false
            inPreferredConfig = Bitmap.Config.ARGB_8888
            inSampleSize = sampleSize
        }

        val bitmap = BitmapFactory.decodeFile(path, options)
        if (bitmap == null) {
            Live2DLogger.e("$TAG: Failed to decode bitmap: $path", null)
            return null
        }

        // Pre-multiply alpha
        return if (!bitmap.isPremultiplied) {
            bitmap.copy(Bitmap.Config.ARGB_8888, true).also {
                it.isPremultiplied = true
                bitmap.recycle()
            }
        } else {
            bitmap
        }
    }

    /**
     *
     */
    private fun uploadBitmapToGL(bitmap: Bitmap, path: String): Int {
        val textureHandle = IntArray(1)
        GLES20.glGenTextures(1, textureHandle, 0)

        if (textureHandle[0] == 0) {
            checkGLError("glGenTextures")
            return 0
        }

        GLES20.glBindTexture(GLES20.GL_TEXTURE_2D, textureHandle[0])

        val isPOT = isPowerOfTwo(bitmap.width) && isPowerOfTwo(bitmap.height)
        val minFilter = if (isPOT) GLES20.GL_LINEAR_MIPMAP_LINEAR else GLES20.GL_LINEAR
        GLES20.glTexParameteri(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_MIN_FILTER, minFilter)
        GLES20.glTexParameteri(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_MAG_FILTER, GLES20.GL_LINEAR)
        GLES20.glTexParameteri(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_WRAP_S, GLES20.GL_CLAMP_TO_EDGE)
        GLES20.glTexParameteri(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_WRAP_T, GLES20.GL_CLAMP_TO_EDGE)

        GLUtils.texImage2D(GLES20.GL_TEXTURE_2D, 0, bitmap, 0)

        if (isPOT) {
            GLES20.glGenerateMipmap(GLES20.GL_TEXTURE_2D)
        }

        textureInfo[textureHandle[0]] = TextureInfo(
            path = path,
            width = bitmap.width,
            height = bitmap.height,
            textureId = textureHandle[0]
        )

        checkGLError("uploadBitmapToGL")
        return textureHandle[0]
    }
    
    /**
     */
    fun getTextureId(index: Int): Int {
        return textureIds.getOrNull(index) ?: 0
    }
    
    /**
     */
    fun getTextureCount(): Int = textureIds.size
    
    /**
     */
    fun getValidTextureCount(): Int = textureIds.count { it != 0 }
    
    /**
     */
    fun getTextureInfo(textureId: Int): TextureInfo? = textureInfo[textureId]
    
    /**
     * 
     */
    fun release() {
        if (textureIds.isNotEmpty()) {
            val validIds = textureIds.filter { it != 0 }.toIntArray()
            if (validIds.isNotEmpty()) {
                GLES20.glDeleteTextures(validIds.size, validIds, 0)
                checkGLError("glDeleteTextures")
                Live2DLogger.d(TAG, "Released ${validIds.size} textures")
            }
            textureIds.clear()
            textureInfo.clear()
        }
    }
    
    /**
     */
    private fun calculateSampleSize(width: Int, height: Int, maxSize: Int): Int {
        var sampleSize = 1
        var w = width
        var h = height
        
        while (w > maxSize || h > maxSize) {
            sampleSize *= 2
            w /= 2
            h /= 2
        }
        
        return sampleSize
    }

    private fun isPowerOfTwo(value: Int): Boolean {
        return value > 0 && (value and (value - 1)) == 0
    }
    
    /**
     */
    private fun checkGLError(operation: String) {
        var error: Int
        while (GLES20.glGetError().also { error = it } != GLES20.GL_NO_ERROR) {
            Live2DLogger.e("$TAG: GL Error after $operation: $error", null)
        }
    }
}

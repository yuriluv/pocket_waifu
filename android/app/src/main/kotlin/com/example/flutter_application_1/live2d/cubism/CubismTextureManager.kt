package com.example.flutter_application_1.live2d.cubism

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.opengl.GLES20
import android.opengl.GLUtils
import com.example.flutter_application_1.live2d.core.Live2DLogger
import java.io.File
import java.util.concurrent.Executors

/**
 * Cubism 모델용 텍스처 관리자
 * 
 * 텍스처 파일을 OpenGL에 로드하고 모델에 바인딩합니다.
 * 메모리 관리 및 텍스처 ID 추적을 담당합니다.
 *
 * 최적화:
 * - 비트맵 디코드는 백그라운드 스레드에서 수행
 * - GL 업로드만 GL 스레드에서 수행
 * - 동일 경로 텍스처 캐싱
 */
class CubismTextureManager {
    
    companion object {
        private const val TAG = "CubismTexture"
        
        // 최대 텍스처 크기 (기본값, 실제 값은 GL에서 조회)
        private var maxTextureSize = 4096

        // 텍스처 캐시 (경로 → 텍스처 ID) — 프로세스 전역
        // WHY: 동일 모델을 재로드할 때 텍스처를 다시 디코드하지 않습니다.
        // 오버레이 숨김→표시 사이클에서 GL context가 재생성되면 무효화됩니다.
        private val globalTextureCache = HashMap<String, Int>(8)

        /**
         * 전역 캐시 무효화 (GL context 재생성 시 호출)
         */
        fun invalidateGlobalCache() {
            globalTextureCache.clear()
            Live2DLogger.d("$TAG: Global texture cache invalidated", null)
        }
    }
    
    // 로드된 텍스처 ID 목록
    private val textureIds = mutableListOf<Int>()
    
    // 텍스처 정보 (디버깅용)
    private val textureInfo = mutableMapOf<Int, TextureInfo>()
    
    data class TextureInfo(
        val path: String,
        val width: Int,
        val height: Int,
        val textureId: Int
    )
    
    /**
     * GL 최대 텍스처 크기 조회 및 설정
     * onSurfaceCreated에서 호출 권장
     */
    fun queryMaxTextureSize() {
        val size = IntArray(1)
        GLES20.glGetIntegerv(GLES20.GL_MAX_TEXTURE_SIZE, size, 0)
        maxTextureSize = size[0]
        Live2DLogger.d(TAG, "GL_MAX_TEXTURE_SIZE: $maxTextureSize")
    }
    
    /**
     * 여러 텍스처 파일 로드
     * 
     * MUST: GL 스레드에서 호출
     * NOTE: 기존 텍스처를 해제한 후 새로 로드합니다.
     * 
     * @param texturePaths 텍스처 파일 절대 경로 목록
     * @return 로드된 OpenGL 텍스처 ID 목록 (실패 시 해당 인덱스는 0)
     */
    fun loadTextures(texturePaths: List<String>): List<Int> {
        // 기존 텍스처 해제
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
     * 단일 텍스처 로드 (기존 텍스처 유지)
     * 
     * WHY: loadTextures()는 모든 텍스처를 해제하고 다시 로드합니다.
     * 이 메서드는 기존 텍스처를 유지하면서 하나만 추가 로드합니다.
     * LAppModel처럼 개별 텍스처를 순차 로드하는 경우에 사용합니다.
     * 
     * MUST: GL 스레드에서 호출
     * 
     * @param path 텍스처 파일 절대 경로
     * @return 로드된 OpenGL 텍스처 ID (실패 시 0)
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
     * 단일 텍스처 파일 로드
     */
    private fun loadSingleTexture(path: String, index: Int): Int {
        // 캐시 확인
        globalTextureCache[path]?.let { cachedId ->
            // GL 텍스처가 아직 유효한지 확인
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
        
        // 비트맵 디코드 (이 부분이 CPU 집약적)
        val bitmap = decodeBitmapOptimized(path) ?: return 0
        
        // GL 텍스처 업로드
        val textureId = uploadBitmapToGL(bitmap, path)
        bitmap.recycle()

        if (textureId != 0) {
            globalTextureCache[path] = textureId
        }
        
        return textureId
    }

    /**
     * 최적화된 비트맵 디코드
     *
     * WHY: 별도 메서드로 분리하여 향후 백그라운드 디코드 + GLSurfaceView.queueEvent
     * 패턴으로 전환할 수 있는 진입점을 만듭니다.
     */
    private fun decodeBitmapOptimized(path: String): Bitmap? {
        // 크기 확인 (bounds only — 메모리 할당 없음)
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

        // 다운샘플 계산
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
     * 비트맵을 GL 텍스처로 업로드
     *
     * MUST: GL 스레드에서 호출
     */
    private fun uploadBitmapToGL(bitmap: Bitmap, path: String): Int {
        val textureHandle = IntArray(1)
        GLES20.glGenTextures(1, textureHandle, 0)

        if (textureHandle[0] == 0) {
            checkGLError("glGenTextures")
            return 0
        }

        GLES20.glBindTexture(GLES20.GL_TEXTURE_2D, textureHandle[0])

        // 텍스처 파라미터
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
     * 인덱스로 텍스처 ID 조회
     */
    fun getTextureId(index: Int): Int {
        return textureIds.getOrNull(index) ?: 0
    }
    
    /**
     * 로드된 텍스처 수 반환
     */
    fun getTextureCount(): Int = textureIds.size
    
    /**
     * 유효한 텍스처 수 반환 (로드 성공한 것만)
     */
    fun getValidTextureCount(): Int = textureIds.count { it != 0 }
    
    /**
     * 텍스처 정보 조회
     */
    fun getTextureInfo(textureId: Int): TextureInfo? = textureInfo[textureId]
    
    /**
     * 모든 텍스처 해제
     * 
     * MUST: GL 스레드에서 호출
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
     * 샘플 크기 계산 (다운스케일용)
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
     * GL 에러 체크
     */
    private fun checkGLError(operation: String) {
        var error: Int
        while (GLES20.glGetError().also { error = it } != GLES20.GL_NO_ERROR) {
            Live2DLogger.e("$TAG: GL Error after $operation: $error", null)
        }
    }
}

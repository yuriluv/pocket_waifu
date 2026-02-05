package com.example.flutter_application_1.live2d.renderer

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.opengl.GLES20
import android.opengl.GLUtils
import com.example.flutter_application_1.live2d.core.Live2DLogger
import java.io.File
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.nio.FloatBuffer

/**
 * 텍스처 기반 모델 렌더러
 * 
 * Live2D SDK가 없을 때 모델의 텍스처 이미지를 직접 렌더링합니다.
 * 이를 통해 사용자는 최소한 모델의 외관을 볼 수 있습니다.
 */
class TextureModelRenderer {
    
    companion object {
        // 버텍스 셰이더 (텍스처용)
        private const val VERTEX_SHADER = """
            uniform mat4 uMVPMatrix;
            uniform vec4 uTransform; // x, y, scale, rotation
            attribute vec4 aPosition;
            attribute vec2 aTexCoord;
            varying vec2 vTexCoord;
            
            void main() {
                float scale = uTransform.z;
                float rotation = uTransform.w;
                float cosR = cos(rotation);
                float sinR = sin(rotation);
                
                // 회전 적용
                vec4 rotatedPos;
                rotatedPos.x = aPosition.x * cosR - aPosition.y * sinR;
                rotatedPos.y = aPosition.x * sinR + aPosition.y * cosR;
                rotatedPos.z = aPosition.z;
                rotatedPos.w = aPosition.w;
                
                // 스케일 및 위치 적용
                rotatedPos.xy = rotatedPos.xy * scale + uTransform.xy;
                
                gl_Position = uMVPMatrix * rotatedPos;
                vTexCoord = aTexCoord;
            }
        """
        
        // 프래그먼트 셰이더 (텍스처용)
        private const val FRAGMENT_SHADER = """
            precision mediump float;
            uniform sampler2D uTexture;
            uniform float uOpacity;
            varying vec2 vTexCoord;
            
            void main() {
                vec4 color = texture2D(uTexture, vTexCoord);
                color.a *= uOpacity;
                gl_FragColor = color;
            }
        """
        
        // 사각형 버텍스 (텍스처 표시용)
        private val QUAD_VERTICES = floatArrayOf(
            // Position     // TexCoord
            -0.5f,  0.75f, 0f,   0f, 0f,  // 좌상
             0.5f,  0.75f, 0f,   1f, 0f,  // 우상
            -0.5f, -0.75f, 0f,   0f, 1f,  // 좌하
             0.5f, -0.75f, 0f,   1f, 1f,  // 우하
        )
        
        private const val COORDS_PER_VERTEX = 3
        private const val TEXCOORDS_PER_VERTEX = 2
        private const val STRIDE = (COORDS_PER_VERTEX + TEXCOORDS_PER_VERTEX) * 4
    }
    
    private var programId = 0
    private var mvpMatrixHandle = 0
    private var transformHandle = 0
    private var opacityHandle = 0
    private var textureHandle = 0
    private var positionHandle = 0
    private var texCoordHandle = 0
    
    private var vertexBuffer: FloatBuffer? = null
    private var textureId = 0
    private var isInitialized = false
    private var hasTexture = false
    private var maxTextureSize = 0
    
    // 텍스처 크기 (비율 계산용)
    private var textureWidth = 1
    private var textureHeight = 1
    private var aspectRatio = 1f
    
    /**
     * 초기화
     */
    fun initialize(): Boolean {
        try {
            // 버텍스 셰이더 컴파일
            val vertexShader = compileShader(GLES20.GL_VERTEX_SHADER, VERTEX_SHADER)
            if (vertexShader == 0) return false
            
            // 프래그먼트 셰이더 컴파일
            val fragmentShader = compileShader(GLES20.GL_FRAGMENT_SHADER, FRAGMENT_SHADER)
            if (fragmentShader == 0) {
                GLES20.glDeleteShader(vertexShader)
                return false
            }
            
            // 프로그램 링크
            programId = GLES20.glCreateProgram()
            GLES20.glAttachShader(programId, vertexShader)
            GLES20.glAttachShader(programId, fragmentShader)
            GLES20.glLinkProgram(programId)
            
            val linkStatus = IntArray(1)
            GLES20.glGetProgramiv(programId, GLES20.GL_LINK_STATUS, linkStatus, 0)
            if (linkStatus[0] == 0) {
                Live2DLogger.Renderer.e("텍스처 렌더러 프로그램 링크 실패", null)
                GLES20.glDeleteProgram(programId)
                return false
            }
            
            GLES20.glDeleteShader(vertexShader)
            GLES20.glDeleteShader(fragmentShader)
            
            // 핸들 가져오기
            mvpMatrixHandle = GLES20.glGetUniformLocation(programId, "uMVPMatrix")
            transformHandle = GLES20.glGetUniformLocation(programId, "uTransform")
            opacityHandle = GLES20.glGetUniformLocation(programId, "uOpacity")
            textureHandle = GLES20.glGetUniformLocation(programId, "uTexture")
            positionHandle = GLES20.glGetAttribLocation(programId, "aPosition")
            texCoordHandle = GLES20.glGetAttribLocation(programId, "aTexCoord")
            
            // 버텍스 버퍼 생성
            createVertexBuffer()

            // 최대 텍스처 크기 확인
            val maxSize = IntArray(1)
            GLES20.glGetIntegerv(GLES20.GL_MAX_TEXTURE_SIZE, maxSize, 0)
            maxTextureSize = maxSize[0]
            Live2DLogger.GL.i("GL_MAX_TEXTURE_SIZE", "$maxTextureSize")
            
            isInitialized = true
            Live2DLogger.Renderer.i("텍스처 렌더러 초기화됨", null)
            return true
            
        } catch (e: Exception) {
            Live2DLogger.Renderer.e("텍스처 렌더러 초기화 오류", e)
            return false
        }
    }
    
    private fun compileShader(type: Int, source: String): Int {
        val shader = GLES20.glCreateShader(type)
        GLES20.glShaderSource(shader, source)
        GLES20.glCompileShader(shader)
        
        val compileStatus = IntArray(1)
        GLES20.glGetShaderiv(shader, GLES20.GL_COMPILE_STATUS, compileStatus, 0)
        
        if (compileStatus[0] == 0) {
            Live2DLogger.Renderer.e("셰이더 컴파일 오류: ${GLES20.glGetShaderInfoLog(shader)}", null)
            GLES20.glDeleteShader(shader)
            return 0
        }
        
        return shader
    }
    
    private fun createVertexBuffer() {
        vertexBuffer = ByteBuffer.allocateDirect(QUAD_VERTICES.size * 4)
            .order(ByteOrder.nativeOrder())
            .asFloatBuffer()
            .put(QUAD_VERTICES)
        vertexBuffer?.position(0)
    }
    
    /**
     * 버텍스 버퍼를 이미지 비율에 맞게 업데이트
     */
    private fun updateVertexBufferForAspectRatio() {
        // 이미지 비율에 맞는 버텍스 계산
        val halfWidth: Float
        val halfHeight: Float
        
        if (aspectRatio > 1f) {
            // 이미지가 넓은 경우
            halfWidth = 0.5f
            halfHeight = 0.5f / aspectRatio
        } else {
            // 이미지가 높은 경우
            halfWidth = 0.5f * aspectRatio
            halfHeight = 0.5f
        }
        
        val vertices = floatArrayOf(
            -halfWidth,  halfHeight, 0f,   0f, 0f,
             halfWidth,  halfHeight, 0f,   1f, 0f,
            -halfWidth, -halfHeight, 0f,   0f, 1f,
             halfWidth, -halfHeight, 0f,   1f, 1f,
        )
        
        vertexBuffer?.clear()
        vertexBuffer?.put(vertices)
        vertexBuffer?.position(0)
    }
    
    /**
     * 텍스처 로드
     */
    fun loadTexture(texturePath: String): Boolean {
        try {
            hasTexture = false
            val file = File(texturePath)
            if (!file.exists()) {
                Live2DLogger.Renderer.e("텍스처 파일 없음: $texturePath", null as String?)
                return false
            }
            
            // 이전 텍스처 해제
            if (textureId != 0) {
                GLES20.glDeleteTextures(1, intArrayOf(textureId), 0)
            }
            
            // 비트맵 크기 확인 (bounds only)
            val boundsOptions = BitmapFactory.Options().apply {
                inJustDecodeBounds = true
            }
            BitmapFactory.decodeFile(texturePath, boundsOptions)

            var srcWidth = boundsOptions.outWidth
            var srcHeight = boundsOptions.outHeight
            if (srcWidth <= 0 || srcHeight <= 0) {
                Live2DLogger.Renderer.e("비트맵 크기 확인 실패: $texturePath", null as String?)
                return false
            }

            val maxSize = if (maxTextureSize > 0) maxTextureSize else 4096
            var inSampleSize = 1
            while (srcWidth / inSampleSize > maxSize || srcHeight / inSampleSize > maxSize) {
                inSampleSize *= 2
            }

            if (inSampleSize > 1) {
                Live2DLogger.Renderer.w(
                    "텍스처 크기 축소", "${srcWidth}x${srcHeight} -> /$inSampleSize (max=$maxSize)"
                )
            }

            // 비트맵 로드 (다운샘플 적용)
            val options = BitmapFactory.Options().apply {
                inPreferredConfig = Bitmap.Config.ARGB_8888
                inSampleSize = inSampleSize
            }
            var bitmap = BitmapFactory.decodeFile(texturePath, options)
            
            if (bitmap == null) {
                Live2DLogger.Renderer.e("비트맵 디코드 실패: $texturePath", null as String?)
                return false
            }

            // 최대 텍스처 크기 초과 시 추가 축소
            if (bitmap.width > maxSize || bitmap.height > maxSize) {
                val original = bitmap
                val scale = minOf(
                    maxSize.toFloat() / bitmap.width.toFloat(),
                    maxSize.toFloat() / bitmap.height.toFloat()
                )
                val targetW = (bitmap.width * scale).toInt().coerceAtLeast(1)
                val targetH = (bitmap.height * scale).toInt().coerceAtLeast(1)
                Live2DLogger.Renderer.w(
                    "텍스처 추가 축소", "${bitmap.width}x${bitmap.height} -> ${targetW}x${targetH}"
                )
                bitmap = Bitmap.createScaledBitmap(bitmap, targetW, targetH, true)
                if (bitmap != original) {
                    original.recycle()
                }
            }
            
            textureWidth = bitmap.width
            textureHeight = bitmap.height
            aspectRatio = textureWidth.toFloat() / textureHeight.toFloat()
            
            // 비율에 맞게 버텍스 업데이트
            updateVertexBufferForAspectRatio()
            
            // OpenGL 텍스처 생성
            val textures = IntArray(1)
            GLES20.glGenTextures(1, textures, 0)
            textureId = textures[0]
            
            GLES20.glBindTexture(GLES20.GL_TEXTURE_2D, textureId)
            
            // 텍스처 파라미터 설정
            GLES20.glTexParameteri(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_MIN_FILTER, GLES20.GL_LINEAR)
            GLES20.glTexParameteri(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_MAG_FILTER, GLES20.GL_LINEAR)
            GLES20.glTexParameteri(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_WRAP_S, GLES20.GL_CLAMP_TO_EDGE)
            GLES20.glTexParameteri(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_WRAP_T, GLES20.GL_CLAMP_TO_EDGE)
            
            // 비트맵을 텍스처로 업로드
            GLES20.glPixelStorei(GLES20.GL_UNPACK_ALIGNMENT, 1)
            GLUtils.texImage2D(GLES20.GL_TEXTURE_2D, 0, bitmap, 0)

            // GL 오류 체크
            val glError = GLES20.glGetError()
            if (glError != GLES20.GL_NO_ERROR) {
                Live2DLogger.GL.e("텍스처 업로드 GL 오류", "error=0x${glError.toString(16)}")
                GLES20.glDeleteTextures(1, intArrayOf(textureId), 0)
                textureId = 0
                bitmap.recycle()
                return false
            }
            
            bitmap.recycle()
            
            hasTexture = true
            Live2DLogger.Renderer.i(
                "텍스처 로드됨", 
                "${textureWidth}x${textureHeight}, path=$texturePath"
            )
            return true
            
        } catch (e: Exception) {
            Live2DLogger.Renderer.e("텍스처 로드 오류: $texturePath", e)
            return false
        }
    }
    
    /**
     * 렌더링
     */
    fun render(
        mvpMatrix: FloatArray,
        x: Float,
        y: Float,
        scale: Float,
        rotation: Float,
        opacity: Float
    ) {
        if (!isInitialized || !hasTexture) return
        
        GLES20.glUseProgram(programId)
        
        // Uniform 설정
        GLES20.glUniformMatrix4fv(mvpMatrixHandle, 1, false, mvpMatrix, 0)
        GLES20.glUniform4f(transformHandle, x, y, scale, Math.toRadians(rotation.toDouble()).toFloat())
        GLES20.glUniform1f(opacityHandle, opacity)
        
        // 텍스처 바인딩
        GLES20.glActiveTexture(GLES20.GL_TEXTURE0)
        GLES20.glBindTexture(GLES20.GL_TEXTURE_2D, textureId)
        GLES20.glUniform1i(textureHandle, 0)
        
        // 버텍스 데이터 설정
        vertexBuffer?.position(0)
        GLES20.glEnableVertexAttribArray(positionHandle)
        GLES20.glVertexAttribPointer(
            positionHandle,
            COORDS_PER_VERTEX,
            GLES20.GL_FLOAT,
            false,
            STRIDE,
            vertexBuffer
        )
        
        vertexBuffer?.position(COORDS_PER_VERTEX)
        GLES20.glEnableVertexAttribArray(texCoordHandle)
        GLES20.glVertexAttribPointer(
            texCoordHandle,
            TEXCOORDS_PER_VERTEX,
            GLES20.GL_FLOAT,
            false,
            STRIDE,
            vertexBuffer
        )
        
        // 그리기
        GLES20.glDrawArrays(GLES20.GL_TRIANGLE_STRIP, 0, 4)

        // GL 오류 체크
        val glError = GLES20.glGetError()
        if (glError != GLES20.GL_NO_ERROR) {
            Live2DLogger.GL.e("렌더링 GL 오류", "error=0x${glError.toString(16)}")
        }
        
        // 정리
        GLES20.glDisableVertexAttribArray(positionHandle)
        GLES20.glDisableVertexAttribArray(texCoordHandle)
    }
    
    /**
     * 텍스처 로드 여부
     */
    fun hasLoadedTexture(): Boolean = hasTexture
    
    /**
     * 리소스 해제
     */
    fun dispose() {
        if (textureId != 0) {
            GLES20.glDeleteTextures(1, intArrayOf(textureId), 0)
            textureId = 0
        }
        if (programId != 0) {
            GLES20.glDeleteProgram(programId)
            programId = 0
        }
        vertexBuffer = null
        hasTexture = false
        isInitialized = false
    }
}

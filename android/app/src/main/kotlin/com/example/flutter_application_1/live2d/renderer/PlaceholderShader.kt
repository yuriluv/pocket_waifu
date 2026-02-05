package com.example.flutter_application_1.live2d.renderer

import android.opengl.GLES20
import com.example.flutter_application_1.live2d.core.Live2DLogger
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.nio.FloatBuffer
import kotlin.math.cos
import kotlin.math.sin

/**
 * 플레이스홀더 셰이더
 * 
 * Live2D SDK가 없을 때 기본 도형을 렌더링하는 셰이더
 * SDK 통합 후에는 실제 Live2D 렌더러로 대체됩니다.
 */
class PlaceholderShader {
    
    companion object {
        // 버텍스 셰이더
        private const val VERTEX_SHADER = """
            uniform mat4 uMVPMatrix;
            uniform vec4 uModelTransform; // x, y, scale, rotation
            attribute vec4 aPosition;
            
            void main() {
                float scale = uModelTransform.z;
                float rotation = uModelTransform.w;
                float cosR = cos(rotation);
                float sinR = sin(rotation);
                
                // 회전 적용
                vec4 rotatedPos;
                rotatedPos.x = aPosition.x * cosR - aPosition.y * sinR;
                rotatedPos.y = aPosition.x * sinR + aPosition.y * cosR;
                rotatedPos.z = aPosition.z;
                rotatedPos.w = aPosition.w;
                
                // 스케일 및 위치 적용
                rotatedPos.xy = rotatedPos.xy * scale + uModelTransform.xy;
                
                gl_Position = uMVPMatrix * rotatedPos;
            }
        """
        
        // 프래그먼트 셰이더
        private const val FRAGMENT_SHADER = """
            precision mediump float;
            uniform vec4 uColor;
            
            void main() {
                gl_FragColor = uColor;
            }
        """
        
        // 원 세그먼트 수
        private const val CIRCLE_SEGMENTS = 32
    }
    
    private var programId = 0
    private var mvpMatrixHandle = 0
    private var modelTransformHandle = 0
    private var colorHandle = 0
    private var positionHandle = 0
    
    private var circleVertexBuffer: FloatBuffer? = null
    private var isInitialized = false
    
    /**
     * 셰이더 초기화
     */
    fun initialize(): Boolean {
        try {
            // 버텍스 셰이더 컴파일
            val vertexShader = compileShader(GLES20.GL_VERTEX_SHADER, VERTEX_SHADER)
            if (vertexShader == 0) {
                Live2DLogger.Renderer.e("버텍스 셰이더 컴파일 실패", null)
                return false
            }
            
            // 프래그먼트 셰이더 컴파일
            val fragmentShader = compileShader(GLES20.GL_FRAGMENT_SHADER, FRAGMENT_SHADER)
            if (fragmentShader == 0) {
                GLES20.glDeleteShader(vertexShader)
                Live2DLogger.Renderer.e("프래그먼트 셰이더 컴파일 실패", null)
                return false
            }
            
            // 프로그램 링크
            programId = GLES20.glCreateProgram()
            GLES20.glAttachShader(programId, vertexShader)
            GLES20.glAttachShader(programId, fragmentShader)
            GLES20.glLinkProgram(programId)
            
            // 링크 상태 확인
            val linkStatus = IntArray(1)
            GLES20.glGetProgramiv(programId, GLES20.GL_LINK_STATUS, linkStatus, 0)
            if (linkStatus[0] == 0) {
                Live2DLogger.Renderer.e("프로그램 링크 실패: ${GLES20.glGetProgramInfoLog(programId)}", null)
                GLES20.glDeleteProgram(programId)
                return false
            }
            
            // 셰이더는 프로그램에 링크되었으므로 삭제
            GLES20.glDeleteShader(vertexShader)
            GLES20.glDeleteShader(fragmentShader)
            
            // 핸들 가져오기
            mvpMatrixHandle = GLES20.glGetUniformLocation(programId, "uMVPMatrix")
            modelTransformHandle = GLES20.glGetUniformLocation(programId, "uModelTransform")
            colorHandle = GLES20.glGetUniformLocation(programId, "uColor")
            positionHandle = GLES20.glGetAttribLocation(programId, "aPosition")
            
            // 원 버텍스 버퍼 생성
            createCircleVertexBuffer()
            
            isInitialized = true
            Live2DLogger.Renderer.i("플레이스홀더 셰이더 초기화됨", null)
            return true
            
        } catch (e: Exception) {
            Live2DLogger.Renderer.e("셰이더 초기화 오류", e)
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
    
    private fun createCircleVertexBuffer() {
        // 원 버텍스 생성 (중심점 + 외곽점)
        val vertexCount = CIRCLE_SEGMENTS + 2
        val vertices = FloatArray(vertexCount * 3)
        
        // 중심점
        vertices[0] = 0f
        vertices[1] = 0f
        vertices[2] = 0f
        
        // 외곽점
        for (i in 0..CIRCLE_SEGMENTS) {
            val angle = (i.toFloat() / CIRCLE_SEGMENTS) * 2f * Math.PI.toFloat()
            val idx = (i + 1) * 3
            vertices[idx] = cos(angle)
            vertices[idx + 1] = sin(angle)
            vertices[idx + 2] = 0f
        }
        
        // 버퍼 생성
        circleVertexBuffer = ByteBuffer.allocateDirect(vertices.size * 4)
            .order(ByteOrder.nativeOrder())
            .asFloatBuffer()
            .put(vertices)
        circleVertexBuffer?.position(0)
    }
    
    /**
     * 셰이더 사용
     */
    fun use() {
        if (!isInitialized) return
        GLES20.glUseProgram(programId)
    }
    
    /**
     * MVP 행렬 설정
     */
    fun setMVPMatrix(matrix: FloatArray) {
        GLES20.glUniformMatrix4fv(mvpMatrixHandle, 1, false, matrix, 0)
    }
    
    /**
     * 모델 변환 설정
     */
    fun setModelTransform(x: Float, y: Float, scale: Float, rotation: Float) {
        GLES20.glUniform4f(modelTransformHandle, x, y, scale, Math.toRadians(rotation.toDouble()).toFloat())
    }
    
    /**
     * 색상 설정
     */
    fun setColor(r: Float, g: Float, b: Float, a: Float) {
        GLES20.glUniform4f(colorHandle, r, g, b, a)
    }
    
    /**
     * 원 그리기
     */
    fun drawCircle(x: Float, y: Float, radius: Float) {
        if (!isInitialized || circleVertexBuffer == null) return
        
        // 스케일 적용을 위해 버텍스 재계산
        val vertexCount = CIRCLE_SEGMENTS + 2
        val vertices = FloatArray(vertexCount * 3)
        
        // 중심점
        vertices[0] = x
        vertices[1] = y
        vertices[2] = 0f
        
        // 외곽점
        for (i in 0..CIRCLE_SEGMENTS) {
            val angle = (i.toFloat() / CIRCLE_SEGMENTS) * 2f * Math.PI.toFloat()
            val idx = (i + 1) * 3
            vertices[idx] = x + cos(angle) * radius
            vertices[idx + 1] = y + sin(angle) * radius
            vertices[idx + 2] = 0f
        }
        
        // 버퍼 업데이트
        circleVertexBuffer?.clear()
        circleVertexBuffer?.put(vertices)
        circleVertexBuffer?.position(0)
        
        // 그리기
        GLES20.glEnableVertexAttribArray(positionHandle)
        GLES20.glVertexAttribPointer(positionHandle, 3, GLES20.GL_FLOAT, false, 0, circleVertexBuffer)
        GLES20.glDrawArrays(GLES20.GL_TRIANGLE_FAN, 0, vertexCount)
        GLES20.glDisableVertexAttribArray(positionHandle)
    }
    
    /**
     * 리소스 해제
     */
    fun dispose() {
        if (programId != 0) {
            GLES20.glDeleteProgram(programId)
            programId = 0
        }
        circleVertexBuffer = null
        isInitialized = false
    }
}

package com.example.flutter_application_1.live2d.renderer

import android.content.Context
import android.opengl.GLSurfaceView
import android.util.AttributeSet
import android.view.MotionEvent
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import com.example.flutter_application_1.live2d.core.Live2DLogger

/**
 * Live2D OpenGL Surface View
 * 
 * Live2D 모델을 렌더링하기 위한 GLSurfaceView 구현
 * OpenGL ES 2.0을 사용합니다.
 */
class Live2DGLSurfaceView : GLSurfaceView {
    
    private var renderer: Live2DGLRenderer? = null
    private var touchListener: OnTouchCallback? = null
    
    // 터치 콜백 인터페이스
    interface OnTouchCallback {
        fun onTouch(event: MotionEvent): Boolean
    }
    
    constructor(context: Context) : super(context) {
        init(context)
    }
    
    constructor(context: Context, attrs: AttributeSet?) : super(context, attrs) {
        init(context)
    }
    
    private fun init(context: Context) {
        // OpenGL ES 2.0 사용
        setEGLContextClientVersion(2)
        
        // 배경 투명 설정 (오버레이용)
        setEGLConfigChooser(8, 8, 8, 8, 16, 0) // RGBA8888 + Depth16
        holder.setFormat(android.graphics.PixelFormat.TRANSLUCENT)
        setZOrderOnTop(true)
        
        // 렌더러 생성 및 설정
        renderer = Live2DGLRenderer(context)
        setRenderer(renderer)
        
        // 연속 렌더링 모드 (애니메이션용)
        renderMode = RENDERMODE_CONTINUOUSLY
        
        Live2DLogger.GL.i("GLSurfaceView 초기화됨", "OpenGL ES 2.0")
    }
    
    /**
     * 터치 콜백 설정
     */
    fun setOnTouchCallback(callback: OnTouchCallback) {
        touchListener = callback
    }
    
    override fun onTouchEvent(event: MotionEvent): Boolean {
        // 먼저 외부 콜백에 전달
        val handled = touchListener?.onTouch(event) ?: false
        
        // 렌더러에도 터치 이벤트 전달 (시선 추적용)
        renderer?.let { r ->
            when (event.action) {
                MotionEvent.ACTION_DOWN, MotionEvent.ACTION_MOVE -> {
                    // 화면 좌표를 -1~1 범위로 정규화
                    val normalizedX = (event.x / width) * 2f - 1f
                    val normalizedY = 1f - (event.y / height) * 2f
                    r.onTouch(normalizedX, normalizedY)
                }
                MotionEvent.ACTION_UP -> {
                    r.onTouchEnd()
                }
            }
        }
        
        return handled || super.onTouchEvent(event)
    }
    
    /**
     * 모델 로드
     */
    fun loadModel(modelPath: String, modelName: String): Boolean {
        val r = renderer ?: return false
        val latch = CountDownLatch(1)
        var result = false
        queueEvent {
            try {
                result = r.loadModel(modelPath, modelName)
            } finally {
                latch.countDown()
            }
        }
        // GL 스레드 작업 완료까지 짧게 대기 (최대 2초)
        latch.await(2, TimeUnit.SECONDS)
        return result
    }
    
    /**
     * 모션 재생
     */
    fun playMotion(motionName: String, loop: Boolean = false): Boolean {
        val r = renderer ?: return false
        val latch = CountDownLatch(1)
        var result = false
        queueEvent {
            try {
                result = r.playMotion(motionName, loop)
            } finally {
                latch.countDown()
            }
        }
        latch.await(1, TimeUnit.SECONDS)
        return result
    }
    
    /**
     * 표정 설정
     */
    fun setExpression(expressionName: String): Boolean {
        val r = renderer ?: return false
        val latch = CountDownLatch(1)
        var result = false
        queueEvent {
            try {
                result = r.setExpression(expressionName)
            } finally {
                latch.countDown()
            }
        }
        latch.await(1, TimeUnit.SECONDS)
        return result
    }
    
    /**
     * 스케일 설정
     */
    fun setModelScale(scale: Float) {
        renderer?.let { r ->
            queueEvent { r.setModelScale(scale) }
        }
    }
    
    /**
     * 위치 설정
     */
    fun setModelPosition(x: Float, y: Float) {
        renderer?.let { r ->
            queueEvent { r.setModelPosition(x, y) }
        }
    }
    
    /**
     * 배경색 설정 (디버깅용)
     */
    fun setBackgroundColor(r: Float, g: Float, b: Float, a: Float) {
        renderer?.let { renderer ->
            queueEvent { renderer.setBackgroundColor(r, g, b, a) }
        }
    }
    
    /**
     * 현재 로드된 모델 정보
     */
    fun getModelInfo(): Map<String, Any>? {
        val r = renderer ?: return null
        val latch = CountDownLatch(1)
        var info: Map<String, Any>? = null
        queueEvent {
            try {
                info = r.getModelInfo()
            } finally {
                latch.countDown()
            }
        }
        latch.await(1, TimeUnit.SECONDS)
        return info
    }

    /**
     * 목표 FPS 설정
     */
    fun setTargetFps(fps: Int) {
        renderer?.let { r ->
            queueEvent { r.setTargetFps(fps) }
        }
    }

    /**
     * 저전력 모드 설정
     */
    fun setLowPowerMode(enabled: Boolean) {
        renderer?.let { r ->
            queueEvent { r.setLowPowerMode(enabled) }
        }
    }
    
    /**
     * 리소스 해제
     */
    fun dispose() {
        renderer?.dispose()
        Live2DLogger.GL.i("GLSurfaceView 정리됨", null)
    }
    
    override fun onPause() {
        super.onPause()
        renderer?.onPause()
    }
    
    override fun onResume() {
        super.onResume()
        renderer?.onResume()
    }
}

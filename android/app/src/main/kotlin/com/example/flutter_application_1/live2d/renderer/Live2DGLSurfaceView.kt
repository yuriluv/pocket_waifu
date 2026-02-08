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
        // WHY: depth buffer= 0 — 2D Live2D 렌더링에 depth test 불필요
        setEGLConfigChooser(8, 8, 8, 8, 0, 0) // RGBA8888, no depth/stencil
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
    
    /**
     * 터치 이벤트 차단 — Part 1: 터치 패스스루
     * 
     * GLSurfaceView는 터치를 소비하지 않습니다.
     * Part 2에서 커스텀 히트박스가 터치를 처리합니다.
     * 
     * 내부 시선 추적/제스처 메서드는 보존됩니다 (Part 2에서 히트박스를 통해 호출 예정).
     */
    override fun onTouchEvent(event: MotionEvent): Boolean {
        return false // 터치를 아래 레이어로 패스스루
    }
    
    /**
     * 외부에서 터치 이벤트를 주입 (Part 2: 커스텀 히트박스에서 호출 예정)
     * 
     * GLSurfaceView 자체가 터치를 차단하지 않으므로,
     * 히트박스에서 인식한 터치를 이 메서드로 렌더러에 전달합니다.
     */
    fun deliverTouchToRenderer(event: MotionEvent) {
        // 외부 콜백 전달
        touchListener?.onTouch(event)
        
        // 렌더러에 시선 추적용 터치 전달
        renderer?.let { r ->
            when (event.action) {
                MotionEvent.ACTION_DOWN, MotionEvent.ACTION_MOVE -> {
                    val normalizedX = (event.x / width) * 2f - 1f
                    val normalizedY = 1f - (event.y / height) * 2f
                    r.onTouch(normalizedX, normalizedY)
                }
                MotionEvent.ACTION_UP -> {
                    r.onTouchEnd()
                }
            }
        }
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
     * 모델 투명도 설정 (윈도우 알파와 분리)
     */
    fun setModelOpacity(opacity: Float) {
        renderer?.let { r ->
            queueEvent { r.setModelOpacity(opacity) }
        }
    }
    
    /**
     * 캐릭터 시각적 투명도 설정 (GL 레벨, 윈도우 알파와 독립)
     */
    fun setCharacterOpacity(opacity: Float) {
        renderer?.let { r ->
            queueEvent { r.setCharacterOpacity(opacity) }
        }
    }
    
    /**
     * 캐릭터 상대적 크기 설정 (투명상자 대비)
     */
    fun setRelativeScale(scale: Float) {
        renderer?.let { r ->
            queueEvent { r.setRelativeScale(scale) }
        }
    }
    
    /**
     * 캐릭터 오프셋 설정 (픽셀 단위)
     */
    fun setCharacterOffset(xPixel: Float, yPixel: Float) {
        renderer?.let { r ->
            queueEvent { r.setCharacterOffset(xPixel, yPixel) }
        }
    }
    
    /**
     * 캐릭터 회전 설정 (도)
     */
    fun setCharacterRotation(degrees: Int) {
        renderer?.let { r ->
            queueEvent { r.setCharacterRotation(degrees) }
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

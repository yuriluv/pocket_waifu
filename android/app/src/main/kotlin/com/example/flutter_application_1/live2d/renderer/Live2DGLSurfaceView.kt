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
 */
class Live2DGLSurfaceView : GLSurfaceView {
    
    private var renderer: Live2DGLRenderer? = null
    private var touchListener: OnTouchCallback? = null
    
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
        setEGLContextClientVersion(2)
        
        setEGLConfigChooser(8, 8, 8, 8, 0, 0) // RGBA8888, no depth/stencil
        holder.setFormat(android.graphics.PixelFormat.TRANSLUCENT)
        setZOrderOnTop(true)
        
        renderer = Live2DGLRenderer(context)
        setRenderer(renderer)
        
        renderMode = RENDERMODE_CONTINUOUSLY
        
        Live2DLogger.GL.i("GLSurfaceView 초기화됨", "OpenGL ES 2.0")
    }
    
    /**
     */
    fun setOnTouchCallback(callback: OnTouchCallback) {
        touchListener = callback
    }
    
    /**
     * 
     * 
     */
    override fun onTouchEvent(event: MotionEvent): Boolean {
        return false
    }
    
    /**
     * 
     */
    fun deliverTouchToRenderer(event: MotionEvent) {
        touchListener?.onTouch(event)
        
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
        latch.await(2, TimeUnit.SECONDS)
        return result
    }
    
    /**
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
     */
    fun setModelScale(scale: Float) {
        renderer?.let { r ->
            queueEvent { r.setModelScale(scale) }
        }
    }

    /**
     */
    fun setModelOpacity(opacity: Float) {
        renderer?.let { r ->
            queueEvent { r.setModelOpacity(opacity) }
        }
    }
    
    /**
     */
    fun setCharacterOpacity(opacity: Float) {
        renderer?.let { r ->
            queueEvent { r.setCharacterOpacity(opacity) }
        }
    }
    
    /**
     */
    fun setRelativeScale(scale: Float) {
        renderer?.let { r ->
            queueEvent { r.setRelativeScale(scale) }
        }
    }
    
    /**
     */
    fun setCharacterOffset(xPixel: Float, yPixel: Float) {
        renderer?.let { r ->
            queueEvent { r.setCharacterOffset(xPixel, yPixel) }
        }
    }
    
    /**
     */
    fun setCharacterRotation(degrees: Int) {
        renderer?.let { r ->
            queueEvent { r.setCharacterRotation(degrees) }
        }
    }
    
    /**
     */
    fun setModelPosition(x: Float, y: Float) {
        renderer?.let { r ->
            queueEvent { r.setModelPosition(x, y) }
        }
    }
    
    /**
     */
    fun setBackgroundColor(r: Float, g: Float, b: Float, a: Float) {
        renderer?.let { renderer ->
            queueEvent { renderer.setBackgroundColor(r, g, b, a) }
        }
    }
    
    /**
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
     */
    fun setTargetFps(fps: Int) {
        renderer?.let { r ->
            queueEvent { r.setTargetFps(fps) }
        }
    }

    /**
     */
    fun setLowPowerMode(enabled: Boolean) {
        renderer?.let { r ->
            queueEvent { r.setLowPowerMode(enabled) }
        }
    }

    /**
     */
    fun setParameterValue(paramId: String, value: Float, durationMs: Int) {
        renderer?.let { r ->
            queueEvent { r.setParameterValue(paramId, value, durationMs) }
        }
    }
    
    /**
     */
    fun dispose() {
        val r = renderer
        if (r == null) {
            Live2DLogger.GL.i("GLSurfaceView 정리됨", "renderer already null")
            return
        }

        val latch = CountDownLatch(1)
        try {
            queueEvent {
                try {
                    r.dispose()
                } finally {
                    latch.countDown()
                }
            }
            latch.await(1, TimeUnit.SECONDS)
        } catch (t: Throwable) {
            Live2DLogger.GL.w("GLSurfaceView dispose queueEvent 실패", t.message)
        }

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

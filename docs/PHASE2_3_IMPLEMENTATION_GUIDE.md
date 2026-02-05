# Phase 2-3 구현 가이드: OpenGL 렌더러 & 제스처 시스템

## 1. Live2D Cubism SDK 통합

### 1.1 SDK 다운로드 및 설정

```plaintext
1. Live2D 공식 사이트에서 Cubism SDK for Native 다운로드
   https://www.live2d.com/download/cubism-sdk/

2. 다운로드한 SDK에서 다음 파일들을 프로젝트에 복사:

   SDK 폴더 구조:
   CubismSdkForNative-x.x.x/
   ├── Core/
   │   ├── include/           # 헤더 파일
   │   │   └── Live2DCubismCore.h
   │   └── lib/
   │       └── android/       # 네이티브 라이브러리
   │           ├── arm64-v8a/libLive2DCubismCore.a
   │           ├── armeabi-v7a/libLive2DCubismCore.a
   │           └── x86_64/libLive2DCubismCore.a
   │
   └── Framework/             # Java/Kotlin 프레임워크

3. 프로젝트 경로에 복사:
   android/app/src/main/
   ├── jniLibs/
   │   ├── arm64-v8a/libLive2DCubismCore.so
   │   ├── armeabi-v7a/libLive2DCubismCore.so
   │   └── x86_64/libLive2DCubismCore.so
   │
   └── java/com/live2d/sdk/cubism/
       └── framework/         # Cubism Framework Java 코드
```

### 1.2 대안: OpenGL로 직접 구현 (SDK 없이)

Live2D SDK 라이센스 문제가 있을 경우, 오픈소스 대안 사용:

```plaintext
1. live2d-cubism-core-sys (Rust, 바인딩 참고용)
2. pixi-live2d-display (웹 구현 참고)
3. 직접 moc3 파서 구현 (복잡함)

권장: 공식 SDK 사용 (개인 비상업적 용도 무료)
```

---

## 2. OpenGL ES 렌더러 구현

### 2.1 GLSurfaceView 래퍼

```kotlin
// android/app/src/main/kotlin/.../live2d/overlay/Live2DSurfaceView.kt

package com.example.flutter_application_1.live2d.overlay

import android.content.Context
import android.graphics.PixelFormat
import android.opengl.GLSurfaceView
import android.util.AttributeSet
import android.view.MotionEvent
import com.example.flutter_application_1.live2d.core.Live2DRenderer
import com.example.flutter_application_1.live2d.gesture.GestureDetectorManager

/**
 * Live2D 모델을 렌더링하는 OpenGL Surface View
 */
class Live2DSurfaceView @JvmOverloads constructor(
    context: Context,
    attrs: AttributeSet? = null
) : GLSurfaceView(context, attrs) {

    private val renderer: Live2DRenderer
    private var gestureManager: GestureDetectorManager? = null
    
    // 터치 이벤트 콜백
    var onInteractionEvent: ((InteractionEvent) -> Unit)? = null

    init {
        // OpenGL ES 2.0 사용
        setEGLContextClientVersion(2)
        
        // 투명 배경 설정
        setEGLConfigChooser(8, 8, 8, 8, 16, 0)
        holder.setFormat(PixelFormat.TRANSLUCENT)
        setZOrderOnTop(true)
        
        // 렌더러 설정
        renderer = Live2DRenderer(context)
        setRenderer(renderer)
        
        // 연속 렌더링 모드 (애니메이션용)
        renderMode = RENDERMODE_CONTINUOUSLY
    }

    /**
     * 제스처 매니저 설정
     */
    fun setGestureManager(manager: GestureDetectorManager) {
        gestureManager = manager
        manager.onInteractionEvent = { event ->
            onInteractionEvent?.invoke(event)
        }
    }

    /**
     * 모델 로드
     */
    fun loadModel(modelPath: String) {
        queueEvent {
            renderer.loadModel(modelPath)
        }
    }

    /**
     * 모델 언로드
     */
    fun unloadModel() {
        queueEvent {
            renderer.unloadModel()
        }
    }

    /**
     * 모션 재생
     */
    fun playMotion(group: String, index: Int, priority: Int = 2) {
        queueEvent {
            renderer.playMotion(group, index, priority)
        }
    }

    /**
     * 표정 설정
     */
    fun setExpression(expressionId: String) {
        queueEvent {
            renderer.setExpression(expressionId)
        }
    }

    /**
     * 눈 깜빡임 설정
     */
    fun setEyeBlink(enabled: Boolean) {
        renderer.setEyeBlink(enabled)
    }

    /**
     * 호흡 설정
     */
    fun setBreathing(enabled: Boolean) {
        renderer.setBreathing(enabled)
    }

    /**
     * 시선 추적 설정
     */
    fun setLookAt(enabled: Boolean) {
        renderer.setLookAt(enabled)
    }

    /**
     * 터치 포인트 설정 (시선 추적용)
     */
    fun setTouchPoint(x: Float, y: Float) {
        renderer.setTouchPoint(x, y)
    }

    override fun onTouchEvent(event: MotionEvent): Boolean {
        // 1. 시선 추적용 터치 포인트 업데이트
        if (event.action == MotionEvent.ACTION_MOVE || 
            event.action == MotionEvent.ACTION_DOWN) {
            val normalizedX = event.x / width * 2 - 1  // -1 ~ 1
            val normalizedY = event.y / height * 2 - 1 // -1 ~ 1
            renderer.setTouchPoint(normalizedX, -normalizedY)  // Y축 반전
        }
        
        // 2. 제스처 감지
        gestureManager?.onTouchEvent(event)
        
        return true
    }

    override fun onDetachedFromWindow() {
        super.onDetachedFromWindow()
        queueEvent {
            renderer.release()
        }
    }
}
```

### 2.2 Live2D 렌더러 (핵심)

```kotlin
// android/app/src/main/kotlin/.../live2d/core/Live2DRenderer.kt

package com.example.flutter_application_1.live2d.core

import android.content.Context
import android.opengl.GLES20
import android.opengl.GLSurfaceView
import android.opengl.Matrix
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.nio.FloatBuffer
import javax.microedition.khronos.egl.EGLConfig
import javax.microedition.khronos.opengles.GL10

/**
 * Live2D 모델 OpenGL 렌더러
 * 
 * 이 클래스는 Live2D Cubism SDK를 사용하여 모델을 렌더링합니다.
 * SDK 없이는 moc3 파일 파싱 및 렌더링이 불가능합니다.
 */
class Live2DRenderer(private val context: Context) : GLSurfaceView.Renderer {

    // === 셰이더 프로그램 ===
    private var shaderProgram: Int = 0
    
    // === 행렬 ===
    private val projectionMatrix = FloatArray(16)
    private val viewMatrix = FloatArray(16)
    private val mvpMatrix = FloatArray(16)
    
    // === Live2D 모델 (SDK 연동시 실제 타입으로 교체) ===
    private var model: Live2DModelWrapper? = null
    
    // === 자동 동작 플래그 ===
    private var enableEyeBlink = true
    private var enableBreathing = true
    private var enableLookAt = true
    
    // === 터치 포인트 ===
    private var touchX = 0f
    private var touchY = 0f
    
    // === 시간 ===
    private var lastFrameTime = System.nanoTime()
    
    // === 뷰포트 크기 ===
    private var viewportWidth = 0
    private var viewportHeight = 0

    // ========================================================================
    // GLSurfaceView.Renderer 구현
    // ========================================================================

    override fun onSurfaceCreated(gl: GL10?, config: EGLConfig?) {
        // 투명 배경 설정
        GLES20.glClearColor(0f, 0f, 0f, 0f)
        
        // 블렌딩 활성화 (투명도 지원)
        GLES20.glEnable(GLES20.GL_BLEND)
        GLES20.glBlendFunc(GLES20.GL_SRC_ALPHA, GLES20.GL_ONE_MINUS_SRC_ALPHA)
        
        // 깊이 테스트 비활성화 (2D 렌더링)
        GLES20.glDisable(GLES20.GL_DEPTH_TEST)
        
        // 셰이더 로드
        loadShaders()
        
        // Live2D 초기화
        initializeLive2D()
    }

    override fun onSurfaceChanged(gl: GL10?, width: Int, height: Int) {
        viewportWidth = width
        viewportHeight = height
        
        GLES20.glViewport(0, 0, width, height)
        
        // 투영 행렬 설정 (정규화된 좌표계)
        val ratio = width.toFloat() / height.toFloat()
        Matrix.orthoM(projectionMatrix, 0, -ratio, ratio, -1f, 1f, -1f, 1f)
        
        // 뷰 행렬 설정
        Matrix.setIdentityM(viewMatrix, 0)
    }

    override fun onDrawFrame(gl: GL10?) {
        // 델타 시간 계산
        val currentTime = System.nanoTime()
        val deltaTime = (currentTime - lastFrameTime) / 1_000_000_000f
        lastFrameTime = currentTime
        
        // 화면 클리어
        GLES20.glClear(GLES20.GL_COLOR_BUFFER_BIT)
        
        // 모델 업데이트 및 렌더링
        model?.let { m ->
            // 1. 자동 동작 업데이트
            if (enableEyeBlink) {
                m.updateEyeBlink(deltaTime)
            }
            if (enableBreathing) {
                m.updateBreathing(deltaTime)
            }
            if (enableLookAt) {
                m.updateLookAt(touchX, touchY)
            }
            
            // 2. 모션 업데이트
            m.updateMotion(deltaTime)
            
            // 3. 표정 업데이트
            m.updateExpression(deltaTime)
            
            // 4. 물리 연산
            m.updatePhysics(deltaTime)
            
            // 5. 모델 업데이트 (파라미터 적용)
            m.update()
            
            // 6. MVP 행렬 계산
            Matrix.multiplyMM(mvpMatrix, 0, projectionMatrix, 0, viewMatrix, 0)
            
            // 7. 렌더링
            m.draw(shaderProgram, mvpMatrix)
        }
    }

    // ========================================================================
    // 셰이더 관리
    // ========================================================================

    private fun loadShaders() {
        val vertexShaderCode = """
            attribute vec4 a_Position;
            attribute vec2 a_TexCoord;
            uniform mat4 u_MVPMatrix;
            varying vec2 v_TexCoord;
            
            void main() {
                gl_Position = u_MVPMatrix * a_Position;
                v_TexCoord = a_TexCoord;
            }
        """.trimIndent()

        val fragmentShaderCode = """
            precision mediump float;
            uniform sampler2D u_Texture;
            uniform vec4 u_Color;
            varying vec2 v_TexCoord;
            
            void main() {
                vec4 texColor = texture2D(u_Texture, v_TexCoord);
                gl_FragColor = texColor * u_Color;
            }
        """.trimIndent()

        val vertexShader = compileShader(GLES20.GL_VERTEX_SHADER, vertexShaderCode)
        val fragmentShader = compileShader(GLES20.GL_FRAGMENT_SHADER, fragmentShaderCode)

        shaderProgram = GLES20.glCreateProgram().also {
            GLES20.glAttachShader(it, vertexShader)
            GLES20.glAttachShader(it, fragmentShader)
            GLES20.glLinkProgram(it)
        }
    }

    private fun compileShader(type: Int, shaderCode: String): Int {
        return GLES20.glCreateShader(type).also { shader ->
            GLES20.glShaderSource(shader, shaderCode)
            GLES20.glCompileShader(shader)
            
            // 컴파일 결과 확인
            val compiled = IntArray(1)
            GLES20.glGetShaderiv(shader, GLES20.GL_COMPILE_STATUS, compiled, 0)
            if (compiled[0] == 0) {
                val error = GLES20.glGetShaderInfoLog(shader)
                GLES20.glDeleteShader(shader)
                throw RuntimeException("Shader compilation failed: $error")
            }
        }
    }

    // ========================================================================
    // Live2D 관리
    // ========================================================================

    private fun initializeLive2D() {
        // Live2D Cubism SDK 초기화
        // CubismCore.initialize()
    }

    fun loadModel(modelPath: String) {
        // 기존 모델 해제
        model?.release()
        
        // 새 모델 로드
        model = Live2DModelWrapper.load(context, modelPath)
    }

    fun unloadModel() {
        model?.release()
        model = null
    }

    fun playMotion(group: String, index: Int, priority: Int) {
        model?.startMotion(group, index, priority)
    }

    fun setExpression(expressionId: String) {
        model?.setExpression(expressionId)
    }

    fun setRandomExpression() {
        model?.setRandomExpression()
    }

    // ========================================================================
    // 자동 동작 설정
    // ========================================================================

    fun setEyeBlink(enabled: Boolean) {
        enableEyeBlink = enabled
    }

    fun setBreathing(enabled: Boolean) {
        enableBreathing = enabled
    }

    fun setLookAt(enabled: Boolean) {
        enableLookAt = enabled
    }

    fun setTouchPoint(x: Float, y: Float) {
        touchX = x
        touchY = y
    }

    // ========================================================================
    // 정리
    // ========================================================================

    fun release() {
        model?.release()
        model = null
        
        if (shaderProgram != 0) {
            GLES20.glDeleteProgram(shaderProgram)
            shaderProgram = 0
        }
    }
}
```

### 2.3 Live2D 모델 래퍼

```kotlin
// android/app/src/main/kotlin/.../live2d/core/Live2DModelWrapper.kt

package com.example.flutter_application_1.live2d.core

import android.content.Context
import java.io.File

/**
 * Live2D 모델 래퍼
 * 
 * 실제 Live2D Cubism SDK와 연동되는 클래스입니다.
 * SDK 연동 전에는 스텁으로 동작합니다.
 */
class Live2DModelWrapper private constructor(
    private val modelPath: String
) {
    // === 모델 데이터 (SDK 연동시 실제 타입으로 교체) ===
    // private var cubismModel: CubismModel? = null
    // private var modelMatrix: CubismModelMatrix? = null
    
    // === 매니저 ===
    private var motionManager: MotionManager? = null
    private var expressionManager: ExpressionManager? = null
    private var eyeBlinkManager: EyeBlinkManager? = null
    private var breathManager: BreathManager? = null
    private var physicsManager: PhysicsManager? = null
    
    // === 모델 정보 ===
    val motionGroups: List<String> get() = _motionGroups
    val expressions: List<String> get() = _expressions
    
    private var _motionGroups: List<String> = emptyList()
    private var _expressions: List<String> = emptyList()

    companion object {
        /**
         * 모델 파일 로드
         * @param context Android Context
         * @param modelPath model3.json 파일 경로
         */
        fun load(context: Context, modelPath: String): Live2DModelWrapper? {
            return try {
                val modelFile = File(modelPath)
                if (!modelFile.exists()) {
                    throw IllegalArgumentException("Model file not found: $modelPath")
                }
                
                Live2DModelWrapper(modelPath).apply {
                    loadModelData(context, modelPath)
                }
            } catch (e: Exception) {
                e.printStackTrace()
                null
            }
        }
    }

    private fun loadModelData(context: Context, path: String) {
        // TODO: Live2D SDK를 사용하여 모델 로드
        // 1. model3.json 파싱
        // 2. moc3 파일 로드
        // 3. 텍스처 로드
        // 4. 모션 파일 로드
        // 5. 표정 파일 로드
        // 6. 물리 설정 로드
        
        // 스텁: 로드 성공 로그
        println("[Live2DModelWrapper] Model loaded: $path")
    }

    // ========================================================================
    // 업데이트 메서드
    // ========================================================================

    fun updateEyeBlink(deltaTime: Float) {
        eyeBlinkManager?.update(deltaTime)
    }

    fun updateBreathing(deltaTime: Float) {
        breathManager?.update(deltaTime)
    }

    fun updateLookAt(x: Float, y: Float) {
        // 시선 추적 파라미터 업데이트
        // cubismModel?.setParameterValue("ParamAngleX", x * 30)
        // cubismModel?.setParameterValue("ParamAngleY", y * 30)
        // cubismModel?.setParameterValue("ParamBodyAngleX", x * 10)
    }

    fun updateMotion(deltaTime: Float) {
        motionManager?.update(deltaTime)
    }

    fun updateExpression(deltaTime: Float) {
        expressionManager?.update(deltaTime)
    }

    fun updatePhysics(deltaTime: Float) {
        physicsManager?.update(deltaTime)
    }

    fun update() {
        // 모델 파라미터 최종 업데이트
        // cubismModel?.update()
    }

    // ========================================================================
    // 모션 & 표정
    // ========================================================================

    fun startMotion(group: String, index: Int, priority: Int): Boolean {
        return motionManager?.start(group, index, priority) ?: false
    }

    fun setExpression(expressionId: String): Boolean {
        return expressionManager?.set(expressionId) ?: false
    }

    fun setRandomExpression(): Boolean {
        return expressionManager?.setRandom() ?: false
    }

    fun getMotionCount(group: String): Int {
        return motionManager?.getCount(group) ?: 0
    }

    // ========================================================================
    // 렌더링
    // ========================================================================

    fun draw(shaderProgram: Int, mvpMatrix: FloatArray) {
        // TODO: Live2D SDK를 사용하여 모델 렌더링
        // 1. 드로어블 목록 가져오기
        // 2. 정렬 순서대로 각 드로어블 렌더링
        // 3. 마스크 처리
        // 4. 블렌딩 모드 설정
        
        // 스텁: 렌더링 로그 (디버그용)
        // println("[Live2DModelWrapper] Drawing model")
    }

    // ========================================================================
    // 정리
    // ========================================================================

    fun release() {
        motionManager?.release()
        expressionManager?.release()
        physicsManager?.release()
        
        // cubismModel?.release()
        
        println("[Live2DModelWrapper] Model released")
    }
}

// ========================================================================
// 매니저 클래스들 (스텁)
// ========================================================================

class MotionManager {
    fun update(deltaTime: Float) {}
    fun start(group: String, index: Int, priority: Int): Boolean = true
    fun getCount(group: String): Int = 0
    fun release() {}
}

class ExpressionManager {
    fun update(deltaTime: Float) {}
    fun set(id: String): Boolean = true
    fun setRandom(): Boolean = true
    fun release() {}
}

class EyeBlinkManager {
    fun update(deltaTime: Float) {}
}

class BreathManager {
    fun update(deltaTime: Float) {}
}

class PhysicsManager {
    fun update(deltaTime: Float) {}
    fun release() {}
}
```

---

## 3. 오버레이 서비스 구현

### 3.1 Foreground Service

```kotlin
// android/app/src/main/kotlin/.../live2d/overlay/Live2DOverlayService.kt

package com.example.flutter_application_1.live2d.overlay

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.graphics.PixelFormat
import android.os.Build
import android.os.IBinder
import android.view.Gravity
import android.view.MotionEvent
import android.view.WindowManager
import androidx.core.app.NotificationCompat
import com.example.flutter_application_1.MainActivity
import com.example.flutter_application_1.R
import com.example.flutter_application_1.live2d.gesture.GestureDetectorManager
import com.example.flutter_application_1.live2d.events.EventDispatcher

/**
 * Live2D 오버레이 Foreground Service
 */
class Live2DOverlayService : Service() {

    companion object {
        // 액션 상수
        const val ACTION_SHOW = "com.example.flutter_application_1.live2d.SHOW"
        const val ACTION_HIDE = "com.example.flutter_application_1.live2d.HIDE"
        const val ACTION_LOAD_MODEL = "com.example.flutter_application_1.live2d.LOAD_MODEL"
        const val ACTION_UNLOAD_MODEL = "com.example.flutter_application_1.live2d.UNLOAD_MODEL"
        const val ACTION_PLAY_MOTION = "com.example.flutter_application_1.live2d.PLAY_MOTION"
        const val ACTION_SET_EXPRESSION = "com.example.flutter_application_1.live2d.SET_EXPRESSION"
        const val ACTION_RANDOM_EXPRESSION = "com.example.flutter_application_1.live2d.RANDOM_EXPRESSION"
        const val ACTION_SET_SCALE = "com.example.flutter_application_1.live2d.SET_SCALE"
        const val ACTION_SET_OPACITY = "com.example.flutter_application_1.live2d.SET_OPACITY"
        const val ACTION_SET_POSITION = "com.example.flutter_application_1.live2d.SET_POSITION"
        const val ACTION_SET_SIZE = "com.example.flutter_application_1.live2d.SET_SIZE"
        const val ACTION_SET_EYE_BLINK = "com.example.flutter_application_1.live2d.SET_EYE_BLINK"
        const val ACTION_SET_BREATHING = "com.example.flutter_application_1.live2d.SET_BREATHING"
        const val ACTION_SET_LOOK_AT = "com.example.flutter_application_1.live2d.SET_LOOK_AT"
        const val ACTION_SET_TOUCH_POINT = "com.example.flutter_application_1.live2d.SET_TOUCH_POINT"
        const val ACTION_SEND_SIGNAL = "com.example.flutter_application_1.live2d.SEND_SIGNAL"

        // 알림 채널
        private const val CHANNEL_ID = "live2d_overlay_channel"
        private const val NOTIFICATION_ID = 1001

        // 상태
        var isRunning = false
            private set
    }

    private lateinit var windowManager: WindowManager
    private var overlayView: Live2DSurfaceView? = null
    private var gestureManager: GestureDetectorManager? = null

    // 오버레이 파라미터
    private val overlayParams = WindowManager.LayoutParams().apply {
        type = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        } else {
            @Suppress("DEPRECATION")
            WindowManager.LayoutParams.TYPE_PHONE
        }
        flags = WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
                WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL or
                WindowManager.LayoutParams.FLAG_WATCH_OUTSIDE_TOUCH
        format = PixelFormat.TRANSLUCENT
        gravity = Gravity.TOP or Gravity.START
        width = 300
        height = 400
        x = 0
        y = 100
    }

    // ========================================================================
    // Service 생명주기
    // ========================================================================

    override fun onCreate() {
        super.onCreate()
        windowManager = getSystemService(WINDOW_SERVICE) as WindowManager
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_SHOW -> showOverlay()
            ACTION_HIDE -> hideOverlay()
            ACTION_LOAD_MODEL -> loadModel(intent.getStringExtra("path") ?: "")
            ACTION_UNLOAD_MODEL -> unloadModel()
            ACTION_PLAY_MOTION -> playMotion(
                intent.getStringExtra("group") ?: "",
                intent.getIntExtra("index", 0),
                intent.getIntExtra("priority", 2)
            )
            ACTION_SET_EXPRESSION -> setExpression(intent.getStringExtra("id") ?: "")
            ACTION_RANDOM_EXPRESSION -> setRandomExpression()
            ACTION_SET_SCALE -> setScale(intent.getFloatExtra("scale", 1f))
            ACTION_SET_OPACITY -> setOpacity(intent.getFloatExtra("opacity", 1f))
            ACTION_SET_POSITION -> setPosition(
                intent.getIntExtra("x", 0),
                intent.getIntExtra("y", 0)
            )
            ACTION_SET_SIZE -> setSize(
                intent.getIntExtra("width", 300),
                intent.getIntExtra("height", 400)
            )
            ACTION_SET_EYE_BLINK -> setEyeBlink(intent.getBooleanExtra("enabled", true))
            ACTION_SET_BREATHING -> setBreathing(intent.getBooleanExtra("enabled", true))
            ACTION_SET_LOOK_AT -> setLookAt(intent.getBooleanExtra("enabled", true))
            ACTION_SET_TOUCH_POINT -> setTouchPoint(
                intent.getFloatExtra("x", 0f),
                intent.getFloatExtra("y", 0f)
            )
            ACTION_SEND_SIGNAL -> handleSignal(intent.getStringExtra("signal") ?: "")
        }
        return START_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        hideOverlay()
        super.onDestroy()
    }

    // ========================================================================
    // 오버레이 관리
    // ========================================================================

    private fun showOverlay() {
        if (overlayView != null) return

        // Foreground Service 시작
        startForeground(NOTIFICATION_ID, createNotification())

        // 제스처 매니저 생성
        gestureManager = GestureDetectorManager(this) { event ->
            // Flutter로 이벤트 전송
            EventDispatcher.sendEvent(event)
        }

        // 오버레이 뷰 생성
        overlayView = Live2DSurfaceView(this).apply {
            setGestureManager(gestureManager!!)
            onInteractionEvent = { event ->
                EventDispatcher.sendEvent(event)
            }
        }

        // 드래그 처리를 위한 터치 리스너
        setupDragListener()

        // 윈도우에 추가
        windowManager.addView(overlayView, overlayParams)

        isRunning = true
        EventDispatcher.sendSystemEvent("overlayShown")
    }

    private fun hideOverlay() {
        overlayView?.let { view ->
            view.unloadModel()
            windowManager.removeView(view)
        }
        overlayView = null
        gestureManager = null
        isRunning = false

        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()

        EventDispatcher.sendSystemEvent("overlayHidden")
    }

    private fun setupDragListener() {
        var initialX = 0
        var initialY = 0
        var initialTouchX = 0f
        var initialTouchY = 0f
        var isDragging = false

        overlayView?.setOnTouchListener { _, event ->
            when (event.action) {
                MotionEvent.ACTION_DOWN -> {
                    initialX = overlayParams.x
                    initialY = overlayParams.y
                    initialTouchX = event.rawX
                    initialTouchY = event.rawY
                    isDragging = false
                }
                MotionEvent.ACTION_MOVE -> {
                    val dx = event.rawX - initialTouchX
                    val dy = event.rawY - initialTouchY
                    
                    // 임계값 이상 이동시 드래그로 판정
                    if (Math.abs(dx) > 10 || Math.abs(dy) > 10) {
                        isDragging = true
                        overlayParams.x = (initialX + dx).toInt()
                        overlayParams.y = (initialY + dy).toInt()
                        windowManager.updateViewLayout(overlayView, overlayParams)
                    }
                }
                MotionEvent.ACTION_UP -> {
                    // 드래그가 아닌 경우에만 제스처 처리
                    if (!isDragging) {
                        gestureManager?.onTouchEvent(event)
                    }
                }
            }
            true
        }
    }

    // ========================================================================
    // 모델 제어
    // ========================================================================

    private fun loadModel(path: String) {
        overlayView?.loadModel(path)
        EventDispatcher.sendSystemEvent("modelLoaded", mapOf("path" to path))
    }

    private fun unloadModel() {
        overlayView?.unloadModel()
        EventDispatcher.sendSystemEvent("modelUnloaded")
    }

    private fun playMotion(group: String, index: Int, priority: Int) {
        overlayView?.playMotion(group, index, priority)
    }

    private fun setExpression(id: String) {
        overlayView?.setExpression(id)
    }

    private fun setRandomExpression() {
        // TODO: 구현
    }

    // ========================================================================
    // 디스플레이 설정
    // ========================================================================

    private fun setScale(scale: Float) {
        // 기본 크기에 스케일 적용
        val baseWidth = 300
        val baseHeight = 400
        overlayParams.width = (baseWidth * scale).toInt()
        overlayParams.height = (baseHeight * scale).toInt()
        overlayView?.let {
            windowManager.updateViewLayout(it, overlayParams)
        }
    }

    private fun setOpacity(opacity: Float) {
        overlayParams.alpha = opacity
        overlayView?.let {
            windowManager.updateViewLayout(it, overlayParams)
        }
    }

    private fun setPosition(x: Int, y: Int) {
        overlayParams.x = x
        overlayParams.y = y
        overlayView?.let {
            windowManager.updateViewLayout(it, overlayParams)
        }
    }

    private fun setSize(width: Int, height: Int) {
        overlayParams.width = width
        overlayParams.height = height
        overlayView?.let {
            windowManager.updateViewLayout(it, overlayParams)
        }
    }

    // ========================================================================
    // 자동 동작 설정
    // ========================================================================

    private fun setEyeBlink(enabled: Boolean) {
        overlayView?.setEyeBlink(enabled)
    }

    private fun setBreathing(enabled: Boolean) {
        overlayView?.setBreathing(enabled)
    }

    private fun setLookAt(enabled: Boolean) {
        overlayView?.setLookAt(enabled)
    }

    private fun setTouchPoint(x: Float, y: Float) {
        overlayView?.setTouchPoint(x, y)
    }

    // ========================================================================
    // 신호 처리
    // ========================================================================

    private fun handleSignal(signal: String) {
        when (signal) {
            "happy" -> {
                setExpression("happy")
                playMotion("happy", 0, 3)
            }
            "sad" -> {
                setExpression("sad")
                playMotion("sad", 0, 3)
            }
            "startSpeaking" -> {
                playMotion("talk", 0, 2)
            }
            "stopSpeaking" -> {
                // idle 모션으로 복귀
                playMotion("idle", 0, 1)
            }
            // 추가 신호 처리
        }
    }

    // ========================================================================
    // 알림
    // ========================================================================

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Live2D 오버레이",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Live2D 오버레이 서비스 실행 중"
                setShowBadge(false)
            }
            
            val notificationManager = getSystemService(NotificationManager::class.java)
            notificationManager.createNotificationChannel(channel)
        }
    }

    private fun createNotification(): Notification {
        val intent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK
        }
        val pendingIntent = PendingIntent.getActivity(
            this, 0, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Live2D 오버레이")
            .setContentText("오버레이가 실행 중입니다")
            .setSmallIcon(R.drawable.ic_notification)  // 적절한 아이콘 필요
            .setContentIntent(pendingIntent)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setOngoing(true)
            .build()
    }
}
```

---

## 4. 제스처 인식 시스템

### 4.1 제스처 매니저

```kotlin
// android/app/src/main/kotlin/.../live2d/gesture/GestureDetectorManager.kt

package com.example.flutter_application_1.live2d.gesture

import android.content.Context
import android.graphics.PointF
import android.view.GestureDetector
import android.view.MotionEvent
import com.example.flutter_application_1.live2d.events.InteractionEvent

/**
 * 제스처 감지 매니저
 */
class GestureDetectorManager(
    context: Context,
    private val onGestureDetected: (InteractionEvent) -> Unit
) {
    // 제스처 감지기
    private val gestureDetector: GestureDetector
    
    // 드래그 패턴 인식기
    private val dragRecognizer = DragPatternRecognizer()
    
    // 터치 포인트 기록
    private val touchPoints = mutableListOf<PointF>()
    private var touchStartTime = 0L
    
    // 콜백 (외부에서 설정)
    var onInteractionEvent: ((InteractionEvent) -> Unit)? = null

    init {
        gestureDetector = GestureDetector(context, object : GestureDetector.SimpleOnGestureListener() {
            override fun onSingleTapConfirmed(e: MotionEvent): Boolean {
                sendEvent(InteractionEvent.tap(e.x, e.y))
                return true
            }

            override fun onDoubleTap(e: MotionEvent): Boolean {
                sendEvent(InteractionEvent.doubleTap(e.x, e.y))
                return true
            }

            override fun onLongPress(e: MotionEvent) {
                sendEvent(InteractionEvent.longPress(e.x, e.y))
            }

            override fun onFling(
                e1: MotionEvent?,
                e2: MotionEvent,
                velocityX: Float,
                velocityY: Float
            ): Boolean {
                if (e1 == null) return false
                
                val dx = e2.x - e1.x
                val dy = e2.y - e1.y
                
                val swipeType = when {
                    Math.abs(dx) > Math.abs(dy) -> {
                        if (dx > 0) "swipeRight" else "swipeLeft"
                    }
                    else -> {
                        if (dy > 0) "swipeDown" else "swipeUp"
                    }
                }
                
                sendEvent(InteractionEvent(swipeType, e2.x, e2.y))
                return true
            }
        })
    }

    fun onTouchEvent(event: MotionEvent): Boolean {
        // 1. 기본 제스처 감지
        gestureDetector.onTouchEvent(event)
        
        // 2. 드래그 패턴 추적
        when (event.action) {
            MotionEvent.ACTION_DOWN -> {
                touchPoints.clear()
                touchStartTime = System.currentTimeMillis()
                touchPoints.add(PointF(event.x, event.y))
                dragRecognizer.clear()
                dragRecognizer.addPoint(event.x, event.y)
            }
            MotionEvent.ACTION_MOVE -> {
                touchPoints.add(PointF(event.x, event.y))
                dragRecognizer.addPoint(event.x, event.y)
            }
            MotionEvent.ACTION_UP -> {
                // 드래그 패턴 분석
                if (touchPoints.size > 10) {  // 충분한 포인트가 있을 때만
                    val pattern = dragRecognizer.analyzePattern()
                    if (pattern != DragPattern.UNKNOWN) {
                        sendEvent(InteractionEvent(
                            pattern.eventName,
                            event.x,
                            event.y,
                            mapOf("pattern" to pattern.name)
                        ))
                    }
                }
            }
        }
        
        return true
    }

    private fun sendEvent(event: InteractionEvent) {
        onGestureDetected(event)
        onInteractionEvent?.invoke(event)
    }
}
```

### 4.2 드래그 패턴 인식기

```kotlin
// android/app/src/main/kotlin/.../live2d/gesture/DragPatternRecognizer.kt

package com.example.flutter_application_1.live2d.gesture

import android.graphics.PointF
import kotlin.math.abs
import kotlin.math.atan2
import kotlin.math.sqrt

/**
 * 드래그 패턴 열거형
 */
enum class DragPattern(val eventName: String) {
    SWIPE_UP("swipeUp"),
    SWIPE_DOWN("swipeDown"),
    SWIPE_LEFT("swipeLeft"),
    SWIPE_RIGHT("swipeRight"),
    CIRCLE_CW("circleCW"),
    CIRCLE_CCW("circleCCW"),
    HEAD_PAT("headPat"),       // 머리 쓰다듬기 (좌우 반복)
    ZIGZAG("zigzag"),          // 지그재그
    UNKNOWN("unknown")
}

/**
 * 드래그 패턴 인식기
 */
class DragPatternRecognizer {
    
    private val points = mutableListOf<PointF>()
    
    // 인식 임계값
    private val minPointsForPattern = 10
    private val headPatMinDirectionChanges = 3
    private val circleAngleThreshold = 300f  // 도
    private val circleClosenessThreshold = 50f  // 시작점-끝점 거리
    
    fun clear() {
        points.clear()
    }
    
    fun addPoint(x: Float, y: Float) {
        points.add(PointF(x, y))
    }
    
    fun analyzePattern(): DragPattern {
        if (points.size < minPointsForPattern) return DragPattern.UNKNOWN
        
        // 패턴 우선순위에 따라 체크
        return when {
            isHeadPat() -> DragPattern.HEAD_PAT
            isCircle() -> detectCircleDirection()
            isZigzag() -> DragPattern.ZIGZAG
            else -> DragPattern.UNKNOWN
        }
    }
    
    /**
     * 머리 쓰다듬기 패턴 (좌우 반복 움직임)
     */
    private fun isHeadPat(): Boolean {
        var directionChanges = 0
        var lastDirection = 0
        
        for (i in 1 until points.size) {
            val dx = points[i].x - points[i-1].x
            if (abs(dx) < 5) continue  // 너무 작은 이동은 무시
            
            val currentDirection = if (dx > 0) 1 else -1
            
            if (currentDirection != lastDirection && lastDirection != 0) {
                directionChanges++
            }
            lastDirection = currentDirection
        }
        
        // Y축 이동이 적고 방향 전환이 많으면 머리 쓰다듬기
        val totalYMovement = abs(points.last().y - points.first().y)
        val totalXMovement = abs(points.last().x - points.first().x)
        
        return directionChanges >= headPatMinDirectionChanges && 
               totalYMovement < 100 && 
               totalXMovement < 200
    }
    
    /**
     * 원형 패턴 감지
     */
    private fun isCircle(): Boolean {
        if (points.size < 20) return false
        
        // 시작점과 끝점 거리
        val startEnd = distance(points.first(), points.last())
        if (startEnd > circleClosenessThreshold) return false
        
        // 총 회전 각도 계산
        val totalAngle = calculateTotalRotation()
        return abs(totalAngle) > circleAngleThreshold
    }
    
    /**
     * 원 방향 감지 (시계/반시계)
     */
    private fun detectCircleDirection(): DragPattern {
        val totalAngle = calculateTotalRotation()
        return if (totalAngle > 0) DragPattern.CIRCLE_CW else DragPattern.CIRCLE_CCW
    }
    
    /**
     * 지그재그 패턴 감지
     */
    private fun isZigzag(): Boolean {
        var zigzagCount = 0
        var lastVerticalDirection = 0
        
        for (i in 1 until points.size) {
            val dy = points[i].y - points[i-1].y
            if (abs(dy) < 10) continue
            
            val currentDirection = if (dy > 0) 1 else -1
            
            // 방향이 바뀌고, 수평 이동도 있으면 지그재그
            if (currentDirection != lastVerticalDirection && lastVerticalDirection != 0) {
                val dx = points[i].x - points[i-1].x
                if (abs(dx) > 20) {
                    zigzagCount++
                }
            }
            lastVerticalDirection = currentDirection
        }
        
        return zigzagCount >= 2
    }
    
    /**
     * 총 회전 각도 계산
     */
    private fun calculateTotalRotation(): Float {
        if (points.size < 3) return 0f
        
        var totalAngle = 0f
        val center = calculateCenter()
        
        for (i in 1 until points.size) {
            val angle1 = atan2(
                points[i-1].y - center.y,
                points[i-1].x - center.x
            )
            val angle2 = atan2(
                points[i].y - center.y,
                points[i].x - center.x
            )
            
            var diff = Math.toDegrees((angle2 - angle1).toDouble()).toFloat()
            
            // -180 ~ 180 범위로 정규화
            while (diff > 180) diff -= 360
            while (diff < -180) diff += 360
            
            totalAngle += diff
        }
        
        return totalAngle
    }
    
    /**
     * 중심점 계산
     */
    private fun calculateCenter(): PointF {
        var sumX = 0f
        var sumY = 0f
        for (point in points) {
            sumX += point.x
            sumY += point.y
        }
        return PointF(sumX / points.size, sumY / points.size)
    }
    
    /**
     * 두 점 사이 거리
     */
    private fun distance(p1: PointF, p2: PointF): Float {
        val dx = p2.x - p1.x
        val dy = p2.y - p1.y
        return sqrt(dx * dx + dy * dy)
    }
}
```

### 4.3 이벤트 클래스 및 디스패처

```kotlin
// android/app/src/main/kotlin/.../live2d/events/InteractionEvent.kt

package com.example.flutter_application_1.live2d.events

/**
 * 상호작용 이벤트
 */
data class InteractionEvent(
    val type: String,
    val x: Float? = null,
    val y: Float? = null,
    val extras: Map<String, Any?>? = null,
    val timestamp: Long = System.currentTimeMillis()
) {
    companion object {
        fun tap(x: Float, y: Float) = InteractionEvent("tap", x, y)
        fun doubleTap(x: Float, y: Float) = InteractionEvent("doubleTap", x, y)
        fun longPress(x: Float, y: Float) = InteractionEvent("longPress", x, y)
        fun system(type: String, extras: Map<String, Any?>? = null) = 
            InteractionEvent(type, extras = extras)
    }
    
    fun toMap(): Map<String, Any?> = mapOf(
        "type" to type,
        "x" to x,
        "y" to y,
        "extras" to extras,
        "timestamp" to timestamp
    )
}
```

```kotlin
// android/app/src/main/kotlin/.../live2d/events/EventDispatcher.kt

package com.example.flutter_application_1.live2d.events

import com.example.flutter_application_1.live2d.Live2DEventStreamHandler

/**
 * 이벤트 디스패처 (싱글톤)
 */
object EventDispatcher {
    
    private var streamHandler: Live2DEventStreamHandler? = null
    
    fun setStreamHandler(handler: Live2DEventStreamHandler) {
        streamHandler = handler
    }
    
    fun sendEvent(event: InteractionEvent) {
        streamHandler?.sendEvent(event.toMap())
    }
    
    fun sendSystemEvent(type: String, extras: Map<String, Any?>? = null) {
        sendEvent(InteractionEvent.system(type, extras))
    }
}
```

---

## 5. 다음 단계 (Phase 4)

Phase 2-3 완료 후:
1. Flutter 측 상호작용 관리자 구현
2. 앱의 다른 기능과 Live2D 연동
3. 제스처 설정 화면 구현
4. 모델 브라우저 개선

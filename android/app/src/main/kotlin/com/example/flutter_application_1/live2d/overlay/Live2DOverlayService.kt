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
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.provider.Settings
import android.view.Gravity
import android.view.MotionEvent
import android.view.View
import android.view.WindowManager
import androidx.core.app.NotificationCompat
import com.example.flutter_application_1.MainActivity
import com.example.flutter_application_1.R
import com.example.flutter_application_1.live2d.Live2DEventStreamHandler
import com.example.flutter_application_1.live2d.core.Live2DLogger
import com.example.flutter_application_1.live2d.gesture.GestureConfig
import com.example.flutter_application_1.live2d.gesture.GestureDetectorManager
import com.example.flutter_application_1.live2d.gesture.GestureType
import com.example.flutter_application_1.live2d.renderer.Live2DGLSurfaceView

/**
 * Live2D 오버레이 Foreground Service
 * 
 * 다른 앱 위에 Live2D 모델을 표시하는 서비스입니다.
 * 현재는 기본 틀만 구현하고, 실제 OpenGL 렌더링은 Phase 2에서 구현합니다.
 */
class Live2DOverlayService : Service() {
    
    companion object {
        private const val TAG = "Live2DOverlayService"
        
        // ========== 액션 상수 ==========
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
        const val ACTION_SEND_SIGNAL = "com.example.flutter_application_1.live2d.SEND_SIGNAL"
        const val ACTION_SET_TARGET_FPS = "com.example.flutter_application_1.live2d.SET_TARGET_FPS"
        const val ACTION_SET_LOW_POWER_MODE = "com.example.flutter_application_1.live2d.SET_LOW_POWER_MODE"
        
        // ========== Extra 키 상수 ==========
        const val EXTRA_MODEL_PATH = "model_path"
        const val EXTRA_MOTION_GROUP = "motion_group"
        const val EXTRA_MOTION_INDEX = "motion_index"
        const val EXTRA_MOTION_PRIORITY = "motion_priority"
        const val EXTRA_EXPRESSION_ID = "expression_id"
        const val EXTRA_SCALE = "scale"
        const val EXTRA_OPACITY = "opacity"
        const val EXTRA_POSITION_X = "position_x"
        const val EXTRA_POSITION_Y = "position_y"
        const val EXTRA_WIDTH = "width"
        const val EXTRA_HEIGHT = "height"
        const val EXTRA_ENABLED = "enabled"
        const val EXTRA_SIGNAL_NAME = "signal_name"
        const val EXTRA_TARGET_FPS = "target_fps"
        
        // ========== 알림 ==========
        private const val CHANNEL_ID = "live2d_overlay_channel"
        private const val NOTIFICATION_ID = 1001
        
        // ========== 기본 크기 ==========
        private const val DEFAULT_WIDTH = 300
        private const val DEFAULT_HEIGHT = 400
        
        // ========== 상태 체크 간격 (ms) ==========
        private const val STATE_CHECK_INTERVAL_MS = 30_000L   // 30초 상태 브로드캐스트
        private const val PERMISSION_CHECK_INTERVAL_MS = 60_000L  // 60초 권한 체크
        
        // ========== 상태 ==========
        // WHY isRunning is in companion object:
        // The service can be stopped and restarted by Android at any time.
        // Companion object survives service recreation within the same process.
        // This allows Flutter to query state even if service instance changed.
        // CAVEAT: Does not survive process death - Flutter should verify via isOverlayVisible() call.
        @Volatile
        var isRunning = false
            private set
        
        // 서비스 시작 시간 (디버그/메트릭용)
        @Volatile
        var serviceStartTime: Long = 0L
            private set
            
        // ========== 현재 모델 정보 (외부 접근용) ==========
        @Volatile
        var currentModelInfo: Map<String, Any>? = null
            private set
    }
    
    private lateinit var windowManager: WindowManager
    private var overlayView: View? = null
    private var glSurfaceView: Live2DGLSurfaceView? = null
    
    // 제스처 감지 관리자
    private var gestureDetector: GestureDetectorManager? = null
    
    // 현재 모델 정보
    private var currentModelPath: String? = null
    
    // 현재 설정
    private var currentScale = 1f
    private var currentOpacity = 1f
    private var currentWidth = DEFAULT_WIDTH
    private var currentHeight = DEFAULT_HEIGHT
    
    // ========== 상태 체크 Handler ==========
    private val stateCheckHandler = Handler(Looper.getMainLooper())
    
    // 상태 브로드캐스트 (30초마다)
    private val stateCheckRunnable = object : Runnable {
        override fun run() {
            if (isRunning) {
                broadcastState()
                stateCheckHandler.postDelayed(this, STATE_CHECK_INTERVAL_MS)
            }
        }
    }
    
    // 권한 체크 (60초마다)
    private val permissionCheckRunnable = object : Runnable {
        override fun run() {
            if (!checkAndRecoverPermission()) return
            stateCheckHandler.postDelayed(this, PERMISSION_CHECK_INTERVAL_MS)
        }
    }
    
    // 오버레이 파라미터
    private val overlayParams: WindowManager.LayoutParams by lazy {
        WindowManager.LayoutParams().apply {
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
            width = currentWidth
            height = currentHeight
            x = 0
            y = 100
        }
    }
    
    // ============================================================================
    // Service 생명주기
    // ============================================================================
    
    override fun onCreate() {
        android.util.Log.d("Live2D", ">>> SERVICE onCreate START")
        super.onCreate()
        Live2DLogger.Overlay.i("서비스 생성", "Live2DOverlayService 초기화")
        
        try {
            windowManager = getSystemService(WINDOW_SERVICE) as WindowManager
            
            // CRITICAL: Create notification channel FIRST
            createNotificationChannel()
            android.util.Log.d("Live2D", ">>> Notification channel created")
            
            // CRITICAL: Start foreground IMMEDIATELY in onCreate
            // Android 12+ kills the app if startForeground() is not called within ~10 seconds
            val notification = createNotification()
            android.util.Log.d("Live2D", ">>> Notification created")
            
            startForeground(NOTIFICATION_ID, notification)
            android.util.Log.d("Live2D", ">>> startForeground called successfully")
        } catch (e: Exception) {
            android.util.Log.e("Live2D", ">>> SERVICE onCreate ERROR: ${e.message}", e)
            Live2DLogger.Overlay.e("서비스 생성 실패", e.message, e)
        }
        
        android.util.Log.d("Live2D", ">>> SERVICE onCreate END")
    }
    
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        android.util.Log.d("Live2D", ">>> SERVICE onStartCommand: action=${intent?.action}")
        Live2DLogger.Overlay.d("onStartCommand", "action=${intent?.action}")
        
        when (intent?.action) {
            ACTION_SHOW -> showOverlay()
            ACTION_HIDE -> hideOverlay()
            ACTION_LOAD_MODEL -> loadModel(intent.getStringExtra(EXTRA_MODEL_PATH) ?: "")
            ACTION_UNLOAD_MODEL -> unloadModel()
            ACTION_PLAY_MOTION -> playMotion(
                intent.getStringExtra(EXTRA_MOTION_GROUP) ?: "",
                intent.getIntExtra(EXTRA_MOTION_INDEX, 0),
                intent.getIntExtra(EXTRA_MOTION_PRIORITY, 2)
            )
            ACTION_SET_EXPRESSION -> setExpression(intent.getStringExtra(EXTRA_EXPRESSION_ID) ?: "")
            ACTION_RANDOM_EXPRESSION -> setRandomExpression()
            ACTION_SET_SCALE -> setScale(intent.getFloatExtra(EXTRA_SCALE, 1f))
            ACTION_SET_OPACITY -> setOpacity(intent.getFloatExtra(EXTRA_OPACITY, 1f))
            ACTION_SET_POSITION -> setPosition(
                intent.getIntExtra(EXTRA_POSITION_X, 0),
                intent.getIntExtra(EXTRA_POSITION_Y, 0)
            )
            ACTION_SET_SIZE -> setSize(
                intent.getIntExtra(EXTRA_WIDTH, DEFAULT_WIDTH),
                intent.getIntExtra(EXTRA_HEIGHT, DEFAULT_HEIGHT)
            )
            ACTION_SET_EYE_BLINK -> setEyeBlink(intent.getBooleanExtra(EXTRA_ENABLED, true))
            ACTION_SET_BREATHING -> setBreathing(intent.getBooleanExtra(EXTRA_ENABLED, true))
            ACTION_SET_LOOK_AT -> setLookAt(intent.getBooleanExtra(EXTRA_ENABLED, true))
            ACTION_SEND_SIGNAL -> handleSignal(intent.getStringExtra(EXTRA_SIGNAL_NAME) ?: "")
            ACTION_SET_TARGET_FPS -> setTargetFps(intent.getIntExtra(EXTRA_TARGET_FPS, 60))
            ACTION_SET_LOW_POWER_MODE -> setLowPowerMode(intent.getBooleanExtra(EXTRA_ENABLED, false))
        }
        
        return START_STICKY
    }
    
    override fun onBind(intent: Intent?): IBinder? = null
    
    override fun onDestroy() {
        android.util.Log.d("Live2D", ">>> SERVICE onDestroy")
        Live2DLogger.Overlay.i("서비스 종료", "Live2DOverlayService 정리")
        hideOverlay()
        super.onDestroy()
    }
    
    override fun onTaskRemoved(rootIntent: Intent?) {
        android.util.Log.d("Live2D", ">>> SERVICE onTaskRemoved")
        Live2DLogger.Overlay.w("태스크 제거됨", "onTaskRemoved 호출")
        super.onTaskRemoved(rootIntent)
    }
    
    override fun onLowMemory() {
        android.util.Log.d("Live2D", ">>> SERVICE onLowMemory")
        Live2DLogger.Overlay.w("메모리 부족", "onLowMemory 호출")
        super.onLowMemory()
    }
    
    override fun onTrimMemory(level: Int) {
        android.util.Log.d("Live2D", ">>> SERVICE onTrimMemory level=$level")
        Live2DLogger.Overlay.w("메모리 트림", "level=$level")
        super.onTrimMemory(level)
    }
    
    // ============================================================================
    // 오버레이 관리
    // ============================================================================
    
    private fun showOverlay() {
        if (overlayView != null) {
            Live2DLogger.Overlay.w("오버레이 표시 스킵", "이미 표시되어 있음")
            return
        }
        
        // 권한 확인
        if (!checkAndRecoverPermission()) {
            Live2DLogger.Overlay.e("오버레이 표시 실패", "권한 없음")
            return
        }
        
        Live2DLogger.Overlay.i("오버레이 표시 시작", "GLSurfaceView 생성")
        
        // Note: startForeground() is already called in onCreate()
        // No need to call it again here
        Live2DLogger.Overlay.d("Foreground Service 이미 시작됨", "notificationId=$NOTIFICATION_ID")
        
        // GLSurfaceView 생성 (Live2D 렌더링용)
        glSurfaceView = Live2DGLSurfaceView(this)
        overlayView = glSurfaceView
        Live2DLogger.Overlay.d("GLSurfaceView 생성됨", "크기: ${currentWidth}x${currentHeight}")
        
        // 배경 투명 설정
        glSurfaceView?.setBackgroundColor(0f, 0f, 0f, 0f)
        
        // 드래그 처리 설정
        setupDragListener()
        
        // 윈도우에 추가
        try {
            windowManager.addView(overlayView, overlayParams)
            isRunning = true
            
            // 상태 체크 시작
            startStateChecks()
            
            // Flutter로 이벤트 전송
            Live2DEventStreamHandler.getInstance()?.sendOverlayShown()
            
            Live2DLogger.Overlay.i("오버레이 표시 완료", "위치: (${overlayParams.x}, ${overlayParams.y}), 크기: ${overlayParams.width}x${overlayParams.height}")
        } catch (e: Exception) {
            Live2DLogger.Overlay.e("오버레이 표시 실패", "WindowManager.addView 예외", e)
            overlayView = null
        }
    }
    
    private fun hideOverlay() {
        // 상태 체크 중지 (먼저 중지하여 정리 중 브로드캐스트 방지)
        stopStateChecks()
        
        overlayView?.let { view ->
            Live2DLogger.Overlay.i("오버레이 숨김 시작", "리소스 정리")
            
            // 제스처 감지기 정리
            gestureDetector?.dispose()
            gestureDetector = null
            
            // GLSurfaceView 정리
            glSurfaceView?.let { gl ->
                Live2DLogger.Overlay.d("GLSurfaceView 정리", "onPause, dispose 호출")
                gl.onPause()
                gl.dispose()
            }
            
            try {
                windowManager.removeView(view)
                Live2DLogger.Overlay.d("WindowManager에서 뷰 제거됨", null)
            } catch (e: Exception) {
                Live2DLogger.Overlay.e("오버레이 제거 실패", "WindowManager.removeView 예외", e)
            }
        }
        
        overlayView = null
        glSurfaceView = null
        isRunning = false
        
        // Flutter로 이벤트 전송
        Live2DEventStreamHandler.getInstance()?.sendOverlayHidden()
        Live2DLogger.Overlay.i("오버레이 숨김 완료", "서비스 중지")
        
        // 서비스 중지
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
    }
    
    /**
     * 제스처 감지 및 드래그 처리 설정
     */
    private fun setupDragListener() {
        // 제스처 감지기 생성
        gestureDetector = GestureDetectorManager(
            config = GestureConfig(
                enableSwipe = true,
                enableHeadPat = true,
                enablePoke = true
            )
        ) { gestureResult ->
            // 제스처 감지 시 Flutter로 전송
            Live2DEventStreamHandler.getInstance()?.sendGestureResult(gestureResult.toMap())
            
            // 드래그 관련이 아닌 제스처는 내부 처리도 수행
            handleGesture(gestureResult.type)
        }
        
        var initialX = 0
        var initialY = 0
        var initialTouchX = 0f
        var initialTouchY = 0f
        var isDragging = false
        var hasMoved = false
        
        overlayView?.setOnTouchListener { _, event ->
            // 제스처 감지기에 이벤트 전달
            gestureDetector?.onTouchEvent(event)
            
            when (event.action) {
                MotionEvent.ACTION_DOWN -> {
                    initialX = overlayParams.x
                    initialY = overlayParams.y
                    initialTouchX = event.rawX
                    initialTouchY = event.rawY
                    isDragging = false
                    hasMoved = false
                    true
                }
                MotionEvent.ACTION_MOVE -> {
                    val dx = event.rawX - initialTouchX
                    val dy = event.rawY - initialTouchY
                    
                    // 임계값 이상 이동시 드래그로 판정
                    if (Math.abs(dx) > 10 || Math.abs(dy) > 10) {
                        isDragging = true
                        hasMoved = true
                        overlayParams.x = (initialX + dx).toInt()
                        overlayParams.y = (initialY + dy).toInt()
                        windowManager.updateViewLayout(overlayView, overlayParams)
                    }
                    true
                }
                MotionEvent.ACTION_UP -> {
                    // 드래그 종료 처리 (제스처 감지는 GestureDetectorManager가 담당)
                    isDragging = false
                    true
                }
                else -> false
            }
        }
    }
    
    /**
     * 내부 제스처 처리 (모델 반응)
     */
    private fun handleGesture(gestureType: GestureType) {
        when (gestureType) {
            GestureType.TAP -> {
                // 탭 반응 - 탭 모션 시도
                glSurfaceView?.playMotion("tap", false)
            }
            GestureType.DOUBLE_TAP -> {
                // 더블탭 반응 - 랜덤 표정
                setRandomExpression()
            }
            GestureType.LONG_PRESS -> {
                // 롱프레스 반응 - 특별 모션
                glSurfaceView?.playMotion("special", false)
            }
            GestureType.HEAD_PAT -> {
                // 머리 쓰다듬기 반응 - 기쁨 표정 + 모션
                glSurfaceView?.setExpression("happy")
                glSurfaceView?.playMotion("happy", false)
            }
            GestureType.POKE -> {
                // 연타 반응 - 놀람 표정
                glSurfaceView?.setExpression("surprised")
            }
            GestureType.SWIPE_UP -> {
                // 위로 스와이프 - 인사 모션
                glSurfaceView?.playMotion("greet", false)
            }
            GestureType.SWIPE_DOWN -> {
                // 아래로 스와이프 - 숙이기 모션
                glSurfaceView?.playMotion("bow", false)
            }
            else -> {
                // 다른 제스처는 무시
            }
        }
    }
    
    // ============================================================================
    // 모델 제어
    // ============================================================================
    
    private fun loadModel(path: String) {
        Live2DLogger.Model.i("모델 로드 요청", path)
        
        val modelName = path.substringAfterLast("/").substringBeforeLast(".")
        
        glSurfaceView?.let { gl ->
            if (gl.loadModel(path, modelName)) {
                currentModelPath = path
                
                // 모델 정보 캐싱 (외부 접근용)
                currentModelInfo = gl.getModelInfo()
                
                Live2DEventStreamHandler.getInstance()?.sendModelLoaded(path)
                Live2DLogger.Model.i("모델 로드 성공", modelName)
            } else {
                Live2DLogger.Model.e("모델 로드 실패", path)
                Live2DEventStreamHandler.getInstance()?.sendError("MODEL_LOAD_FAILED", "Failed to load model: $path")
            }
        } ?: run {
            Live2DLogger.Overlay.e("GLSurfaceView 미초기화", "모델을 로드할 수 없음")
        }
    }
    
    private fun unloadModel() {
        Live2DLogger.Model.d("모델 언로드 요청", null)
        currentModelPath = null
        currentModelInfo = null
        // 모델 언로드는 새 모델 로드 시 자동으로 처리됨
        Live2DEventStreamHandler.getInstance()?.sendModelUnloaded()
    }
    
    private fun playMotion(group: String, index: Int, priority: Int) {
        Live2DLogger.Model.d("모션 재생 요청", "$group[$index], priority=$priority")
        
        glSurfaceView?.let { gl ->
            val motionName = if (index > 0) "${group}_$index" else group
            val loop = (priority <= 1) // 낮은 우선순위는 반복
            gl.playMotion(motionName, loop)
        }
    }
    
    private fun setExpression(id: String) {
        Live2DLogger.Model.d("표정 설정 요청", id)
        
        glSurfaceView?.setExpression(id)
    }
    
    private fun setRandomExpression() {
        Live2DLogger.Model.d("랜덤 표정 요청", null)
        
        // 모델 정보에서 표정 목록 가져와서 랜덤 선택
        glSurfaceView?.getModelInfo()?.let { info ->
            @Suppress("UNCHECKED_CAST")
            val expressions = info["expressions"] as? List<String>
            if (!expressions.isNullOrEmpty()) {
                val randomExpression = expressions.random()
                setExpression(randomExpression)
            }
        }
    }
    
    // ============================================================================
    // 디스플레이 설정
    // ============================================================================
    
    private fun setScale(scale: Float) {
        Live2DLogger.Overlay.d("스케일 설정", "$scale")
        currentScale = scale
        
        // GLSurfaceView 내 모델 스케일 설정
        glSurfaceView?.setModelScale(scale)
        
        // 기본 크기에 스케일 적용 (윈도우 크기)
        overlayParams.width = (DEFAULT_WIDTH * scale).toInt()
        overlayParams.height = (DEFAULT_HEIGHT * scale).toInt()
        
        overlayView?.let {
            windowManager.updateViewLayout(it, overlayParams)
        }
    }
    
    private fun setOpacity(opacity: Float) {
        Live2DLogger.Overlay.d("투명도 설정", "$opacity")
        currentOpacity = opacity
        overlayParams.alpha = opacity
        
        overlayView?.let {
            windowManager.updateViewLayout(it, overlayParams)
        }
    }
    
    private fun setPosition(x: Int, y: Int) {
        Live2DLogger.Overlay.d("위치 설정", "($x, $y)")
        overlayParams.x = x
        overlayParams.y = y
        
        overlayView?.let {
            windowManager.updateViewLayout(it, overlayParams)
        }
    }
    
    private fun setSize(width: Int, height: Int) {
        Live2DLogger.Overlay.d("크기 설정", "${width}x$height")
        currentWidth = width
        currentHeight = height
        overlayParams.width = width
        overlayParams.height = height
        
        overlayView?.let {
            windowManager.updateViewLayout(it, overlayParams)
        }
    }
    
    // ============================================================================
    // 자동 동작 설정
    // ============================================================================
    
    private var isEyeBlinkEnabled = true
    private var isBreathingEnabled = true
    private var isLookAtEnabled = true
    
    private fun setEyeBlink(enabled: Boolean) {
        Live2DLogger.Model.d("눈 깜빡임 설정", "$enabled")
        isEyeBlinkEnabled = enabled
        // TODO: Live2D 모델에 눈 깜빡임 파라미터 설정
    }
    
    private fun setBreathing(enabled: Boolean) {
        Live2DLogger.Model.d("호흡 설정", "$enabled")
        isBreathingEnabled = enabled
        // TODO: Live2D 모델에 호흡 파라미터 설정
    }
    
    private fun setLookAt(enabled: Boolean) {
        Live2DLogger.Model.d("시선 추적 설정", "$enabled")
        isLookAtEnabled = enabled
        // TODO: Live2D 모델에 시선 추적 설정
    }
    
    // ============================================================================
    // 렌더링 설정
    // ============================================================================
    
    private fun setTargetFps(fps: Int) {
        Live2DLogger.Renderer.d("FPS 설정", "$fps")
        glSurfaceView?.setTargetFps(fps)
    }
    
    private fun setLowPowerMode(enabled: Boolean) {
        Live2DLogger.Renderer.d("저전력 모드 설정", "$enabled")
        glSurfaceView?.setLowPowerMode(enabled)
    }
    
    // ============================================================================
    // 신호 처리 (추후 확장)
    // ============================================================================
    
    private fun handleSignal(signal: String) {
        Live2DLogger.d("신호 수신", signal)
        
        // 기본 신호 처리 (추후 확장)
        when (signal) {
            "happy" -> {
                // setExpression("happy")
            }
            "sad" -> {
                // setExpression("sad")
            }
            "startSpeaking" -> {
                // playMotion("talk", 0, 2)
            }
            "stopSpeaking" -> {
                // playMotion("idle", 0, 1)
            }
            else -> {
                Live2DLogger.w("알 수 없는 신호", signal)
            }
        }
    }
    
    // ============================================================================
    // 상태 관리 및 방어적 복구
    // ============================================================================
    
    /**
     * 권한 확인 및 복구
     * 
     * WHY: 사용자가 실행 중 권한을 취소하면 서비스가 좀비 상태가 됩니다.
     * 이 메서드는 권한이 취소되었는지 확인하고, 취소된 경우 graceful하게 종료합니다.
     * 
     * @return true if permission OK, false if revoked (service will stop)
     */
    private fun checkAndRecoverPermission(): Boolean {
        if (!Settings.canDrawOverlays(this)) {
            Live2DLogger.Overlay.w("권한 취소 감지", "오버레이 권한이 취소됨 - 서비스 종료")
            hideOverlay()
            return false
        }
        return true
    }
    
    /**
     * 현재 상태를 Flutter로 브로드캐스트
     * 
     * WHY: Flutter측 상태와 Native측 상태가 불일치할 수 있습니다 (프로세스 재시작 등).
     * 주기적으로 상태를 브로드캐스트하여 Flutter가 동기화할 수 있게 합니다.
     */
    private fun broadcastState() {
        try {
            val hasModel = glSurfaceView?.getModelInfo() != null
            val uptimeMs = if (serviceStartTime > 0) System.currentTimeMillis() - serviceStartTime else 0
            
            Live2DEventStreamHandler.getInstance()?.sendEvent(
                mapOf(
                    "type" to "stateSync",
                    "isRunning" to isRunning,
                    "modelLoaded" to hasModel,
                    "uptimeMs" to uptimeMs,
                    "modelPath" to currentModelPath
                )
            )
            
            Live2DLogger.Overlay.d("상태 브로드캐스트", "running=$isRunning, model=$hasModel, uptime=${uptimeMs/1000}s")
        } catch (e: Exception) {
            Live2DLogger.Overlay.w("상태 브로드캐스트 실패", e.message)
        }
    }
    
    /**
     * 상태 체크 핸들러 시작
     */
    private fun startStateChecks() {
        serviceStartTime = System.currentTimeMillis()
        
        // 첫 상태 브로드캐스트 (즉시)
        broadcastState()
        
        // 주기적 상태 체크 시작
        stateCheckHandler.postDelayed(stateCheckRunnable, STATE_CHECK_INTERVAL_MS)
        stateCheckHandler.postDelayed(permissionCheckRunnable, PERMISSION_CHECK_INTERVAL_MS)
        
        Live2DLogger.Overlay.d("상태 체크 시작", "state=${STATE_CHECK_INTERVAL_MS}ms, perm=${PERMISSION_CHECK_INTERVAL_MS}ms")
    }
    
    /**
     * 상태 체크 핸들러 중지
     */
    private fun stopStateChecks() {
        stateCheckHandler.removeCallbacks(stateCheckRunnable)
        stateCheckHandler.removeCallbacks(permissionCheckRunnable)
        serviceStartTime = 0
        Live2DLogger.Overlay.d("상태 체크 중지", null)
    }
    
    // ============================================================================
    // 알림
    // ============================================================================
    
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
            notificationManager?.createNotificationChannel(channel)
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
            .setSmallIcon(android.R.drawable.ic_dialog_info)  // 기본 아이콘 사용
            .setContentIntent(pendingIntent)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .setOngoing(true)
            .build()
    }
}

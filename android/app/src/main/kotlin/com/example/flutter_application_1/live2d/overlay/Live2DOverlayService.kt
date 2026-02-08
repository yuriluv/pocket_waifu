package com.example.flutter_application_1.live2d.overlay

import android.app.Activity
import android.app.Application
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.graphics.PixelFormat
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.provider.Settings
import android.view.Gravity
import android.view.MotionEvent
import android.view.View
import android.view.ViewGroup
import android.view.WindowManager
import android.widget.FrameLayout
import androidx.core.app.NotificationCompat
import com.example.flutter_application_1.MainActivity
import com.example.flutter_application_1.R
import com.example.flutter_application_1.live2d.Live2DEventStreamHandler
import com.example.flutter_application_1.live2d.core.Live2DLogger
import com.example.flutter_application_1.live2d.cubism.CubismFrameworkManager
import com.example.flutter_application_1.live2d.cubism.CubismTextureManager
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
        const val ACTION_SET_TOUCH_THROUGH = "com.example.flutter_application_1.live2d.SET_TOUCH_THROUGH"
        const val ACTION_SET_TOUCH_THROUGH_ALPHA = "com.example.flutter_application_1.live2d.SET_TOUCH_THROUGH_ALPHA"
        const val ACTION_SET_CHARACTER_OPACITY = "com.example.flutter_application_1.live2d.SET_CHARACTER_OPACITY"
        const val ACTION_SET_EDIT_MODE = "com.example.flutter_application_1.live2d.SET_EDIT_MODE"
        const val ACTION_SET_CHARACTER_PINNED = "com.example.flutter_application_1.live2d.SET_CHARACTER_PINNED"
        const val ACTION_SET_RELATIVE_SCALE = "com.example.flutter_application_1.live2d.SET_RELATIVE_SCALE"
        const val ACTION_SET_CHARACTER_OFFSET = "com.example.flutter_application_1.live2d.SET_CHARACTER_OFFSET"
        const val ACTION_SET_CHARACTER_ROTATION = "com.example.flutter_application_1.live2d.SET_CHARACTER_ROTATION"

        // ========== 편집 모드 리사이즈 상수 ==========
        const val EDGE_LEFT = 1
        const val EDGE_TOP = 2
        const val EDGE_RIGHT = 4
        const val EDGE_BOTTOM = 8
        const val HANDLE_SIZE = 50f  // 리사이즈 핸들 터치 영역 (px)
        const val MIN_BOX_SIZE = 100  // 최소 상자 크기 (px)
        
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
        const val EXTRA_TOUCH_THROUGH = "touch_through"
        const val EXTRA_TOUCH_THROUGH_ALPHA = "touch_through_alpha"
        const val EXTRA_CHARACTER_OPACITY = "character_opacity"
        const val EXTRA_EDIT_MODE = "edit_mode"
        const val EXTRA_CHARACTER_PINNED = "character_pinned"
        const val EXTRA_RELATIVE_SCALE = "relative_scale"
        const val EXTRA_OFFSET_X = "offset_x"
        const val EXTRA_OFFSET_Y = "offset_y"
        const val EXTRA_ROTATION = "rotation"
        
        // ========== 알림 ==========
        private const val CHANNEL_ID = "live2d_overlay_channel"
        private const val NOTIFICATION_ID = 1001
        
        // ========== 터치 패스스루 상수 ==========
        // Android 12+ (API 31) Untrusted Touch Occlusion:
        // TYPE_APPLICATION_OVERLAY에서 alpha > 0.8이면 아래 앱 터치가 차단됩니다.
        // 0.8f = Android의 MAX_OBSCURING_OPACITY 임계값
        private val MAX_OVERLAY_ALPHA = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) 0.8f else 1.0f
        
        // ========== 기본 크기 ==========
        private const val DEFAULT_WIDTH = 300
        private const val DEFAULT_HEIGHT = 400
        
        // ========== 동적 사이징 상수 (Part 1) ==========
        // 모델 크기 대비 GLSurfaceView 패딩 비율 (애니메이션 클리핑 방지)
        const val PADDING_MULTIPLIER = 1.5f
        // 화면 대비 최소/최대 비율
        const val MIN_SIZE_RATIO = 0.3f
        const val MAX_SIZE_RATIO = 2.0f
        // 모델 바운딩 박스를 가져올 수 없을 때 화면 대비 기본 비율 (50%)
        const val DEFAULT_MODEL_SIZE_RATIO = 0.5f
        
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
    private var overlayContainer: FrameLayout? = null  // 편집 모드 테두리용 컨테이너
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
    
    // ========== 터치스루 토글 시스템 ==========
    private var touchThroughEnabled = true
    private var touchThroughAlpha = 0.8f    // 0.0~1.0 (MAX_OVERLAY_ALPHA로 제한)
    private var characterOpacity = 1.0f     // GL 레벨 캐릭터 투명도
    @Volatile private var isAppForeground = false
    
    // ========== 편집 모드 ==========
    private var editModeEnabled = false
    private var characterPinned = false
    private var boxSelected = false
    private var pinnedCharScreenX = 0  // 고정된 캐릭터 화면 중심 X
    private var pinnedCharScreenY = 0  // 고정된 캐릭터 화면 중심 Y
    private var relativeCharacterScale = 1.0f
    private var characterOffsetPixelX = 0f  // 캐릭터-상자 상대 오프셋
    private var characterOffsetPixelY = 0f
    private var characterRotationDeg = 0
    
    // 터치 상태 추적
    private enum class TouchState { IDLE, DRAGGING, BOX_DRAGGING, BOX_RESIZING }
    private var touchState = TouchState.IDLE
    private var resizeEdgeMask = 0  // bitmask: 1=LEFT, 2=TOP, 4=RIGHT, 8=BOTTOM

    
    // 앱 전경/배경 감지 콜백
    private val lifecycleCallbacks = object : Application.ActivityLifecycleCallbacks {
        override fun onActivityCreated(activity: Activity, savedInstanceState: Bundle?) {}
        override fun onActivityStarted(activity: Activity) {}
        override fun onActivityResumed(activity: Activity) {
            if (activity is MainActivity) {
                isAppForeground = true
                updateTouchMode()
            }
        }
        override fun onActivityPaused(activity: Activity) {
            if (activity is MainActivity) {
                isAppForeground = false
                updateTouchMode()
            }
        }
        override fun onActivityStopped(activity: Activity) {}
        override fun onActivitySaveInstanceState(activity: Activity, outState: Bundle) {}
        override fun onActivityDestroyed(activity: Activity) {}
    }

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
            // WHY: 터치 패스스루를 위해 3개 플래그 모두 필요.
            // FLAG_LAYOUT_NO_LIMITS: LAYOUT_IN_SCREEN 대신 사용하여
            // 시스템 바 영역에서의 의도치 않은 터치 간섭을 방지합니다.
            flags = WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                    WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE or
                    WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL or
                    WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS
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
            
            // 앱 전경/배경 감지 등록
            application.registerActivityLifecycleCallbacks(lifecycleCallbacks)
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
            ACTION_SET_TOUCH_THROUGH -> setTouchThroughEnabled(intent.getBooleanExtra(EXTRA_TOUCH_THROUGH, true))
            ACTION_SET_TOUCH_THROUGH_ALPHA -> setTouchThroughAlphaValue(intent.getIntExtra(EXTRA_TOUCH_THROUGH_ALPHA, 80))
            ACTION_SET_CHARACTER_OPACITY -> setCharacterOpacity(intent.getFloatExtra(EXTRA_CHARACTER_OPACITY, 1f))
            ACTION_SET_EDIT_MODE -> setEditModeEnabled(intent.getBooleanExtra(EXTRA_EDIT_MODE, false))
            ACTION_SET_CHARACTER_PINNED -> setCharacterPinnedMode(intent.getBooleanExtra(EXTRA_CHARACTER_PINNED, false))
            ACTION_SET_RELATIVE_SCALE -> setRelativeScaleValue(intent.getFloatExtra(EXTRA_RELATIVE_SCALE, 1f))
            ACTION_SET_CHARACTER_OFFSET -> setCharacterOffsetValue(
                intent.getFloatExtra(EXTRA_OFFSET_X, 0f),
                intent.getFloatExtra(EXTRA_OFFSET_Y, 0f)
            )
            ACTION_SET_CHARACTER_ROTATION -> setCharacterRotationValue(intent.getIntExtra(EXTRA_ROTATION, 0))
        }
        
        return START_STICKY
    }
    
    override fun onBind(intent: Intent?): IBinder? = null
    
    override fun onDestroy() {
        android.util.Log.d("Live2D", ">>> SERVICE onDestroy")
        Live2DLogger.Overlay.i("서비스 종료", "Live2DOverlayService 정리")
        try {
            application.unregisterActivityLifecycleCallbacks(lifecycleCallbacks)
        } catch (_: Exception) {}
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
        
        // FrameLayout 컨테이너로 감싸기 (편집 모드 파란색 테두리용)
        overlayContainer = FrameLayout(this).apply {
            addView(glSurfaceView, FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT
            ))
        }
        overlayView = overlayContainer
        Live2DLogger.Overlay.d("GLSurfaceView 생성됨", "크기: ${currentWidth}x${currentHeight}")
        
        // 배경 투명 설정 (GL clear color)
        glSurfaceView?.setBackgroundColor(0f, 0f, 0f, 0f)
        
        // GLSurfaceView 터치 패스스루 추가 보장
        // WHY: WindowManager 플래그 외에도 View 자체의 터치/포커스 속성을
        // 비활성화하여 Android InputDispatcher가 이 View를 완전히 무시하도록 합니다.
        glSurfaceView?.apply {
            isClickable = false
            isFocusable = false
            isFocusableInTouchMode = false
        }
        
        // 윈도우 알파: 항상 1.0 유지
        // FLAG_NOT_TOUCHABLE만으로 터치 패스스루 가능 (Android 12+ 포함)
        // 시각적 투명도는 GL 레벨에서 완전히 제어
        overlayParams.alpha = 1.0f
        
        // 동적 사이징 적용 (모델 바운딩 박스 기반)
        applyDynamicSizing(currentScale)
        
        // 터치 모드: 앱 상태에 따라 터치스루/드래그 자동 전환
        Live2DLogger.Overlay.d("터치스루 초기화", "enabled=$touchThroughEnabled, foreground=$isAppForeground")
        
        // 윈도우에 추가
        try {
            windowManager.addView(overlayView, overlayParams)
            isRunning = true
            
            // 터치스루 모드 적용 (앱 상태에 따라 자동 전환)
            updateTouchMode()
            
            // 편집 모드 테두리 적용
            updateEditModeBorder()
            
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
            
            // 1. 제스처 감지기 정리 (입력 차단)
            gestureDetector?.dispose()
            gestureDetector = null
            
            // 2. GLSurfaceView 정리 (렌더링 중지 → 리소스 해제)
            glSurfaceView?.let { gl ->
                Live2DLogger.Overlay.d("GLSurfaceView 정리", "onPause, dispose 호출")
                gl.onPause()
                gl.dispose()
            }
            
            // 3. WindowManager에서 뷰 제거
            try {
                windowManager.removeView(view)
                Live2DLogger.Overlay.d("WindowManager에서 뷰 제거됨", null)
            } catch (e: Exception) {
                Live2DLogger.Overlay.e("오버레이 제거 실패", "WindowManager.removeView 예외", e)
            }
        }
        
        overlayView = null
        overlayContainer = null
        glSurfaceView = null
        isRunning = false

        // 4. 텍스처 캐시 무효화 (GL context가 파괴되었으므로)
        try {
            CubismTextureManager.invalidateGlobalCache()
        } catch (e: Exception) {
            Live2DLogger.Overlay.w("텍스처 캐시 무효화 실패", e.message)
        }

        // 5. CubismFramework 정리 (셰이더 캐시 무효화)
        // GL context가 새로 생성되면 재초기화됩니다.
        try {
            CubismFrameworkManager.dispose()
            Live2DLogger.Overlay.d("CubismFramework 정리완료", null)
        } catch (e: Exception) {
            Live2DLogger.Overlay.e("CubismFramework dispose 실패", null, e)
        }
        
        // 6. Flutter로 이벤트 전송
        Live2DEventStreamHandler.getInstance()?.sendOverlayHidden()
        Live2DLogger.Overlay.i("오버레이 숨김 완료", "서비스 중지")
        
        // 7. 서비스 중지
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
    }
    
    /**
     * 제스처 감지 및 드래그 처리 설정
     * 편집 모드 + 캐릭터 고정 시: 상자 이동/리사이즈
     * 일반 모드: 전체 윈도우 드래그
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
            Live2DEventStreamHandler.getInstance()?.sendGestureResult(gestureResult.toMap())
            handleGesture(gestureResult.type)
        }
        
        var initialX = 0
        var initialY = 0
        var initialTouchX = 0f
        var initialTouchY = 0f
        var initialWidth = 0
        var initialHeight = 0
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
                    initialWidth = overlayParams.width
                    initialHeight = overlayParams.height
                    hasMoved = false
                    
                    if (editModeEnabled && characterPinned) {
                        if (boxSelected) {
                            // 선택 상태: 코너/엣지 감지
                            resizeEdgeMask = detectResizeEdge(event.x, event.y, initialWidth, initialHeight)
                            touchState = if (resizeEdgeMask != 0) TouchState.BOX_RESIZING else TouchState.BOX_DRAGGING
                        } else {
                            touchState = TouchState.BOX_DRAGGING
                        }
                    } else {
                        touchState = TouchState.DRAGGING
                    }
                    true
                }
                MotionEvent.ACTION_MOVE -> {
                    val dx = event.rawX - initialTouchX
                    val dy = event.rawY - initialTouchY
                    
                    if (Math.abs(dx) > 10 || Math.abs(dy) > 10) {
                        hasMoved = true
                        
                        when (touchState) {
                            TouchState.DRAGGING -> {
                                // 일반 드래그: 윈도우 이동
                                overlayParams.x = (initialX + dx).toInt()
                                overlayParams.y = (initialY + dy).toInt()
                                windowManager.updateViewLayout(overlayView, overlayParams)
                            }
                            TouchState.BOX_DRAGGING -> {
                                // 상자 드래그: 윈도우 이동 + 캐릭터 오프셋 업데이트
                                overlayParams.x = (initialX + dx).toInt()
                                overlayParams.y = (initialY + dy).toInt()
                                windowManager.updateViewLayout(overlayView, overlayParams)
                                updateCharacterOffsetFromPinned()
                            }
                            TouchState.BOX_RESIZING -> {
                                handleResize(dx, dy, initialX, initialY, initialWidth, initialHeight)
                            }
                            TouchState.IDLE -> {}
                        }
                    }
                    true
                }
                MotionEvent.ACTION_UP -> {
                    if (!hasMoved && editModeEnabled && characterPinned) {
                        // 이동 없는 탭: 선택 상태 토글
                        boxSelected = !boxSelected
                        updateEditModeBorder()
                    }
                    touchState = TouchState.IDLE
                    true
                }
                MotionEvent.ACTION_OUTSIDE -> {
                    // 외부 터치: 선택 해제
                    if (boxSelected) {
                        boxSelected = false
                        updateEditModeBorder()
                    }
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
        
        // 동적 사이징으로 윈도우 크기 업데이트
        updateSurfaceSizeForScale(scale)
    }
    
    private fun setOpacity(opacity: Float) {
        // 레거시 호환: setOpacity는 이제 캐릭터 GL 투명도를 제어합니다.
        // 윈도우 알파(터치스루)는 setTouchThroughAlphaValue()로 별도 제어
        setCharacterOpacity(opacity)
    }
    
    // ============================================================================
    // 터치스루 토글 시스템
    // ============================================================================
    
    /**
     * 터치스루 모드 활성화/비활성화
     * ON: 앱 외부에서 터치 패스스루, 앱 내부에서 드래그 가능
     * OFF: 향후 편집 모드용 예약
     */
    private fun setTouchThroughEnabled(enabled: Boolean) {
        Live2DLogger.Overlay.d("터치스루 토글", "enabled=$enabled")
        touchThroughEnabled = enabled
        updateTouchMode()
    }
    
    /**
     * 터치스루 투명도 설정 (0~100 정수)
     * 앱 배경 시 캐릭터 GL 투명도로 적용 (윈도우 알파와 무관)
     */
    private fun setTouchThroughAlphaValue(alpha: Int) {
        val normalizedAlpha = (alpha / 100f).coerceIn(0f, 1.0f)
        Live2DLogger.Overlay.d("터치스루 알파", "input=$alpha, applied=$normalizedAlpha")
        touchThroughAlpha = normalizedAlpha
        
        // 터치스루 ON + 앱 배경일 때만 GL 투명도 즉시 업데이트
        if (touchThroughEnabled && !isAppForeground) {
            glSurfaceView?.setCharacterOpacity(touchThroughAlpha)
        }
    }
    
    /**
     * 캐릭터 시각적 투명도 (GL 레벨)
     * 터치스루 ON + 앱 배경에서는 touchThroughAlpha가 우선되므로 즉시 적용하지 않음
     */
    private fun setCharacterOpacity(opacity: Float) {
        Live2DLogger.Overlay.d("캐릭터 투명도", "opacity=$opacity")
        characterOpacity = opacity.coerceIn(0f, 1f)
        // 터치스루 ON + 앱 배경이 아닐 때만 즉시 적용
        if (!(touchThroughEnabled && !isAppForeground)) {
            glSurfaceView?.setCharacterOpacity(characterOpacity)
        }
    }
    
    /**
     * 편집 모드 활성화/비활성화
     */
    private fun setEditModeEnabled(enabled: Boolean) {
        Live2DLogger.Overlay.d("편집 모드", "enabled=$enabled")
        editModeEnabled = enabled
        if (!enabled) {
            characterPinned = false
            boxSelected = false
        }
        updateEditModeBorder()
        // 편집 모드 시 드래그 리스너 재설정
        if (overlayView != null) setupDragListener()
    }
    
    /**
     * 캐릭터 고정 모드 on/off
     * ON: 현재 캐릭터 화면 위치 저장, 투명상자만 이동 가능
     * OFF: 현재 상대적 오프셋 저장
     */
    private fun setCharacterPinnedMode(enabled: Boolean) {
        Live2DLogger.Overlay.d("캐릭터 고정", "enabled=$enabled")
        if (enabled && !characterPinned) {
            // 고정: 현재 화면 위치 기록
            pinnedCharScreenX = overlayParams.x + currentWidth / 2
            pinnedCharScreenY = overlayParams.y + currentHeight / 2
        }
        characterPinned = enabled
        boxSelected = false
        updateEditModeBorder()
        // 드래그 리스너 재설정
        if (overlayView != null) setupDragListener()
    }
    
    /**
     * 캐릭터 상대적 크기 설정
     */
    private fun setRelativeScaleValue(scale: Float) {
        Live2DLogger.Overlay.d("상대 스케일", "scale=$scale")
        relativeCharacterScale = scale.coerceIn(0.1f, 3.0f)
        glSurfaceView?.setRelativeScale(relativeCharacterScale)
    }
    
    /**
     * 캐릭터 오프셋 설정 (픽셀)
     */
    private fun setCharacterOffsetValue(x: Float, y: Float) {
        Live2DLogger.Overlay.d("캐릭터 오프셋", "($x, $y)")
        characterOffsetPixelX = x
        characterOffsetPixelY = y
        glSurfaceView?.setCharacterOffset(x, y)
    }
    
    /**
     * 캐릭터 회전 설정 (도)
     */
    private fun setCharacterRotationValue(degrees: Int) {
        Live2DLogger.Overlay.d("캐릭터 회전", "$degrees°")
        characterRotationDeg = degrees % 360
        glSurfaceView?.setCharacterRotation(characterRotationDeg)
    }
    
    /**
     * 고정 모드에서 상자 이동 시 캐릭터 오프셋 업데이트
     */
    private fun updateCharacterOffsetFromPinned() {
        val boxCenterX = overlayParams.x + currentWidth / 2
        val boxCenterY = overlayParams.y + currentHeight / 2
        characterOffsetPixelX = (pinnedCharScreenX - boxCenterX).toFloat()
        characterOffsetPixelY = (pinnedCharScreenY - boxCenterY).toFloat()
        glSurfaceView?.setCharacterOffset(characterOffsetPixelX, characterOffsetPixelY)
    }
    
    /**
     * 리사이즈 엣지 감지
     * @return bitmask (EDGE_LEFT | EDGE_TOP | EDGE_RIGHT | EDGE_BOTTOM)
     */
    private fun detectResizeEdge(touchX: Float, touchY: Float, width: Int, height: Int): Int {
        var mask = 0
        if (touchX < HANDLE_SIZE) mask = mask or EDGE_LEFT
        if (touchX > width - HANDLE_SIZE) mask = mask or EDGE_RIGHT
        if (touchY < HANDLE_SIZE) mask = mask or EDGE_TOP
        if (touchY > height - HANDLE_SIZE) mask = mask or EDGE_BOTTOM
        return mask
    }
    
    /**
     * 리사이즈 처리
     */
    private fun handleResize(
        dx: Float, dy: Float,
        initialX: Int, initialY: Int,
        initialWidth: Int, initialHeight: Int
    ) {
        var newX = initialX
        var newY = initialY
        var newWidth = initialWidth
        var newHeight = initialHeight
        
        if (resizeEdgeMask and EDGE_LEFT != 0) {
            newX = (initialX + dx).toInt()
            newWidth = (initialWidth - dx).toInt()
        }
        if (resizeEdgeMask and EDGE_RIGHT != 0) {
            newWidth = (initialWidth + dx).toInt()
        }
        if (resizeEdgeMask and EDGE_TOP != 0) {
            newY = (initialY + dy).toInt()
            newHeight = (initialHeight - dy).toInt()
        }
        if (resizeEdgeMask and EDGE_BOTTOM != 0) {
            newHeight = (initialHeight + dy).toInt()
        }
        
        // 최소 크기 제한
        if (newWidth < MIN_BOX_SIZE) {
            if (resizeEdgeMask and EDGE_LEFT != 0) newX = initialX + initialWidth - MIN_BOX_SIZE
            newWidth = MIN_BOX_SIZE
        }
        if (newHeight < MIN_BOX_SIZE) {
            if (resizeEdgeMask and EDGE_TOP != 0) newY = initialY + initialHeight - MIN_BOX_SIZE
            newHeight = MIN_BOX_SIZE
        }
        
        overlayParams.x = newX
        overlayParams.y = newY
        overlayParams.width = newWidth
        overlayParams.height = newHeight
        currentWidth = newWidth
        currentHeight = newHeight
        
        overlayView?.let {
            try {
                windowManager.updateViewLayout(it, overlayParams)
            } catch (e: Exception) {
                Live2DLogger.Overlay.w("리사이즈 레이아웃 실패", e.message)
            }
        }
        
        // 고정 모드면 오프셋 업데이트
        if (characterPinned) {
            updateCharacterOffsetFromPinned()
        }
    }
    
    /**
     * 편집 모드 테두리 + 리사이즈 핸들 표시/숨김
     */
    private fun updateEditModeBorder() {
        overlayContainer?.let { container ->
            if (editModeEnabled) {
                val strokeWidth = if (boxSelected) 6 else 4
                val borderDrawable = android.graphics.drawable.GradientDrawable().apply {
                    setColor(android.graphics.Color.TRANSPARENT)
                    setStroke(strokeWidth, android.graphics.Color.parseColor("#2196F3"))
                    cornerRadius = 8f
                }
                container.foreground = borderDrawable
                
                // 선택 상태에서 FLAG_WATCH_OUTSIDE_TOUCH 추가 (외부 터치 감지)
                if (boxSelected) {
                    overlayParams.flags = overlayParams.flags or
                            WindowManager.LayoutParams.FLAG_WATCH_OUTSIDE_TOUCH
                } else {
                    overlayParams.flags = overlayParams.flags and
                            WindowManager.LayoutParams.FLAG_WATCH_OUTSIDE_TOUCH.inv()
                }
                overlayView?.let {
                    try {
                        windowManager.updateViewLayout(it, overlayParams)
                    } catch (_: Exception) {}
                }
            } else {
                container.foreground = null
            }
        }
    }
    
    /**
     * 앱 상태에 따라 터치 모드를 자동 전환
     * - 터치스루 ON + 앱 배경: FLAG_NOT_TOUCHABLE, GL 투명도 = touchThroughAlpha
     * - 터치스루 ON + 앱 전경: 드래그 가능, GL 투명도 = characterOpacity
     * - 터치스루 OFF: 항상 터치 수신, GL 투명도 = characterOpacity
     * 
     * 윈도우 알파는 항상 1.0 유지 (투명도는 GL 레벨에서만 제어)
     */
    private fun updateTouchMode() {
        if (overlayView == null) return
        
        // 윈도우 알파 항상 1.0 (FLAG_NOT_TOUCHABLE만으로 터치 패스스루 충분)
        overlayParams.alpha = 1.0f
        
        if (touchThroughEnabled) {
            if (isAppForeground) {
                // 앱 전경: 드래그 가능, 캐릭터 투명도 = 표시 설정값
                applyTouchReceiving()
                glSurfaceView?.setCharacterOpacity(characterOpacity)
            } else {
                // 앱 배경: 터치 패스스루, 캐릭터 투명도 = 터치스루 설정값
                applyTouchPassthrough()
                glSurfaceView?.setCharacterOpacity(touchThroughAlpha)
            }
        } else {
            // 터치스루 OFF: 항상 터치 수신, 캐릭터 투명도 = 표시 설정값
            applyTouchReceiving()
            glSurfaceView?.setCharacterOpacity(characterOpacity)
        }
        
        // 윈도우 레이아웃 업데이트
        overlayView?.let {
            try {
                windowManager.updateViewLayout(it, overlayParams)
            } catch (e: Exception) {
                Live2DLogger.Overlay.w("터치 모드 업데이트 실패", e.message)
            }
        }
    }
    
    /**
     * 터치 패스스루 적용 (앱 배경 시)
     */
    private fun applyTouchPassthrough() {
        overlayParams.flags = overlayParams.flags or
                WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE or
                WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL
        
        overlayView?.let {
            it.setOnTouchListener(null)
            try {
                windowManager.updateViewLayout(it, overlayParams)
            } catch (e: Exception) {
                Live2DLogger.Overlay.w("터치 패스스루 적용 실패", e.message)
            }
        }
        Live2DLogger.Overlay.d("터치 모드", "패스스루 (앱 배경)")
    }
    
    /**
     * 터치 수신 적용 (앱 전경 시 — 드래그 가능)
     * FLAG_NOT_TOUCHABLE만 제거, FLAG_NOT_FOCUSABLE 유지 (키보드 방지)
     */
    private fun applyTouchReceiving() {
        overlayParams.flags = (overlayParams.flags and
                WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE.inv()) or
                WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL or
                WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS
        
        overlayView?.let {
            try {
                windowManager.updateViewLayout(it, overlayParams)
            } catch (e: Exception) {
                Live2DLogger.Overlay.w("터치 수신 적용 실패", e.message)
            }
        }
        
        // 드래그 리스너 설정
        setupDragListener()
        Live2DLogger.Overlay.d("터치 모드", "수신 (앱 전경, 드래그 가능)")
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
    // 동적 사이징 (Part 1)
    // ============================================================================
    
    /**
     * 모델 크기 × 스케일 × 패딩으로 GLSurfaceView 크기 계산
     * 
     * @param modelWidth 모델 캔버스/바운딩 박스 너비 (px). 0이면 화면 비율 기본값 사용.
     * @param modelHeight 모델 캔버스/바운딩 박스 높이 (px). 0이면 화면 비율 기본값 사용.
     * @param modelScale 현재 모델 스케일
     * @param screenWidth 화면 너비
     * @param screenHeight 화면 높이
     * @return Pair(width, height)
     */
    private fun calculateSurfaceSize(
        modelWidth: Float, modelHeight: Float, modelScale: Float,
        screenWidth: Int, screenHeight: Int
    ): Pair<Int, Int> {
        // 모델 바운딩 박스를 가져올 수 없으면 화면의 50% 기본값 사용
        val baseW = if (modelWidth > 0f) modelWidth else screenWidth * DEFAULT_MODEL_SIZE_RATIO
        val baseH = if (modelHeight > 0f) modelHeight else screenHeight * DEFAULT_MODEL_SIZE_RATIO
        
        var width = (baseW * modelScale * PADDING_MULTIPLIER).toInt()
        var height = (baseH * modelScale * PADDING_MULTIPLIER).toInt()
        
        // 화면 대비 최소/최대 제약
        val minW = (screenWidth * MIN_SIZE_RATIO).toInt()
        val maxW = (screenWidth * MAX_SIZE_RATIO).toInt()
        val minH = (screenHeight * MIN_SIZE_RATIO).toInt()
        val maxH = (screenHeight * MAX_SIZE_RATIO).toInt()
        
        width = width.coerceIn(minW, maxW)
        height = height.coerceIn(minH, maxH)
        
        return Pair(width, height)
    }
    
    /**
     * 현재 스케일에 맞춰 GLSurfaceView 동적 사이징 적용
     * 
     * 모델 바운딩 박스 정보가 없으면 화면 크기 기반 기본값을 사용합니다.
     * Part 3에서 바운딩 박스 추출이 구현되면 modelWidth/Height를 업데이트합니다.
     */
    private fun applyDynamicSizing(scale: Float) {
        val displayMetrics = resources.displayMetrics
        val screenWidth = displayMetrics.widthPixels
        val screenHeight = displayMetrics.heightPixels
        
        // TODO: Part 3에서 모델 캔버스/바운딩 박스 크기를 추출하여 사용
        // 현재는 0을 전달하여 화면 50% 기본값 사용
        val modelWidth = 0f
        val modelHeight = 0f
        
        val (newWidth, newHeight) = calculateSurfaceSize(
            modelWidth, modelHeight, scale, screenWidth, screenHeight
        )
        
        currentWidth = newWidth
        currentHeight = newHeight
        overlayParams.width = newWidth
        overlayParams.height = newHeight
        
        overlayView?.let {
            try {
                windowManager.updateViewLayout(it, overlayParams)
            } catch (e: Exception) {
                Live2DLogger.Overlay.w("동적 사이징 레이아웃 업데이트 실패", e.message)
            }
        }
        
        Live2DLogger.Overlay.d("동적 사이징 적용", "${newWidth}x${newHeight} (scale=$scale, padding=$PADDING_MULTIPLIER)")
    }
    
    /**
     * 스케일 변경 시 GLSurfaceView 크기 업데이트 (Part 3에서 호출)
     * 
     * @param newScale 새로운 모델 스케일
     */
    fun updateSurfaceSizeForScale(newScale: Float) {
        applyDynamicSizing(newScale)
    }
    
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

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
import android.graphics.Color
import android.graphics.drawable.GradientDrawable
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.provider.Settings
import android.view.Gravity
import android.util.TypedValue
import android.view.inputmethod.InputMethodManager
import android.view.MotionEvent
import android.view.View
import android.view.ViewGroup
import android.view.WindowManager
import android.widget.Button
import android.widget.EditText
import android.widget.FrameLayout
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.Switch
import android.widget.TextView
import androidx.core.app.NotificationCompat
import com.example.flutter_application_1.MainActivity
import com.example.flutter_application_1.live2d.Live2DEventStreamHandler
import com.example.flutter_application_1.live2d.core.Live2DLogger
import com.example.flutter_application_1.live2d.cubism.CubismFrameworkManager
import com.example.flutter_application_1.live2d.cubism.CubismTextureManager
import com.example.flutter_application_1.live2d.gesture.GestureConfig
import com.example.flutter_application_1.live2d.gesture.GestureDetectorManager
import com.example.flutter_application_1.live2d.gesture.GestureType
import com.example.flutter_application_1.live2d.renderer.Live2DGLSurfaceView
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.plugin.common.MethodChannel

/**
 * 
 */
class Live2DOverlayService : Service() {
    
    companion object {
        private const val TAG = "Live2DOverlayService"
        
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
        const val ACTION_SET_PARAMETER = "com.example.flutter_application_1.live2d.SET_PARAMETER"
        const val ACTION_OPEN_MINI_MENU = "com.example.flutter_application_1.live2d.OPEN_MINI_MENU"
        const val ACTION_CLOSE_MINI_MENU = "com.example.flutter_application_1.live2d.CLOSE_MINI_MENU"

        const val EDGE_LEFT = 1
        const val EDGE_TOP = 2
        const val EDGE_RIGHT = 4
        const val EDGE_BOTTOM = 8
        const val HANDLE_SIZE = 50f
        const val MIN_BOX_SIZE = 100
        
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
        const val EXTRA_PARAMETER_ID = "parameter_id"
        const val EXTRA_PARAMETER_VALUE = "parameter_value"
        const val EXTRA_PARAMETER_DURATION = "parameter_duration"
        
        private const val CHANNEL_ID = "live2d_overlay_channel"
        private const val MINI_MENU_CHANNEL = "com.example.flutter_application_1/mini_menu"
        private const val ENGINE_ID = "main_engine"
        private const val NOTIFICATION_ID = 1001

        private const val REQUEST_CODE_OPEN_APP = 1000
        
        // Android 12+ (API 31) Untrusted Touch Occlusion:
        private val MAX_OVERLAY_ALPHA = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) 0.8f else 1.0f
        
        private const val DEFAULT_WIDTH = 300
        private const val DEFAULT_HEIGHT = 400
        
        const val PADDING_MULTIPLIER = 1.5f
        const val MIN_SIZE_RATIO = 0.3f
        const val MAX_SIZE_RATIO = 2.0f
        const val DEFAULT_MODEL_SIZE_RATIO = 0.5f
        
        private const val STATE_CHECK_INTERVAL_MS = 30_000L
        private const val PERMISSION_CHECK_INTERVAL_MS = 60_000L
        
        // WHY isRunning is in companion object:
        // The service can be stopped and restarted by Android at any time.
        // Companion object survives service recreation within the same process.
        // This allows Flutter to query state even if service instance changed.
        // CAVEAT: Does not survive process death - Flutter should verify via isOverlayVisible() call.
        @Volatile
        var isRunning = false
            private set
        
        @Volatile
        var serviceStartTime: Long = 0L
            private set
            
        @Volatile
        var currentModelInfo: Map<String, Any>? = null
            private set

        @Volatile
        private var lastDisplayState: Map<String, Any> = emptyMap()

        fun getDisplayState(context: Context): Map<String, Any> {
            val metrics = context.resources.displayMetrics
            return lastDisplayState.toMutableMap().apply {
                put("screenWidth", metrics.widthPixels)
                put("screenHeight", metrics.heightPixels)
                put("density", metrics.density)
            }
        }
    }
    
    private lateinit var windowManager: WindowManager
    private var overlayView: View? = null
    private var overlayContainer: FrameLayout? = null
    private var glSurfaceView: Live2DGLSurfaceView? = null
    @Volatile private var isHidingOverlay = false
    
    private var gestureDetector: GestureDetectorManager? = null
    
    private var currentModelPath: String? = null
    
    private var currentScale = 1f
    private var currentOpacity = 1f
    private var currentWidth = DEFAULT_WIDTH
    private var currentHeight = DEFAULT_HEIGHT
    
    private var touchThroughEnabled = true
    private var touchThroughAlpha = 0.8f
    private var characterOpacity = 1.0f
    @Volatile private var isAppForeground = false
    
    private var editModeEnabled = false
    private var characterPinned = false
    private var boxSelected = false
    private var pinnedCharScreenX = 0
    private var pinnedCharScreenY = 0
    private var relativeCharacterScale = 1.0f
    private var characterOffsetPixelX = 0f
    private var characterOffsetPixelY = 0f
    private var characterRotationDeg = 0
    
    private enum class TouchState { IDLE, DRAGGING, BOX_DRAGGING, BOX_RESIZING }
    private var touchState = TouchState.IDLE
    private var resizeEdgeMask = 0  // bitmask: 1=LEFT, 2=TOP, 4=RIGHT, 8=BOTTOM

    private var miniMenuOverlayView: View? = null
    private var miniMenuCardView: View? = null
    private var miniMenuParams: WindowManager.LayoutParams? = null
    private var miniMenuSessionId: String? = null
    private var miniMenuMessagesContainer: LinearLayout? = null
    private var miniMenuMessagesScrollView: ScrollView? = null
    private var miniMenuInputField: EditText? = null
    private var miniMenuStatusText: TextView? = null
    private var miniMenuScreenshotText: EditText? = null
    private var miniMenuTouchToggle: Switch? = null
    private var miniMenuNotificationToggle: Switch? = null
    private val miniMenuHandler = Handler(Looper.getMainLooper())
    private var miniMenuPolling = false

    
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

    private val stateCheckHandler = Handler(Looper.getMainLooper())
    
    private val stateCheckRunnable = object : Runnable {
        override fun run() {
            if (isRunning) {
                broadcastState()
                stateCheckHandler.postDelayed(this, STATE_CHECK_INTERVAL_MS)
            }
        }
    }
    
    private val permissionCheckRunnable = object : Runnable {
        override fun run() {
            if (!checkAndRecoverPermission()) return
            stateCheckHandler.postDelayed(this, PERMISSION_CHECK_INTERVAL_MS)
        }
    }
    
    private val overlayParams: WindowManager.LayoutParams by lazy {
        WindowManager.LayoutParams().apply {
            type = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
            } else {
                @Suppress("DEPRECATION")
                WindowManager.LayoutParams.TYPE_PHONE
            }
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
            ACTION_SET_PARAMETER -> setParameterValue(
                intent.getStringExtra(EXTRA_PARAMETER_ID) ?: "",
                intent.getFloatExtra(EXTRA_PARAMETER_VALUE, 0f),
                intent.getIntExtra(EXTRA_PARAMETER_DURATION, 0)
            )
            ACTION_OPEN_MINI_MENU -> openMiniMenu(intent.getStringExtra("sessionId"))
            ACTION_CLOSE_MINI_MENU -> closeMiniMenu()
        }
        
        return START_STICKY
    }
    
    override fun onBind(intent: Intent?): IBinder? = null
    
    override fun onDestroy() {
        android.util.Log.d("Live2D", ">>> SERVICE onDestroy")
        Live2DLogger.Overlay.i("서비스 종료", "Live2DOverlayService 정리")
        closeMiniMenu()
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
    // ============================================================================
    
    private fun showOverlay() {
        if (overlayView != null) {
            Live2DLogger.Overlay.w("오버레이 표시 스킵", "이미 표시되어 있음")
            return
        }
        
        if (!checkAndRecoverPermission()) {
            Live2DLogger.Overlay.e("오버레이 표시 실패", "권한 없음")
            return
        }
        
        Live2DLogger.Overlay.i("오버레이 표시 시작", "GLSurfaceView 생성")
        
        // Note: startForeground() is already called in onCreate()
        // No need to call it again here
        Live2DLogger.Overlay.d("Foreground Service 이미 시작됨", "notificationId=$NOTIFICATION_ID")
        
        glSurfaceView = Live2DGLSurfaceView(this)
        
        overlayContainer = FrameLayout(this).apply {
            addView(glSurfaceView, FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT
            ))
        }
        overlayView = overlayContainer
        Live2DLogger.Overlay.d("GLSurfaceView 생성됨", "크기: ${currentWidth}x${currentHeight}")
        
        glSurfaceView?.setBackgroundColor(0f, 0f, 0f, 0f)
        
        glSurfaceView?.apply {
            isClickable = false
            isFocusable = false
            isFocusableInTouchMode = false
        }
        
        overlayParams.alpha = 1.0f
        
        applyDynamicSizing(currentScale)
        
        Live2DLogger.Overlay.d("터치스루 초기화", "enabled=$touchThroughEnabled, foreground=$isAppForeground")
        
        try {
            windowManager.addView(overlayView, overlayParams)
            isRunning = true
            
            updateTouchMode()
            
            updateEditModeBorder()
            updateDisplayState()
            
            startStateChecks()
            
            Live2DEventStreamHandler.getInstance()?.sendOverlayShown()
            
            Live2DLogger.Overlay.i("오버레이 표시 완료", "위치: (${overlayParams.x}, ${overlayParams.y}), 크기: ${overlayParams.width}x${overlayParams.height}")
        } catch (e: Exception) {
            Live2DLogger.Overlay.e("오버레이 표시 실패", "WindowManager.addView 예외", e)
            overlayView = null
        }
    }
    
    private fun hideOverlay() {
        if (isHidingOverlay) {
            Live2DLogger.Overlay.d("오버레이 숨김 스킵", "already in progress")
            return
        }
        isHidingOverlay = true

        closeMiniMenu()
        stopStateChecks()
        
        overlayView?.let { view ->
            Live2DLogger.Overlay.i("오버레이 숨김 시작", "리소스 정리")
            
            gestureDetector?.dispose()
            gestureDetector = null
            
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
        overlayContainer = null
        glSurfaceView = null
        isRunning = false

        try {
            CubismTextureManager.invalidateGlobalCache()
        } catch (e: Exception) {
            Live2DLogger.Overlay.w("텍스처 캐시 무효화 실패", e.message)
        }

        try {
            CubismFrameworkManager.dispose()
            Live2DLogger.Overlay.d("CubismFramework 정리완료", null)
        } catch (e: Exception) {
            Live2DLogger.Overlay.e("CubismFramework dispose 실패", null, e)
        }
        
        Live2DEventStreamHandler.getInstance()?.sendOverlayHidden()
        Live2DLogger.Overlay.i("오버레이 숨김 완료", "서비스 중지")
        
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
    }
    
    /**
     */
    private fun setupDragListener() {
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
                                overlayParams.x = (initialX + dx).toInt()
                                overlayParams.y = (initialY + dy).toInt()
                                windowManager.updateViewLayout(overlayView, overlayParams)
                            }
                            TouchState.BOX_DRAGGING -> {
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
                        boxSelected = !boxSelected
                        updateEditModeBorder()
                    }
                    touchState = TouchState.IDLE
                    true
                }
                MotionEvent.ACTION_OUTSIDE -> {
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
     */
    private fun handleGesture(gestureType: GestureType) {
        when (gestureType) {
            GestureType.TAP -> {
                glSurfaceView?.playMotion("tap", false)
            }
            GestureType.DOUBLE_TAP -> {
                setRandomExpression()
            }
            GestureType.LONG_PRESS -> {
                glSurfaceView?.playMotion("special", false)
            }
            GestureType.HEAD_PAT -> {
                glSurfaceView?.setExpression("happy")
                glSurfaceView?.playMotion("happy", false)
            }
            GestureType.POKE -> {
                glSurfaceView?.setExpression("surprised")
            }
            GestureType.SWIPE_UP -> {
                glSurfaceView?.playMotion("greet", false)
            }
            GestureType.SWIPE_DOWN -> {
                glSurfaceView?.playMotion("bow", false)
            }
            else -> {
            }
        }
    }
    
    // ============================================================================
    // ============================================================================
    
    private fun loadModel(path: String) {
        Live2DLogger.Model.i("모델 로드 요청", path)
        
        val modelName = path.substringAfterLast("/").substringBeforeLast(".")
        
        glSurfaceView?.let { gl ->
            if (gl.loadModel(path, modelName)) {
                currentModelPath = path
                
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
        Live2DEventStreamHandler.getInstance()?.sendModelUnloaded()
    }
    
    private fun playMotion(group: String, index: Int, priority: Int) {
        Live2DLogger.Model.d("모션 재생 요청", "$group[$index], priority=$priority")
        
        glSurfaceView?.let { gl ->
            val motionName = if (index > 0) "${group}_$index" else group
            val loop = (priority <= 1)
            gl.playMotion(motionName, loop)
        }
    }
    
    private fun setExpression(id: String) {
        Live2DLogger.Model.d("표정 설정 요청", id)
        
        glSurfaceView?.setExpression(id)
    }
    
    private fun setRandomExpression() {
        Live2DLogger.Model.d("랜덤 표정 요청", null)
        
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
    // ============================================================================
    
    private fun setScale(scale: Float) {
        Live2DLogger.Overlay.d("스케일 설정", "$scale")
        currentScale = scale
        
        glSurfaceView?.setModelScale(scale)
        
        updateSurfaceSizeForScale(scale)
    }
    
    private fun setOpacity(opacity: Float) {
        setCharacterOpacity(opacity)
    }
    
    // ============================================================================
    // ============================================================================
    
    /**
     */
    private fun setTouchThroughEnabled(enabled: Boolean) {
        Live2DLogger.Overlay.d("터치스루 토글", "enabled=$enabled")
        touchThroughEnabled = enabled
        updateTouchMode()
        refreshForegroundNotification()
    }
    
    /**
     */
    private fun setTouchThroughAlphaValue(alpha: Int) {
        val normalizedAlpha = (alpha / 100f).coerceIn(0f, 1.0f)
        Live2DLogger.Overlay.d("터치스루 알파", "input=$alpha, applied=$normalizedAlpha")
        touchThroughAlpha = normalizedAlpha
        
        if (touchThroughEnabled && !isAppForeground) {
            glSurfaceView?.setCharacterOpacity(touchThroughAlpha)
        }
    }
    
    /**
     */
    private fun setCharacterOpacity(opacity: Float) {
        Live2DLogger.Overlay.d("캐릭터 투명도", "opacity=$opacity")
        characterOpacity = opacity.coerceIn(0f, 1f)
        if (!(touchThroughEnabled && !isAppForeground)) {
            glSurfaceView?.setCharacterOpacity(characterOpacity)
        }
    }
    
    /**
     */
    private fun setEditModeEnabled(enabled: Boolean) {
        Live2DLogger.Overlay.d("편집 모드", "enabled=$enabled")
        editModeEnabled = enabled
        if (!enabled) {
            characterPinned = false
            boxSelected = false
        }
        updateEditModeBorder()
        if (overlayView != null) setupDragListener()
    }
    
    /**
     */
    private fun setCharacterPinnedMode(enabled: Boolean) {
        Live2DLogger.Overlay.d("캐릭터 고정", "enabled=$enabled")
        if (enabled && !characterPinned) {
            pinnedCharScreenX = overlayParams.x + currentWidth / 2
            pinnedCharScreenY = overlayParams.y + currentHeight / 2
        }
        characterPinned = enabled
        boxSelected = false
        updateEditModeBorder()
        if (overlayView != null) setupDragListener()
    }
    
    /**
     */
    private fun setRelativeScaleValue(scale: Float) {
        Live2DLogger.Overlay.d("상대 스케일", "scale=$scale")
        relativeCharacterScale = scale.coerceIn(0.1f, 3.0f)
        glSurfaceView?.setRelativeScale(relativeCharacterScale)
        updateDisplayState()
    }
    
    /**
     */
    private fun setCharacterOffsetValue(x: Float, y: Float) {
        Live2DLogger.Overlay.d("캐릭터 오프셋", "($x, $y)")
        characterOffsetPixelX = x
        characterOffsetPixelY = y
        glSurfaceView?.setCharacterOffset(x, y)
        updateDisplayState()
    }
    
    /**
     */
    private fun setCharacterRotationValue(degrees: Int) {
        Live2DLogger.Overlay.d("캐릭터 회전", "$degrees°")
        characterRotationDeg = degrees % 360
        glSurfaceView?.setCharacterRotation(characterRotationDeg)
        updateDisplayState()
    }

    private fun setParameterValue(paramId: String, value: Float, durationMs: Int) {
        if (paramId.isBlank()) return
        glSurfaceView?.setParameterValue(paramId, value, durationMs)
    }
    
    /**
     */
    private fun updateCharacterOffsetFromPinned() {
        val boxCenterX = overlayParams.x + currentWidth / 2
        val boxCenterY = overlayParams.y + currentHeight / 2
        characterOffsetPixelX = (pinnedCharScreenX - boxCenterX).toFloat()
        characterOffsetPixelY = (pinnedCharScreenY - boxCenterY).toFloat()
        glSurfaceView?.setCharacterOffset(characterOffsetPixelX, characterOffsetPixelY)
        updateDisplayState()
    }
    
    /**
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
        
        if (characterPinned) {
            updateCharacterOffsetFromPinned()
        }
        updateDisplayState()
    }
    
    /**
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
     * 
     */
    private fun updateTouchMode() {
        if (overlayView == null) return
        
        overlayParams.alpha = 1.0f
        
        if (touchThroughEnabled) {
            if (isAppForeground) {
                applyTouchReceiving()
                glSurfaceView?.setCharacterOpacity(characterOpacity)
            } else {
                applyTouchPassthrough()
                glSurfaceView?.setCharacterOpacity(touchThroughAlpha)
            }
        } else {
            applyTouchReceiving()
            glSurfaceView?.setCharacterOpacity(characterOpacity)
        }
        
        overlayView?.let {
            try {
                windowManager.updateViewLayout(it, overlayParams)
            } catch (e: Exception) {
                Live2DLogger.Overlay.w("터치 모드 업데이트 실패", e.message)
            }
        }
    }
    
    /**
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
        updateDisplayState()
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
        updateDisplayState()
    }

    private fun updateDisplayState() {
        val metrics = resources.displayMetrics
        val state = mapOf(
            "containerWidth" to currentWidth,
            "containerHeight" to currentHeight,
            "containerX" to overlayParams.x,
            "containerY" to overlayParams.y,
            "relativeScale" to relativeCharacterScale,
            "offsetX" to characterOffsetPixelX,
            "offsetY" to characterOffsetPixelY,
            "rotationDeg" to characterRotationDeg,
            "screenWidth" to metrics.widthPixels,
            "screenHeight" to metrics.heightPixels,
            "density" to metrics.density,
            "globalScale" to currentScale,
        )
        lastDisplayState = state
        Live2DEventStreamHandler.getInstance()?.sendSystemEvent(
            "displayStateChanged",
            state,
        )
    }
    
    // ============================================================================
    // ============================================================================
    
    /**
     * 
     * @return Pair(width, height)
     */
    private fun calculateSurfaceSize(
        modelWidth: Float, modelHeight: Float, modelScale: Float,
        screenWidth: Int, screenHeight: Int
    ): Pair<Int, Int> {
        val baseW = if (modelWidth > 0f) modelWidth else screenWidth * DEFAULT_MODEL_SIZE_RATIO
        val baseH = if (modelHeight > 0f) modelHeight else screenHeight * DEFAULT_MODEL_SIZE_RATIO
        
        var width = (baseW * modelScale * PADDING_MULTIPLIER).toInt()
        var height = (baseH * modelScale * PADDING_MULTIPLIER).toInt()
        
        val minW = (screenWidth * MIN_SIZE_RATIO).toInt()
        val maxW = (screenWidth * MAX_SIZE_RATIO).toInt()
        val minH = (screenHeight * MIN_SIZE_RATIO).toInt()
        val maxH = (screenHeight * MAX_SIZE_RATIO).toInt()
        
        width = width.coerceIn(minW, maxW)
        height = height.coerceIn(minH, maxH)
        
        return Pair(width, height)
    }
    
    /**
     * 
     */
    private fun applyDynamicSizing(scale: Float) {
        val displayMetrics = resources.displayMetrics
        val screenWidth = displayMetrics.widthPixels
        val screenHeight = displayMetrics.heightPixels
        
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
        updateDisplayState()
    }
    
    /**
     * 
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
    }
    
    private fun setBreathing(enabled: Boolean) {
        Live2DLogger.Model.d("호흡 설정", "$enabled")
        isBreathingEnabled = enabled
    }
    
    private fun setLookAt(enabled: Boolean) {
        Live2DLogger.Model.d("시선 추적 설정", "$enabled")
        isLookAtEnabled = enabled
    }
    
    // ============================================================================
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
    // ============================================================================
    
    private fun handleSignal(signal: String) {
        Live2DLogger.d("신호 수신", signal)
        
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
    // ============================================================================
    
    /**
     * 
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
     * 
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
     */
    private fun startStateChecks() {
        serviceStartTime = System.currentTimeMillis()
        
        broadcastState()
        
        stateCheckHandler.postDelayed(stateCheckRunnable, STATE_CHECK_INTERVAL_MS)
        stateCheckHandler.postDelayed(permissionCheckRunnable, PERMISSION_CHECK_INTERVAL_MS)
        
        Live2DLogger.Overlay.d("상태 체크 시작", "state=${STATE_CHECK_INTERVAL_MS}ms, perm=${PERMISSION_CHECK_INTERVAL_MS}ms")
    }
    
    /**
     */
    private fun stopStateChecks() {
        stateCheckHandler.removeCallbacks(stateCheckRunnable)
        stateCheckHandler.removeCallbacks(permissionCheckRunnable)
        serviceStartTime = 0
        Live2DLogger.Overlay.d("상태 체크 중지", null)
    }

    private fun dp(value: Int): Int {
        return TypedValue.applyDimension(
            TypedValue.COMPLEX_UNIT_DIP,
            value.toFloat(),
            resources.displayMetrics,
        ).toInt()
    }

    private fun miniMenuChannel(): MethodChannel? {
        val engine = FlutterEngineCache.getInstance().get(ENGINE_ID) ?: return null
        return MethodChannel(engine.dartExecutor.binaryMessenger, MINI_MENU_CHANNEL)
    }

    private fun invokeMiniMenuMethod(
        method: String,
        arguments: Any? = null,
        onSuccess: (Any?) -> Unit = {},
        onError: (String) -> Unit = {},
    ) {
        val channel = miniMenuChannel() ?: run {
            onError("flutter_engine_unavailable")
            return
        }
        channel.invokeMethod(method, arguments, object : MethodChannel.Result {
            override fun success(result: Any?) {
                onSuccess(result)
            }

            override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) {
                onError(errorMessage ?: errorCode)
            }

            override fun notImplemented() {
                onError("not_implemented")
            }
        })
    }

    private fun withResolvedMiniMenuSessionId(onReady: (String?) -> Unit) {
        if (!miniMenuSessionId.isNullOrBlank()) {
            onReady(miniMenuSessionId)
            return
        }
        invokeMiniMenuMethod(
            "miniMenuGetActiveSessionId",
            onSuccess = { result ->
                miniMenuSessionId = result as? String
                onReady(miniMenuSessionId)
            },
            onError = {
                onReady(miniMenuSessionId)
            },
        )
    }

    private fun openMiniMenu(sessionId: String?) {
        if (!Settings.canDrawOverlays(this)) {
            val intent = Intent(
                Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                android.net.Uri.parse("package:$packageName"),
            ).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            startActivity(intent)
            return
        }
        if (miniMenuOverlayView != null) {
            miniMenuSessionId = sessionId ?: miniMenuSessionId
            refreshMiniMenuFromFlutter()
            return
        }

        miniMenuSessionId = sessionId
        if (miniMenuSessionId == null) {
            invokeMiniMenuMethod("miniMenuGetActiveSessionId", onSuccess = { result ->
                miniMenuSessionId = result as? String
                showMiniMenuWindow()
            })
            return
        }
        showMiniMenuWindow()
    }

    private var miniMenuTabButtons: List<Button>? = null
    private var miniMenuCurrentTabIndex = 0

    private fun showMiniMenuWindow() {
        if (miniMenuOverlayView != null) return
        val root = FrameLayout(this).apply {
            setBackgroundColor(0x88000000.toInt())
            isClickable = true
            setOnClickListener { closeMiniMenu() }
        }

        val card = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            val bg = GradientDrawable().apply {
                cornerRadius = dp(16).toFloat()
                setColor(Color.WHITE)
            }
            background = bg
            elevation = dp(8).toFloat()
            setPadding(dp(12), dp(12), dp(12), dp(12))
            isClickable = true
            setOnClickListener { }
        }
        miniMenuCardView = card

        val tabs = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER
        }
        val generalButton = Button(this).apply { text = "General" }
        val inputButton = Button(this).apply { text = "Input" }
        val settingsButton = Button(this).apply { text = "설정" }
        val tabButtonList = listOf(generalButton, inputButton, settingsButton)
        miniMenuTabButtons = tabButtonList
        tabs.addView(generalButton)
        tabs.addView(inputButton)
        tabs.addView(settingsButton)

        val generalTab = buildGeneralTab()
        val inputTab = buildInputTab()
        val settingsTab = buildSettingsTab()

        fun updateTabStyle(selectedIndex: Int) {
            for ((i, btn) in tabButtonList.withIndex()) {
                if (i == selectedIndex) {
                    btn.setBackgroundColor(0xFF2196F3.toInt())
                    btn.setTextColor(Color.WHITE)
                } else {
                    btn.setBackgroundColor(Color.LTGRAY)
                    btn.setTextColor(Color.BLACK)
                }
            }
        }

        fun showTab(index: Int) {
            miniMenuCurrentTabIndex = index
            generalTab.visibility = if (index == 0) View.VISIBLE else View.GONE
            inputTab.visibility = if (index == 1) View.VISIBLE else View.GONE
            settingsTab.visibility = if (index == 2) View.VISIBLE else View.GONE
            updateTabStyle(index)
            if (index == 0) {
                refreshMiniMenuFromFlutter()
            }
            if (index == 1) {
                refreshMessages()
            }
        }
        generalButton.setOnClickListener { showTab(0) }
        inputButton.setOnClickListener { showTab(1) }
        settingsButton.setOnClickListener { showTab(2) }

        val closeButton = Button(this).apply {
            text = "닫기"
            setOnClickListener { closeMiniMenu() }
        }

        card.addView(tabs)
        card.addView(closeButton)
        card.addView(generalTab)
        card.addView(inputTab)
        card.addView(settingsTab)
        showTab(0)

        val contentParams = FrameLayout.LayoutParams(
            (resources.displayMetrics.widthPixels * 0.8f).toInt(),
            (resources.displayMetrics.heightPixels * 0.6f).toInt(),
        ).apply {
            gravity = Gravity.CENTER
        }
        root.addView(card, contentParams)

        val params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.MATCH_PARENT,
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
            } else {
                @Suppress("DEPRECATION")
                WindowManager.LayoutParams.TYPE_PHONE
            },
            WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL or
                WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
            PixelFormat.TRANSLUCENT,
        )
        miniMenuParams = params
        miniMenuOverlayView = root

        try {
            windowManager.addView(root, params)
            miniMenuTouchToggle?.isChecked = touchThroughEnabled
            startMiniMenuPolling()
            refreshMiniMenuFromFlutter()
        } catch (e: Exception) {
            Live2DLogger.Overlay.e("미니 메뉴 표시 실패", e.message, e)
            miniMenuOverlayView = null
            miniMenuParams = null
        }
    }

    private fun closeMiniMenu() {
        stopMiniMenuPolling()
        // Clear focus first to avoid IME warnings
        miniMenuInputField?.clearFocus()
        miniMenuScreenshotText?.clearFocus()
        hideMiniMenuKeyboard()
        miniMenuOverlayView?.let {
            try {
                windowManager.removeView(it)
            } catch (_: Exception) {
            }
        }
        miniMenuOverlayView = null
        miniMenuCardView = null
        miniMenuParams = null
        miniMenuMessagesContainer = null
        miniMenuMessagesScrollView = null
        miniMenuInputField = null
        miniMenuStatusText = null
        miniMenuScreenshotText = null
        miniMenuTouchToggle = null
        miniMenuNotificationToggle = null
        miniMenuTabButtons = null
        miniMenuCurrentTabIndex = 0
    }

    private fun hideMiniMenuKeyboard() {
        val imm = getSystemService(Context.INPUT_METHOD_SERVICE) as? InputMethodManager
        val screenshotToken = miniMenuScreenshotText?.windowToken
        val inputToken = miniMenuInputField?.windowToken
        if (screenshotToken != null) {
            imm?.hideSoftInputFromWindow(screenshotToken, 0)
        }
        if (inputToken != null) {
            imm?.hideSoftInputFromWindow(inputToken, 0)
        }
        miniMenuScreenshotText?.clearFocus()
        miniMenuInputField?.clearFocus()
    }

    private fun startMiniMenuPolling() {
        if (miniMenuPolling) return
        miniMenuPolling = true
        miniMenuHandler.post(object : Runnable {
            override fun run() {
                if (!miniMenuPolling || miniMenuOverlayView == null) return
                refreshMiniMenuFromFlutter()
                miniMenuHandler.postDelayed(this, 2000)
            }
        })
    }

    private fun stopMiniMenuPolling() {
        miniMenuPolling = false
        miniMenuHandler.removeCallbacksAndMessages(null)
    }

    private fun buildGeneralTab(): View {
        val layout = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(8), dp(8), dp(8), dp(8))
        }

        miniMenuScreenshotText = EditText(this).apply {
            hint = "메세지 (선택사항)"
        }
        val screenshotButton = Button(this).apply {
            text = "스크린샷"
            setOnClickListener {
                val text = miniMenuScreenshotText?.text?.toString()?.trim().orEmpty()
                miniMenuStatusText?.text = "Capturing..."
                withResolvedMiniMenuSessionId { resolvedSessionId ->
                    closeMiniMenu()
                    miniMenuHandler.postDelayed({
                        invokeMiniMenuMethod(
                            "miniMenuCaptureAndSendScreenshot",
                            mapOf("sessionId" to resolvedSessionId, "text" to text),
                            onSuccess = { result ->
                                val map = result as? Map<*, *>
                                val ok = map?.get("ok") as? Boolean ?: false
                                val error = map?.get("message")?.toString()
                                    ?: map?.get("error")?.toString()
                                if (!ok) {
                                    miniMenuStatusText?.text = "오류: ${error ?: "unknown"}"
                                    Live2DLogger.Overlay.w("스크린샷 전송 실패", error ?: "unknown")
                                } else {
                                    miniMenuStatusText?.text = ""
                                    Live2DLogger.Overlay.d("스크린샷 전송 완료", null)
                                }
                            },
                            onError = { err ->
                                miniMenuStatusText?.text = "오류: $err"
                                Live2DLogger.Overlay.w("스크린샷 캡처 오류", err)
                            },
                        )
                    }, 500)
                }
            }
        }

        miniMenuTouchToggle = Switch(this).apply {
            text = "터치스루"
            isChecked = touchThroughEnabled
            setOnCheckedChangeListener { _, _ ->
                invokeMiniMenuMethod(
                    "miniMenuToggleTouchThrough",
                    onSuccess = { result ->
                        val enabled = result as? Boolean ?: false
                        touchThroughEnabled = enabled
                        post {
                            setOnCheckedChangeListener(null)
                            isChecked = enabled
                            setOnCheckedChangeListener { _, _ ->
                                invokeMiniMenuMethod("miniMenuToggleTouchThrough")
                            }
                        }
                    },
                    onError = {
                        post {
                            setOnCheckedChangeListener(null)
                            isChecked = touchThroughEnabled
                            setOnCheckedChangeListener { _, _ ->
                                invokeMiniMenuMethod("miniMenuToggleTouchThrough")
                            }
                        }
                    },
                )
            }
        }

        val openAppButton = Button(this).apply {
            text = "앱으로 이동"
            setOnClickListener {
                closeMiniMenu()
                val intent = Intent(this@Live2DOverlayService, MainActivity::class.java).apply {
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                }
                startActivity(intent)
            }
        }

        miniMenuNotificationToggle = Switch(this).apply {
            text = "알림 간편설정"
            setOnCheckedChangeListener { _, isChecked ->
                invokeMiniMenuMethod(
                    "miniMenuSetNotificationEnabled",
                    mapOf("enabled" to isChecked),
                    onSuccess = { refreshMiniMenuFromFlutter() },
                    onError = { refreshMiniMenuFromFlutter() },
                )
            }
        }

        layout.addView(miniMenuScreenshotText)
        layout.addView(screenshotButton)
        layout.addView(miniMenuTouchToggle)
        layout.addView(openAppButton)
        layout.addView(miniMenuNotificationToggle)
        return layout
    }

    private fun buildInputTab(): View {
        val layout = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(8), dp(8), dp(8), dp(8))
        }

        val scrollView = ScrollView(this)
        miniMenuMessagesScrollView = scrollView
        miniMenuMessagesContainer = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
        }
        scrollView.addView(miniMenuMessagesContainer)

        miniMenuStatusText = TextView(this).apply {
            text = ""
        }

        val inputRow = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
        }
        miniMenuInputField = EditText(this).apply {
            hint = "메세지"
            layoutParams = LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f)
        }
        val sendButton = Button(this).apply {
            text = "Send"
            setOnClickListener {
                val text = miniMenuInputField?.text?.toString()?.trim().orEmpty()
                if (text.isEmpty()) return@setOnClickListener
                miniMenuStatusText?.text = "Responding..."
                withResolvedMiniMenuSessionId { resolvedSessionId ->
                    invokeMiniMenuMethod(
                        "miniMenuSendMessage",
                        mapOf("sessionId" to resolvedSessionId, "message" to text),
                        onSuccess = { result ->
                            val map = result as? Map<*, *>
                            val ok = map?.get("ok") as? Boolean ?: false
                            if (ok) {
                                miniMenuInputField?.setText("")
                                miniMenuStatusText?.text = ""
                                refreshMessages()
                                return@invokeMiniMenuMethod
                            }
                            val error = map?.get("message")?.toString()
                                ?: map?.get("error")?.toString()
                                ?: "send_failed"
                            miniMenuStatusText?.text = "오류: $error"
                        },
                        onError = {
                            miniMenuStatusText?.text = "오류: $it"
                        },
                    )
                }
            }
        }
        inputRow.addView(miniMenuInputField)
        inputRow.addView(sendButton)

        layout.addView(scrollView, LinearLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT,
            0,
            1f,
        ))
        layout.addView(miniMenuStatusText)
        layout.addView(inputRow)
        return layout
    }

    private fun buildSettingsTab(): View {
        return FrameLayout(this).apply {
            addView(TextView(this@Live2DOverlayService).apply {
                text = "향후 업데이트 예정"
                gravity = Gravity.CENTER
                setTextColor(Color.DKGRAY)
            }, FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT,
            ))
        }
    }

    private fun refreshMiniMenuFromFlutter() {
        // Query current touch-through state (GET, not TOGGLE)
        invokeMiniMenuMethod("miniMenuGetTouchThroughEnabled", onSuccess = { result ->
            val enabled = result as? Boolean ?: false
            touchThroughEnabled = enabled
            miniMenuTouchToggle?.let { toggle ->
                toggle.post {
                    toggle.setOnCheckedChangeListener(null)
                    toggle.isChecked = enabled
                    toggle.setOnCheckedChangeListener { _, _ ->
                        invokeMiniMenuMethod("miniMenuToggleTouchThrough", onSuccess = { r ->
                            val next = r as? Boolean ?: false
                            touchThroughEnabled = next
                            updateTouchMode()
                            refreshForegroundNotification()
                            toggle.post {
                                toggle.setOnCheckedChangeListener(null)
                                toggle.isChecked = next
                                toggle.setOnCheckedChangeListener { _, _ ->
                                    invokeMiniMenuMethod("miniMenuToggleTouchThrough", onSuccess = { r2 ->
                                        val next2 = r2 as? Boolean ?: false
                                        touchThroughEnabled = next2
                                        updateTouchMode()
                                        refreshForegroundNotification()
                                        toggle.post {
                                            toggle.setOnCheckedChangeListener(null)
                                            toggle.isChecked = next2
                                        }
                                    })
                                }
                            }
                        })
                    }
                }
            }
        }, onError = {
            // Fallback: use local value
            miniMenuTouchToggle?.let { toggle ->
                toggle.post {
                    toggle.setOnCheckedChangeListener(null)
                    toggle.isChecked = touchThroughEnabled
                }
            }
        })

        invokeMiniMenuMethod("miniMenuGetNotificationEnabled", onSuccess = { result ->
            val enabled = result as? Boolean ?: false
            Live2DLogger.Overlay.d("미니 메뉴 알림 상태 동기화", "enabled=$enabled")
            miniMenuNotificationToggle?.let { toggle ->
                toggle.post {
                    toggle.setOnCheckedChangeListener(null)
                    toggle.isChecked = enabled
                    toggle.setOnCheckedChangeListener { _, isChecked ->
                        invokeMiniMenuMethod(
                            "miniMenuSetNotificationEnabled",
                            mapOf("enabled" to isChecked),
                        )
                    }
                }
            }
        })

        // Only refresh messages if the input tab is currently visible
        if (miniMenuCurrentTabIndex == 1) {
            refreshMessages()
        }
    }

    private fun refreshMessages() {
        miniMenuStatusText?.post { miniMenuStatusText?.text = "Loading..." }
        invokeMiniMenuMethod(
            "miniMenuGetMessages",
            mapOf("sessionId" to miniMenuSessionId),
            onSuccess = { result ->
                val list = (result as? List<*>)
                    ?.filterIsInstance<Map<*, *>>()
                    ?.map { raw ->
                        raw.entries.associate { entry ->
                            entry.key.toString() to entry.value
                        }
                    }
                    ?: emptyList()
                miniMenuStatusText?.post { miniMenuStatusText?.text = "" }
                renderMessages(list)
            },
            onError = { error ->
                Live2DLogger.Overlay.w("메시지 로딩 실패", error)
                miniMenuStatusText?.post {
                    miniMenuStatusText?.text = "메시지 로딩 실패. 앱으로 이동하여 확인하세요."
                }
            },
        )
    }

    private fun renderMessages(messages: List<Map<String, Any?>>) {
        val container = miniMenuMessagesContainer ?: return
        container.removeAllViews()
        for (message in messages) {
            val role = message["role"]?.toString() ?: "user"
            val content = message["content"]?.toString() ?: ""
            val bubble = TextView(this).apply {
                text = content
                setPadding(dp(10), dp(8), dp(10), dp(8))
                val bg = GradientDrawable().apply {
                    cornerRadius = dp(12).toFloat()
                    setColor(if (role == "assistant") 0xFFE8EAF6.toInt() else 0xFFD1F5D3.toInt())
                }
                background = bg
            }
            val params = LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.WRAP_CONTENT,
                ViewGroup.LayoutParams.WRAP_CONTENT,
            ).apply {
                topMargin = dp(6)
                gravity = if (role == "assistant") Gravity.START else Gravity.END
            }
            container.addView(bubble, params)
        }
        miniMenuMessagesScrollView?.post {
            miniMenuMessagesScrollView?.fullScroll(View.FOCUS_DOWN)
        }
    }
    
    // ============================================================================
    // ============================================================================

    private fun refreshForegroundNotification() {
        try {
            val notificationManager = getSystemService(NotificationManager::class.java)
            notificationManager?.notify(NOTIFICATION_ID, createNotification())
        } catch (e: Exception) {
            Live2DLogger.Overlay.w("알림 갱신 실패", e.message)
        }
    }

    private fun createOpenAppPendingIntent(): PendingIntent {
        val intent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK
        }

        return PendingIntent.getActivity(
            this,
            REQUEST_CODE_OPEN_APP,
            intent,
            pendingIntentFlags(),
        )
    }

    private fun pendingIntentFlags(mutable: Boolean = false): Int {
        var flags = PendingIntent.FLAG_UPDATE_CURRENT
        flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            flags or if (mutable) PendingIntent.FLAG_MUTABLE else PendingIntent.FLAG_IMMUTABLE
        } else if (!mutable) {
            flags or PendingIntent.FLAG_IMMUTABLE
        } else {
            flags
        }
        return flags
    }
    
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
        val contentText = "오버레이가 실행 중입니다"
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Live2D 오버레이")
            .setContentText(contentText)
            .setStyle(NotificationCompat.BigTextStyle().bigText(contentText))
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setContentIntent(createOpenAppPendingIntent())
            .setSubText(if (touchThroughEnabled) "Touch-Through ON" else "Touch-Through OFF")
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .build()
    }
}

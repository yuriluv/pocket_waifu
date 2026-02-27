package com.example.flutter_application_1.live2d

import android.content.Context
import android.content.Intent
import android.os.Build
import android.provider.Settings
import android.os.Environment
import android.net.Uri
import com.example.flutter_application_1.live2d.core.Live2DLogger
import com.example.flutter_application_1.live2d.cubism.CubismFrameworkManager
import com.example.flutter_application_1.live2d.cubism.Live2DNativeBridge
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import com.example.flutter_application_1.live2d.overlay.Live2DOverlayService

/**
 * Live2D Method Handler
 * 
 */
class Live2DMethodHandler(
    private val context: Context,
    private val eventStreamHandler: Live2DEventStreamHandler
) : MethodChannel.MethodCallHandler {
    
    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        Live2DLogger.d("메서드 호출", call.method)
        
        try {
            when (call.method) {
                "hasOverlayPermission" -> hasOverlayPermission(result)
                "requestOverlayPermission" -> requestOverlayPermission(result)
                "hasStoragePermission" -> hasStoragePermission(result)
                "requestStoragePermission" -> requestStoragePermission(result)
                
                "showOverlay" -> showOverlay(result)
                "hideOverlay" -> hideOverlay(result)
                "isOverlayVisible" -> isOverlayVisible(result)
                
                "loadModel" -> loadModel(call, result)
                "unloadModel" -> unloadModel(result)
                "playMotion" -> playMotion(call, result)
                "setExpression" -> setExpression(call, result)
                "setRandomExpression" -> setRandomExpression(result)
                
                "setScale" -> setScale(call, result)
                "setOpacity" -> setOpacity(call, result)
                "setPosition" -> setPosition(call, result)
                "setSize" -> setSize(call, result)
                
                "setTouchThroughEnabled" -> setTouchThroughEnabled(call, result)
                "setTouchThroughAlpha" -> setTouchThroughAlpha(call, result)
                "setCharacterOpacity" -> setCharacterOpacity(call, result)
                "setNotificationResponse" -> setNotificationResponse(call, result)
                "setNotificationError" -> setNotificationError(call, result)
                
                "setEditMode" -> setEditMode(call, result)
                "setCharacterPinned" -> setCharacterPinned(call, result)
                "setRelativeScale" -> setRelativeScale(call, result)
                "setCharacterOffset" -> setCharacterOffset(call, result)
                "setCharacterRotation" -> setCharacterRotation(call, result)
                
                "getDisplayState" -> getDisplayState(result)
                "setParameter" -> setParameter(call, result)
                "getParameter" -> getParameter(call, result)
                "getParameterIds" -> getParameterIds(result)
                
                "setEyeBlink" -> setEyeBlink(call, result)
                "setBreathing" -> setBreathing(call, result)
                "setLookAt" -> setLookAt(call, result)
                
                "sendSignal" -> sendSignal(call, result)
                
                "getMotionGroups" -> getMotionGroups(result)
                "getMotionCount" -> getMotionCount(call, result)
                "getMotionNames" -> getMotionNames(call, result)
                "getExpressions" -> getExpressions(result)
                "getModelInfo" -> getModelInfo(result)
                "analyzeModel" -> analyzeModel(call, result)
                
                "setTargetFps" -> setTargetFps(call, result)
                "setLowPowerMode" -> setLowPowerMode(call, result)
                
                "getHealthStatus" -> getHealthStatus(result)
                "forceReset" -> forceReset(result)
                
                else -> {
                    Live2DLogger.w("알 수 없는 메서드", call.method)
                    result.notImplemented()
                }
            }
        } catch (e: Exception) {
            Live2DLogger.e("메서드 실행 오류: ${call.method}", e)
            result.error("EXECUTION_ERROR", e.message, e.stackTraceToString())
        }
    }
    
    // ============================================================================
    // ============================================================================
    
    private fun hasOverlayPermission(result: MethodChannel.Result) {
        val hasPermission = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            Settings.canDrawOverlays(context)
        } else {
            true
        }
        Live2DLogger.d("오버레이 권한 확인", hasPermission.toString())
        result.success(hasPermission)
    }
    
    private fun requestOverlayPermission(result: MethodChannel.Result) {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                if (!Settings.canDrawOverlays(context)) {
                    val intent = Intent(
                        Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                        Uri.parse("package:${context.packageName}")
                    ).apply {
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    }
                    context.startActivity(intent)
                    Live2DLogger.d("오버레이 권한 설정 화면 열기", null)
                }
            }
            result.success(true)
        } catch (e: Exception) {
            Live2DLogger.e("오버레이 권한 요청 실패", e)
            result.error("PERMISSION_ERROR", e.message, null)
        }
    }
    
    private fun hasStoragePermission(result: MethodChannel.Result) {
        val hasPermission = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            Environment.isExternalStorageManager()
        } else {
            true
        }
        Live2DLogger.d("저장소 권한 확인", hasPermission.toString())
        result.success(hasPermission)
    }
    
    private fun requestStoragePermission(result: MethodChannel.Result) {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                if (!Environment.isExternalStorageManager()) {
                    val intent = Intent(Settings.ACTION_MANAGE_APP_ALL_FILES_ACCESS_PERMISSION).apply {
                        data = Uri.parse("package:${context.packageName}")
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    }
                    context.startActivity(intent)
                    Live2DLogger.d("저장소 권한 설정 화면 열기", null)
                }
            }
            result.success(true)
        } catch (e: Exception) {
            Live2DLogger.e("저장소 권한 요청 실패", e)
            result.error("PERMISSION_ERROR", e.message, null)
        }
    }
    
    // ============================================================================
    // ============================================================================
    
    private fun showOverlay(result: MethodChannel.Result) {
        try {
            Live2DLogger.Overlay.d("오버레이 표시 요청", null)
            
            val intent = Intent(context, Live2DOverlayService::class.java).apply {
                action = Live2DOverlayService.ACTION_SHOW
            }
            
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
            
            result.success(true)
        } catch (e: Exception) {
            Live2DLogger.e("오버레이 표시 실패", e)
            result.error("OVERLAY_ERROR", e.message, null)
        }
    }
    
    private fun hideOverlay(result: MethodChannel.Result) {
        try {
            Live2DLogger.Overlay.d("오버레이 숨김 요청", null)
            
            val intent = Intent(context, Live2DOverlayService::class.java).apply {
                action = Live2DOverlayService.ACTION_HIDE
            }
            context.startService(intent)
            
            result.success(true)
        } catch (e: Exception) {
            Live2DLogger.e("오버레이 숨김 실패", e)
            result.error("OVERLAY_ERROR", e.message, null)
        }
    }
    
    private fun isOverlayVisible(result: MethodChannel.Result) {
        result.success(Live2DOverlayService.isRunning)
    }
    
    // ============================================================================
    // ============================================================================
    
    private fun loadModel(call: MethodCall, result: MethodChannel.Result) {
        val path = call.argument<String>("path")
        if (path == null) {
            result.error("INVALID_ARGUMENT", "path is required", null)
            return
        }
        
        try {
            Live2DLogger.Model.d("모델 로드 요청", path)
            
            val intent = Intent(context, Live2DOverlayService::class.java).apply {
                action = Live2DOverlayService.ACTION_LOAD_MODEL
                putExtra(Live2DOverlayService.EXTRA_MODEL_PATH, path)
            }
            context.startService(intent)
            
            result.success(true)
        } catch (e: Exception) {
            Live2DLogger.e("모델 로드 실패", e)
            result.error("MODEL_ERROR", e.message, null)
        }
    }
    
    private fun unloadModel(result: MethodChannel.Result) {
        try {
            val intent = Intent(context, Live2DOverlayService::class.java).apply {
                action = Live2DOverlayService.ACTION_UNLOAD_MODEL
            }
            context.startService(intent)
            
            result.success(true)
        } catch (e: Exception) {
            Live2DLogger.e("모델 언로드 실패", e)
            result.error("MODEL_ERROR", e.message, null)
        }
    }
    
    private fun playMotion(call: MethodCall, result: MethodChannel.Result) {
        val group = call.argument<String>("group") ?: ""
        val index = call.argument<Int>("index") ?: 0
        val priority = call.argument<Int>("priority") ?: 2
        
        try {
            val intent = Intent(context, Live2DOverlayService::class.java).apply {
                action = Live2DOverlayService.ACTION_PLAY_MOTION
                putExtra(Live2DOverlayService.EXTRA_MOTION_GROUP, group)
                putExtra(Live2DOverlayService.EXTRA_MOTION_INDEX, index)
                putExtra(Live2DOverlayService.EXTRA_MOTION_PRIORITY, priority)
            }
            context.startService(intent)
            
            result.success(true)
        } catch (e: Exception) {
            Live2DLogger.e("모션 재생 실패", e)
            result.error("MOTION_ERROR", e.message, null)
        }
    }
    
    private fun setExpression(call: MethodCall, result: MethodChannel.Result) {
        val id = call.argument<String>("id")
        if (id == null) {
            result.error("INVALID_ARGUMENT", "id is required", null)
            return
        }
        
        try {
            val intent = Intent(context, Live2DOverlayService::class.java).apply {
                action = Live2DOverlayService.ACTION_SET_EXPRESSION
                putExtra(Live2DOverlayService.EXTRA_EXPRESSION_ID, id)
            }
            context.startService(intent)
            
            result.success(true)
        } catch (e: Exception) {
            Live2DLogger.e("표정 설정 실패", e)
            result.error("EXPRESSION_ERROR", e.message, null)
        }
    }
    
    private fun setRandomExpression(result: MethodChannel.Result) {
        try {
            val intent = Intent(context, Live2DOverlayService::class.java).apply {
                action = Live2DOverlayService.ACTION_RANDOM_EXPRESSION
            }
            context.startService(intent)
            
            result.success(true)
        } catch (e: Exception) {
            Live2DLogger.e("랜덤 표정 설정 실패", e)
            result.error("EXPRESSION_ERROR", e.message, null)
        }
    }
    
    // ============================================================================
    // ============================================================================
    
    private fun setScale(call: MethodCall, result: MethodChannel.Result) {
        val scale = call.argument<Double>("scale")?.toFloat() ?: 1f
        
        try {
            val intent = Intent(context, Live2DOverlayService::class.java).apply {
                action = Live2DOverlayService.ACTION_SET_SCALE
                putExtra(Live2DOverlayService.EXTRA_SCALE, scale)
            }
            context.startService(intent)
            
            result.success(true)
        } catch (e: Exception) {
            Live2DLogger.e("스케일 설정 실패", e)
            result.error("DISPLAY_ERROR", e.message, null)
        }
    }
    
    private fun setOpacity(call: MethodCall, result: MethodChannel.Result) {
        val opacity = call.argument<Double>("opacity")?.toFloat() ?: 1f
        
        try {
            val intent = Intent(context, Live2DOverlayService::class.java).apply {
                action = Live2DOverlayService.ACTION_SET_OPACITY
                putExtra(Live2DOverlayService.EXTRA_OPACITY, opacity)
            }
            context.startService(intent)
            
            result.success(true)
        } catch (e: Exception) {
            Live2DLogger.e("투명도 설정 실패", e)
            result.error("DISPLAY_ERROR", e.message, null)
        }
    }
    
    private fun setTouchThroughEnabled(call: MethodCall, result: MethodChannel.Result) {
        val enabled = call.argument<Boolean>("enabled") ?: true
        
        try {
            val intent = Intent(context, Live2DOverlayService::class.java).apply {
                action = Live2DOverlayService.ACTION_SET_TOUCH_THROUGH
                putExtra(Live2DOverlayService.EXTRA_TOUCH_THROUGH, enabled)
            }
            context.startService(intent)
            result.success(true)
        } catch (e: Exception) {
            Live2DLogger.e("터치스루 설정 실패", e)
            result.error("TOUCH_ERROR", e.message, null)
        }
    }
    
    private fun setTouchThroughAlpha(call: MethodCall, result: MethodChannel.Result) {
        val alpha = call.argument<Int>("alpha") ?: 80
        
        try {
            val intent = Intent(context, Live2DOverlayService::class.java).apply {
                action = Live2DOverlayService.ACTION_SET_TOUCH_THROUGH_ALPHA
                putExtra(Live2DOverlayService.EXTRA_TOUCH_THROUGH_ALPHA, alpha)
            }
            context.startService(intent)
            result.success(true)
        } catch (e: Exception) {
            Live2DLogger.e("터치스루 알파 설정 실패", e)
            result.error("TOUCH_ERROR", e.message, null)
        }
    }
    
    private fun setCharacterOpacity(call: MethodCall, result: MethodChannel.Result) {
        val opacity = call.argument<Double>("opacity")?.toFloat() ?: 1f
        
        try {
            val intent = Intent(context, Live2DOverlayService::class.java).apply {
                action = Live2DOverlayService.ACTION_SET_CHARACTER_OPACITY
                putExtra(Live2DOverlayService.EXTRA_CHARACTER_OPACITY, opacity)
            }
            context.startService(intent)
            result.success(true)
        } catch (e: Exception) {
            Live2DLogger.e("캐릭터 투명도 설정 실패", e)
            result.error("DISPLAY_ERROR", e.message, null)
        }
    }

    private fun setNotificationResponse(call: MethodCall, result: MethodChannel.Result) {
        val message = call.argument<String>("message")
        if (message.isNullOrBlank()) {
            result.error("INVALID_ARGUMENT", "message is required", null)
            return
        }
        val sessionId = call.argument<String>("sessionId")

        try {
            val intent = Intent(context, Live2DOverlayService::class.java).apply {
                action = Live2DOverlayService.ACTION_NOTIFICATION_SET_RESPONSE
                putExtra(Live2DOverlayService.EXTRA_NOTIFICATION_MESSAGE, message)
                if (!sessionId.isNullOrBlank()) {
                    putExtra(Live2DOverlayService.EXTRA_NOTIFICATION_SESSION_ID, sessionId)
                }
            }
            context.startService(intent)
            result.success(true)
        } catch (e: Exception) {
            Live2DLogger.e("알림 응답 텍스트 설정 실패", e)
            result.error("NOTIFICATION_ERROR", e.message, null)
        }
    }

    private fun setNotificationError(call: MethodCall, result: MethodChannel.Result) {
        val errorMessage = call.argument<String>("error")
        if (errorMessage.isNullOrBlank()) {
            result.error("INVALID_ARGUMENT", "error is required", null)
            return
        }
        val sessionId = call.argument<String>("sessionId")

        try {
            val intent = Intent(context, Live2DOverlayService::class.java).apply {
                action = Live2DOverlayService.ACTION_NOTIFICATION_SET_ERROR
                putExtra(Live2DOverlayService.EXTRA_NOTIFICATION_ERROR, errorMessage)
                if (!sessionId.isNullOrBlank()) {
                    putExtra(Live2DOverlayService.EXTRA_NOTIFICATION_SESSION_ID, sessionId)
                }
            }
            context.startService(intent)
            result.success(true)
        } catch (e: Exception) {
            Live2DLogger.e("알림 오류 텍스트 설정 실패", e)
            result.error("NOTIFICATION_ERROR", e.message, null)
        }
    }
    
    private fun setEditMode(call: MethodCall, result: MethodChannel.Result) {
        val enabled = call.argument<Boolean>("enabled") ?: false
        
        try {
            val intent = Intent(context, Live2DOverlayService::class.java).apply {
                action = Live2DOverlayService.ACTION_SET_EDIT_MODE
                putExtra(Live2DOverlayService.EXTRA_EDIT_MODE, enabled)
            }
            context.startService(intent)
            result.success(true)
        } catch (e: Exception) {
            Live2DLogger.e("편집 모드 설정 실패", e)
            result.error("EDIT_MODE_ERROR", e.message, null)
        }
    }
    
    private fun setCharacterPinned(call: MethodCall, result: MethodChannel.Result) {
        val enabled = call.argument<Boolean>("enabled") ?: false
        
        try {
            val intent = Intent(context, Live2DOverlayService::class.java).apply {
                action = Live2DOverlayService.ACTION_SET_CHARACTER_PINNED
                putExtra(Live2DOverlayService.EXTRA_CHARACTER_PINNED, enabled)
            }
            context.startService(intent)
            result.success(true)
        } catch (e: Exception) {
            Live2DLogger.e("캐릭터 고정 설정 실패", e)
            result.error("EDIT_MODE_ERROR", e.message, null)
        }
    }
    
    private fun setRelativeScale(call: MethodCall, result: MethodChannel.Result) {
        val scale = call.argument<Double>("scale")?.toFloat() ?: 1f
        
        try {
            val intent = Intent(context, Live2DOverlayService::class.java).apply {
                action = Live2DOverlayService.ACTION_SET_RELATIVE_SCALE
                putExtra(Live2DOverlayService.EXTRA_RELATIVE_SCALE, scale)
            }
            context.startService(intent)
            result.success(true)
        } catch (e: Exception) {
            Live2DLogger.e("상대 스케일 설정 실패", e)
            result.error("EDIT_MODE_ERROR", e.message, null)
        }
    }
    
    private fun setCharacterOffset(call: MethodCall, result: MethodChannel.Result) {
        val x = call.argument<Double>("x")?.toFloat() ?: 0f
        val y = call.argument<Double>("y")?.toFloat() ?: 0f
        
        try {
            val intent = Intent(context, Live2DOverlayService::class.java).apply {
                action = Live2DOverlayService.ACTION_SET_CHARACTER_OFFSET
                putExtra(Live2DOverlayService.EXTRA_OFFSET_X, x)
                putExtra(Live2DOverlayService.EXTRA_OFFSET_Y, y)
            }
            context.startService(intent)
            result.success(true)
        } catch (e: Exception) {
            Live2DLogger.e("캐릭터 오프셋 설정 실패", e)
            result.error("EDIT_MODE_ERROR", e.message, null)
        }
    }
    
    private fun setCharacterRotation(call: MethodCall, result: MethodChannel.Result) {
        val degrees = call.argument<Int>("degrees") ?: 0
        
        try {
            val intent = Intent(context, Live2DOverlayService::class.java).apply {
                action = Live2DOverlayService.ACTION_SET_CHARACTER_ROTATION
                putExtra(Live2DOverlayService.EXTRA_ROTATION, degrees)
            }
            context.startService(intent)
            result.success(true)
        } catch (e: Exception) {
            Live2DLogger.e("캐릭터 회전 설정 실패", e)
            result.error("EDIT_MODE_ERROR", e.message, null)
        }
    }

    private fun getDisplayState(result: MethodChannel.Result) {
        try {
            val state = Live2DOverlayService.getDisplayState(context)
            result.success(state)
        } catch (e: Exception) {
            Live2DLogger.e("디스플레이 상태 조회 실패", e)
            result.error("DISPLAY_STATE_ERROR", e.message, null)
        }
    }

    private fun setParameter(call: MethodCall, result: MethodChannel.Result) {
        val id = call.argument<String>("id")
        val value = call.argument<Double>("value")?.toFloat() ?: 0f
        val duration = call.argument<Int>("durationMs") ?: 0
        if (id.isNullOrBlank()) {
            result.error("INVALID_ARGUMENT", "id is required", null)
            return
        }
        try {
            val intent = Intent(context, Live2DOverlayService::class.java).apply {
                action = Live2DOverlayService.ACTION_SET_PARAMETER
                putExtra(Live2DOverlayService.EXTRA_PARAMETER_ID, id)
                putExtra(Live2DOverlayService.EXTRA_PARAMETER_VALUE, value)
                putExtra(Live2DOverlayService.EXTRA_PARAMETER_DURATION, duration)
            }
            context.startService(intent)
            result.success(true)
        } catch (e: Exception) {
            Live2DLogger.e("파라미터 설정 실패", e)
            result.error("PARAM_ERROR", e.message, null)
        }
    }

    private fun getParameter(call: MethodCall, result: MethodChannel.Result) {
        val id = call.argument<String>("id")
        if (id.isNullOrBlank()) {
            result.error("INVALID_ARGUMENT", "id is required", null)
            return
        }
        try {
            val value = Live2DNativeBridge.nativeGetParameterValue(id)
            result.success(value.toDouble())
        } catch (e: Exception) {
            Live2DLogger.e("파라미터 조회 실패", e)
            result.error("PARAM_ERROR", e.message, null)
        }
    }

    private fun getParameterIds(result: MethodChannel.Result) {
        try {
            val ids = Live2DNativeBridge.nativeGetParameterIds()
            result.success(ids.toList())
        } catch (e: Exception) {
            Live2DLogger.e("파라미터 ID 조회 실패", e)
            result.error("PARAM_ERROR", e.message, null)
        }
    }
    
    private fun setPosition(call: MethodCall, result: MethodChannel.Result) {
        val x = (call.argument<Double>("x") ?: call.argument<Int>("x")?.toDouble() ?: 0.0).toInt()
        val y = (call.argument<Double>("y") ?: call.argument<Int>("y")?.toDouble() ?: 0.0).toInt()
        
        try {
            val intent = Intent(context, Live2DOverlayService::class.java).apply {
                action = Live2DOverlayService.ACTION_SET_POSITION
                putExtra(Live2DOverlayService.EXTRA_POSITION_X, x)
                putExtra(Live2DOverlayService.EXTRA_POSITION_Y, y)
            }
            context.startService(intent)
            
            result.success(true)
        } catch (e: Exception) {
            Live2DLogger.e("위치 설정 실패", e)
            result.error("DISPLAY_ERROR", e.message, null)
        }
    }
    
    private fun setSize(call: MethodCall, result: MethodChannel.Result) {
        val width = call.argument<Int>("width") ?: 300
        val height = call.argument<Int>("height") ?: 400
        
        try {
            val intent = Intent(context, Live2DOverlayService::class.java).apply {
                action = Live2DOverlayService.ACTION_SET_SIZE
                putExtra(Live2DOverlayService.EXTRA_WIDTH, width)
                putExtra(Live2DOverlayService.EXTRA_HEIGHT, height)
            }
            context.startService(intent)
            
            result.success(true)
        } catch (e: Exception) {
            Live2DLogger.e("크기 설정 실패", e)
            result.error("DISPLAY_ERROR", e.message, null)
        }
    }
    
    // ============================================================================
    // ============================================================================
    
    private fun setEyeBlink(call: MethodCall, result: MethodChannel.Result) {
        val enabled = call.argument<Boolean>("enabled") ?: true
        
        try {
            val intent = Intent(context, Live2DOverlayService::class.java).apply {
                action = Live2DOverlayService.ACTION_SET_EYE_BLINK
                putExtra(Live2DOverlayService.EXTRA_ENABLED, enabled)
            }
            context.startService(intent)
            
            result.success(true)
        } catch (e: Exception) {
            Live2DLogger.e("눈 깜빡임 설정 실패", e)
            result.error("BEHAVIOR_ERROR", e.message, null)
        }
    }
    
    private fun setBreathing(call: MethodCall, result: MethodChannel.Result) {
        val enabled = call.argument<Boolean>("enabled") ?: true
        
        try {
            val intent = Intent(context, Live2DOverlayService::class.java).apply {
                action = Live2DOverlayService.ACTION_SET_BREATHING
                putExtra(Live2DOverlayService.EXTRA_ENABLED, enabled)
            }
            context.startService(intent)
            
            result.success(true)
        } catch (e: Exception) {
            Live2DLogger.e("호흡 설정 실패", e)
            result.error("BEHAVIOR_ERROR", e.message, null)
        }
    }
    
    private fun setLookAt(call: MethodCall, result: MethodChannel.Result) {
        val enabled = call.argument<Boolean>("enabled") ?: true
        
        try {
            val intent = Intent(context, Live2DOverlayService::class.java).apply {
                action = Live2DOverlayService.ACTION_SET_LOOK_AT
                putExtra(Live2DOverlayService.EXTRA_ENABLED, enabled)
            }
            context.startService(intent)
            
            result.success(true)
        } catch (e: Exception) {
            Live2DLogger.e("시선 추적 설정 실패", e)
            result.error("BEHAVIOR_ERROR", e.message, null)
        }
    }
    
    // ============================================================================
    // ============================================================================
    
    private fun sendSignal(call: MethodCall, result: MethodChannel.Result) {
        val signal = call.argument<String>("signal") ?: ""
        val data = call.argument<Map<String, Any>>("data")
        
        try {
            Live2DLogger.d("신호 전송", signal)
            
            val intent = Intent(context, Live2DOverlayService::class.java).apply {
                action = Live2DOverlayService.ACTION_SEND_SIGNAL
                putExtra(Live2DOverlayService.EXTRA_SIGNAL_NAME, signal)
            }
            context.startService(intent)
            
            result.success(true)
        } catch (e: Exception) {
            Live2DLogger.e("신호 전송 실패", e)
            result.error("SIGNAL_ERROR", e.message, null)
        }
    }
    
    // ============================================================================
    // ============================================================================
    
    private fun getMotionGroups(result: MethodChannel.Result) {
        try {
            val modelInfo = Live2DOverlayService.currentModelInfo
            if (modelInfo != null) {
                @Suppress("UNCHECKED_CAST")
                val motionGroups = modelInfo["motionGroups"] as? Map<String, List<String>>
                result.success(motionGroups?.keys?.toList() ?: emptyList<String>())
            } else {
                result.success(emptyList<String>())
            }
        } catch (e: Exception) {
            Live2DLogger.e("모션 그룹 조회 실패", e)
            result.error("INFO_ERROR", e.message, null)
        }
    }
    
    private fun getMotionCount(call: MethodCall, result: MethodChannel.Result) {
        val group = call.argument<String>("group") ?: ""
        
        try {
            val modelInfo = Live2DOverlayService.currentModelInfo
            if (modelInfo != null) {
                @Suppress("UNCHECKED_CAST")
                val motionGroups = modelInfo["motionGroups"] as? Map<String, List<String>>
                val count = motionGroups?.get(group)?.size ?: 0
                result.success(count)
            } else {
                result.success(0)
            }
        } catch (e: Exception) {
            Live2DLogger.e("모션 수 조회 실패", e)
            result.error("INFO_ERROR", e.message, null)
        }
    }

    private fun getMotionNames(call: MethodCall, result: MethodChannel.Result) {
        val group = call.argument<String>("group") ?: ""
        try {
            val modelInfo = Live2DOverlayService.currentModelInfo
            if (modelInfo != null) {
                @Suppress("UNCHECKED_CAST")
                val motionGroups = modelInfo["motionGroups"] as? Map<String, List<String>>
                val names = motionGroups?.get(group) ?: emptyList()
                result.success(names)
            } else {
                result.success(emptyList<String>())
            }
        } catch (e: Exception) {
            Live2DLogger.e("모션 이름 조회 실패", e)
            result.error("INFO_ERROR", e.message, null)
        }
    }
    
    private fun getExpressions(result: MethodChannel.Result) {
        try {
            val modelInfo = Live2DOverlayService.currentModelInfo
            if (modelInfo != null) {
                @Suppress("UNCHECKED_CAST")
                val expressions = modelInfo["expressions"] as? List<String>
                result.success(expressions ?: emptyList<String>())
            } else {
                result.success(emptyList<String>())
            }
        } catch (e: Exception) {
            Live2DLogger.e("표정 목록 조회 실패", e)
            result.error("INFO_ERROR", e.message, null)
        }
    }
    
    private fun getModelInfo(result: MethodChannel.Result) {
        try {
            val modelInfo = Live2DOverlayService.currentModelInfo
            result.success(modelInfo ?: emptyMap<String, Any>())
        } catch (e: Exception) {
            Live2DLogger.e("모델 정보 조회 실패", e)
            result.error("INFO_ERROR", e.message, null)
        }
    }
    
    /**
     */
    private fun analyzeModel(call: MethodCall, result: MethodChannel.Result) {
        val path = call.argument<String>("path")
        if (path == null) {
            result.error("INVALID_ARGUMENT", "path is required", null)
            return
        }
        
        try {
            Live2DLogger.d("모델 분석 요청", path)
            
            val parser = com.example.flutter_application_1.live2d.core.Model3JsonParser(path)
            if (parser.parse()) {
                result.success(parser.getSummary())
            } else {
                result.error("PARSE_ERROR", "Failed to parse model file", null)
            }
        } catch (e: Exception) {
            Live2DLogger.e("모델 분석 실패", e)
            result.error("ANALYZE_ERROR", e.message, null)
        }
    }
    
    // ============================================================================
    // ============================================================================
    
    private fun setTargetFps(call: MethodCall, result: MethodChannel.Result) {
        val fps = call.argument<Int>("fps") ?: 60
        
        try {
            Live2DLogger.d("FPS 설정", "$fps")
            val intent = Intent(context, Live2DOverlayService::class.java).apply {
                action = Live2DOverlayService.ACTION_SET_TARGET_FPS
                putExtra(Live2DOverlayService.EXTRA_TARGET_FPS, fps)
            }
            context.startService(intent)
            result.success(true)
        } catch (e: Exception) {
            Live2DLogger.e("FPS 설정 실패", e)
            result.error("RENDER_ERROR", e.message, null)
        }
    }
    
    private fun setLowPowerMode(call: MethodCall, result: MethodChannel.Result) {
        val enabled = call.argument<Boolean>("enabled") ?: false
        
        try {
            Live2DLogger.d("저전력 모드 설정", "$enabled")
            val intent = Intent(context, Live2DOverlayService::class.java).apply {
                action = Live2DOverlayService.ACTION_SET_LOW_POWER_MODE
                putExtra(Live2DOverlayService.EXTRA_ENABLED, enabled)
            }
            context.startService(intent)
            result.success(true)
        } catch (e: Exception) {
            Live2DLogger.e("저전력 모드 설정 실패", e)
            result.error("RENDER_ERROR", e.message, null)
        }
    }
    
    // ============================================================================
    // ============================================================================
    
    /**
     * 
     */
    private fun getHealthStatus(result: MethodChannel.Result) {
        try {
            val runtime = Runtime.getRuntime()
            val heapUsedMB = (runtime.totalMemory() - runtime.freeMemory()) / 1024 / 1024
            val heapMaxMB = runtime.maxMemory() / 1024 / 1024
            
            val uptimeMs = if (Live2DOverlayService.isRunning && Live2DOverlayService.serviceStartTime > 0) {
                System.currentTimeMillis() - Live2DOverlayService.serviceStartTime
            } else {
                0L
            }
            
            val status = mapOf(
                "service" to mapOf(
                    "isRunning" to Live2DOverlayService.isRunning,
                    "uptimeMs" to uptimeMs,
                    "currentModel" to Live2DOverlayService.currentModelInfo
                ),
                "sdk" to CubismFrameworkManager.getStatusInfo(),
                "memory" to mapOf(
                    "heapUsedMB" to heapUsedMB,
                    "heapMaxMB" to heapMaxMB,
                    "heapUsagePercent" to if (heapMaxMB > 0) (heapUsedMB * 100 / heapMaxMB) else 0
                ),
                "timestamp" to System.currentTimeMillis()
            )
            
            Live2DLogger.d("Health status 조회됨", null)
            result.success(status)
            
        } catch (e: Exception) {
            Live2DLogger.e("Health status 조회 실패", e)
            result.error("HEALTH_ERROR", e.message, null)
        }
    }
    
    /**
     * 
     */
    private fun forceReset(result: MethodChannel.Result) {
        try {
            Live2DLogger.w("강제 재설정 요청", "SDK 및 서비스 재초기화")
            
            if (Live2DOverlayService.isRunning) {
                val hideIntent = Intent(context, Live2DOverlayService::class.java).apply {
                    action = Live2DOverlayService.ACTION_HIDE
                }
                context.startService(hideIntent)
            }
            
            CubismFrameworkManager.reinitialize()
            
            Live2DLogger.i("강제 재설정 완료", null)
            result.success(true)
            
        } catch (e: Exception) {
            Live2DLogger.e("강제 재설정 실패", e)
            result.error("RESET_ERROR", e.message, null)
        }
    }
    
    // ============================================================================
    // ============================================================================
    
    fun dispose() {
        Live2DLogger.d("Method Handler 정리", null)
    }
}

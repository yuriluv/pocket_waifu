package com.example.flutter_application_1.live2d.gesture

import android.graphics.PointF
import android.os.Handler
import android.os.Looper
import android.view.MotionEvent
import com.example.flutter_application_1.live2d.core.Live2DLogger

/**
 * 
 */
class GestureDetectorManager(
    private val config: GestureConfig = GestureConfig(),
    private val onGestureDetected: (GestureResult) -> Unit
) {
    companion object {
        private const val TAG = "GestureDetector"
    }
    
    private val handler = Handler(Looper.getMainLooper())
    
    private val touchPoints = mutableListOf<TouchPoint>()
    private var touchDownTime: Long = 0
    private var touchDownPoint: PointF? = null
    
    private var lastTapTime: Long = 0
    private var lastTapPoint: PointF? = null
    private var tapCount = 0
    
    private var longPressRunnable: Runnable? = null
    private var isLongPressTriggered = false
    
    private var isDragging = false
    
    /**
     * 
     * @return true if the event was consumed
     */
    fun onTouchEvent(event: MotionEvent): Boolean {
        val currentTime = System.currentTimeMillis()
        val currentPoint = PointF(event.x, event.y)
        
        when (event.actionMasked) {
            MotionEvent.ACTION_DOWN -> {
                handleTouchDown(currentPoint, currentTime)
            }
            MotionEvent.ACTION_MOVE -> {
                handleTouchMove(currentPoint, currentTime)
            }
            MotionEvent.ACTION_UP -> {
                handleTouchUp(currentPoint, currentTime)
            }
            MotionEvent.ACTION_CANCEL -> {
                resetState()
            }
        }
        
        return true
    }
    
    /**
     */
    private fun handleTouchDown(point: PointF, time: Long) {
        Live2DLogger.Interaction.d("터치 시작", "(${point.x}, ${point.y})")
        
        touchDownTime = time
        touchDownPoint = point
        touchPoints.clear()
        touchPoints.add(TouchPoint(point.x, point.y, time))
        isDragging = false
        isLongPressTriggered = false
        
        cancelLongPressTimer()
        longPressRunnable = Runnable {
            if (!isDragging) {
                isLongPressTriggered = true
                onGestureDetected(GestureResult(
                    type = GestureType.LONG_PRESS,
                    position = point
                ))
                Live2DLogger.Interaction.i("롱프레스 감지", "(${point.x}, ${point.y})")
            }
        }
        handler.postDelayed(longPressRunnable!!, config.longPressTimeout)
    }
    
    /**
     */
    private fun handleTouchMove(point: PointF, time: Long) {
        val downPoint = touchDownPoint ?: return
        
        val lastPoint = touchPoints.lastOrNull()
        if (lastPoint == null || time - lastPoint.timestamp > 16) {  // ~60fps
            touchPoints.add(TouchPoint(point.x, point.y, time))
        }
        
        val moveDistance = GestureUtils.distance(downPoint, point)
        
        if (moveDistance > config.tapMoveThreshold && !isDragging) {
            isDragging = true
            cancelLongPressTimer()
            Live2DLogger.Interaction.d("드래그 시작", "이동 거리: $moveDistance")
        }
    }
    
    /**
     */
    private fun handleTouchUp(point: PointF, time: Long) {
        cancelLongPressTimer()
        
        val downPoint = touchDownPoint ?: return
        val duration = time - touchDownTime
        val moveDistance = GestureUtils.distance(downPoint, point)
        
        Live2DLogger.Interaction.d("터치 종료", "duration: ${duration}ms, distance: $moveDistance")
        
        if (isLongPressTriggered) {
            resetState()
            return
        }
        
        when {
            isDragging && touchPoints.size > 2 -> {
                analyzeSwipeGesture(point, time)
            }
            
            duration < config.tapTimeout && moveDistance < config.tapMoveThreshold -> {
                handleTap(point, time)
            }
        }
        
        resetState()
    }
    
    /**
     */
    private fun handleTap(point: PointF, time: Long) {
        val timeSinceLastTap = time - lastTapTime
        val distanceFromLastTap = lastTapPoint?.let { GestureUtils.distance(it, point) } ?: Float.MAX_VALUE
        
        if (timeSinceLastTap < config.doubleTapTimeout && 
            distanceFromLastTap < config.doubleTapDistanceThreshold) {
            
            tapCount++
            
            if (config.enablePoke && tapCount >= config.pokeMinTaps) {
                onGestureDetected(GestureResult(
                    type = GestureType.POKE,
                    position = point,
                    extras = mapOf("tapCount" to tapCount)
                ))
                Live2DLogger.Interaction.i("연타(Poke) 감지", "탭 수: $tapCount")
                tapCount = 0
                return
            }
            
            if (tapCount == 2) {
                onGestureDetected(GestureResult(
                    type = GestureType.DOUBLE_TAP,
                    position = point
                ))
                Live2DLogger.Interaction.i("더블탭 감지", "(${point.x}, ${point.y})")
                tapCount = 0
                return
            }
        } else {
            tapCount = 1
        }
        
        lastTapTime = time
        lastTapPoint = point
        
        handler.postDelayed({
            if (tapCount == 1) {
                onGestureDetected(GestureResult(
                    type = GestureType.TAP,
                    position = point
                ))
                Live2DLogger.Interaction.i("탭 감지", "(${point.x}, ${point.y})")
                tapCount = 0
            }
        }, config.doubleTapTimeout)
    }
    
    /**
     */
    private fun analyzeSwipeGesture(endPoint: PointF, endTime: Long) {
        if (touchPoints.size < 2) return
        
        val startPoint = touchPoints.first()
        val endTouchPoint = TouchPoint(endPoint.x, endPoint.y, endTime)
        
        val totalDistance = startPoint.distanceTo(endTouchPoint)
        
        val velocity = GestureUtils.velocity(startPoint, endTouchPoint)
        
        if (config.enableHeadPat) {
            val directionChanges = GestureUtils.countDirectionChanges(touchPoints, GestureUtils.Axis.X)
            
            if (directionChanges >= config.headPatMinDirectionChanges && 
                totalDistance > config.headPatMinDistance) {
                onGestureDetected(GestureResult(
                    type = GestureType.HEAD_PAT,
                    position = endPoint,
                    extras = mapOf("directionChanges" to directionChanges)
                ))
                Live2DLogger.Interaction.i("머리쓰다듬기 감지", "방향전환: $directionChanges")
                return
            }
        }
        
        if (config.enableSwipe && 
            totalDistance > config.swipeMinDistance && 
            velocity > config.swipeMinVelocity) {
            
            val angle = GestureUtils.angle(startPoint.toPointF(), endPoint)
            val swipeDirection = GestureUtils.angleToSwipeDirection(angle, config.swipeAngleTolerance)
            
            if (swipeDirection != null) {
                onGestureDetected(GestureResult(
                    type = swipeDirection,
                    position = endPoint,
                    velocity = velocity,
                    extras = mapOf("angle" to angle)
                ))
                Live2DLogger.Interaction.i("스와이프 감지", "${swipeDirection.name}, 속도: $velocity")
            }
        }
    }
    
    /**
     */
    private fun cancelLongPressTimer() {
        longPressRunnable?.let {
            handler.removeCallbacks(it)
        }
        longPressRunnable = null
    }
    
    /**
     */
    private fun resetState() {
        touchPoints.clear()
        touchDownPoint = null
        isDragging = false
        isLongPressTriggered = false
        cancelLongPressTimer()
    }
    
    /**
     */
    fun updateConfig(newConfig: GestureConfig): GestureDetectorManager {
        return GestureDetectorManager(newConfig, onGestureDetected)
    }
    
    /**
     */
    fun dispose() {
        resetState()
        handler.removeCallbacksAndMessages(null)
    }
}

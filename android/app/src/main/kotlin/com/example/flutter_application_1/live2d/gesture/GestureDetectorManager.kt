package com.example.flutter_application_1.live2d.gesture

import android.graphics.PointF
import android.os.Handler
import android.os.Looper
import android.view.MotionEvent
import com.example.flutter_application_1.live2d.core.Live2DLogger

/**
 * 제스처 감지 관리자
 * 
 * 터치 이벤트를 분석하여 다양한 제스처를 감지합니다.
 * - 탭, 더블탭, 롱프레스
 * - 스와이프 (상/하/좌/우)
 * - 머리 쓰다듬기 (좌우 반복)
 * - 연타 (poke)
 */
class GestureDetectorManager(
    private val config: GestureConfig = GestureConfig(),
    private val onGestureDetected: (GestureResult) -> Unit
) {
    companion object {
        private const val TAG = "GestureDetector"
    }
    
    // 핸들러 (타임아웃 처리용)
    private val handler = Handler(Looper.getMainLooper())
    
    // 터치 추적
    private val touchPoints = mutableListOf<TouchPoint>()
    private var touchDownTime: Long = 0
    private var touchDownPoint: PointF? = null
    
    // 탭 감지
    private var lastTapTime: Long = 0
    private var lastTapPoint: PointF? = null
    private var tapCount = 0
    
    // 롱프레스 감지
    private var longPressRunnable: Runnable? = null
    private var isLongPressTriggered = false
    
    // 드래그 상태
    private var isDragging = false
    
    /**
     * 터치 이벤트 처리
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
     * 터치 시작 처리
     */
    private fun handleTouchDown(point: PointF, time: Long) {
        Live2DLogger.Interaction.d("터치 시작", "(${point.x}, ${point.y})")
        
        touchDownTime = time
        touchDownPoint = point
        touchPoints.clear()
        touchPoints.add(TouchPoint(point.x, point.y, time))
        isDragging = false
        isLongPressTriggered = false
        
        // 롱프레스 타이머 시작
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
     * 터치 이동 처리
     */
    private fun handleTouchMove(point: PointF, time: Long) {
        val downPoint = touchDownPoint ?: return
        
        // 터치 포인트 기록 (간격 두고)
        val lastPoint = touchPoints.lastOrNull()
        if (lastPoint == null || time - lastPoint.timestamp > 16) {  // ~60fps
            touchPoints.add(TouchPoint(point.x, point.y, time))
        }
        
        // 이동 거리 체크
        val moveDistance = GestureUtils.distance(downPoint, point)
        
        if (moveDistance > config.tapMoveThreshold && !isDragging) {
            isDragging = true
            cancelLongPressTimer()
            Live2DLogger.Interaction.d("드래그 시작", "이동 거리: $moveDistance")
        }
    }
    
    /**
     * 터치 종료 처리
     */
    private fun handleTouchUp(point: PointF, time: Long) {
        cancelLongPressTimer()
        
        val downPoint = touchDownPoint ?: return
        val duration = time - touchDownTime
        val moveDistance = GestureUtils.distance(downPoint, point)
        
        Live2DLogger.Interaction.d("터치 종료", "duration: ${duration}ms, distance: $moveDistance")
        
        // 롱프레스가 이미 감지되었으면 무시
        if (isLongPressTriggered) {
            resetState()
            return
        }
        
        when {
            // 드래그 제스처 분석
            isDragging && touchPoints.size > 2 -> {
                analyzeSwipeGesture(point, time)
            }
            
            // 탭 제스처
            duration < config.tapTimeout && moveDistance < config.tapMoveThreshold -> {
                handleTap(point, time)
            }
        }
        
        resetState()
    }
    
    /**
     * 탭 처리 (싱글탭, 더블탭, 연타)
     */
    private fun handleTap(point: PointF, time: Long) {
        val timeSinceLastTap = time - lastTapTime
        val distanceFromLastTap = lastTapPoint?.let { GestureUtils.distance(it, point) } ?: Float.MAX_VALUE
        
        // 연속 탭 체크
        if (timeSinceLastTap < config.doubleTapTimeout && 
            distanceFromLastTap < config.doubleTapDistanceThreshold) {
            
            tapCount++
            
            // 연타 (poke) 체크
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
            
            // 더블탭
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
            // 새로운 탭 시퀀스
            tapCount = 1
        }
        
        lastTapTime = time
        lastTapPoint = point
        
        // 약간의 딜레이 후 싱글탭 전송 (더블탭 대기)
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
     * 스와이프/머리쓰다듬기 분석
     */
    private fun analyzeSwipeGesture(endPoint: PointF, endTime: Long) {
        if (touchPoints.size < 2) return
        
        val startPoint = touchPoints.first()
        val endTouchPoint = TouchPoint(endPoint.x, endPoint.y, endTime)
        
        // 전체 이동 거리
        val totalDistance = startPoint.distanceTo(endTouchPoint)
        
        // 속도 계산
        val velocity = GestureUtils.velocity(startPoint, endTouchPoint)
        
        // 머리 쓰다듬기 체크 (좌우 방향 전환 횟수)
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
        
        // 스와이프 체크
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
     * 롱프레스 타이머 취소
     */
    private fun cancelLongPressTimer() {
        longPressRunnable?.let {
            handler.removeCallbacks(it)
        }
        longPressRunnable = null
    }
    
    /**
     * 상태 초기화
     */
    private fun resetState() {
        touchPoints.clear()
        touchDownPoint = null
        isDragging = false
        isLongPressTriggered = false
        cancelLongPressTimer()
    }
    
    /**
     * 설정 업데이트
     */
    fun updateConfig(newConfig: GestureConfig): GestureDetectorManager {
        return GestureDetectorManager(newConfig, onGestureDetected)
    }
    
    /**
     * 리소스 정리
     */
    fun dispose() {
        resetState()
        handler.removeCallbacksAndMessages(null)
    }
}

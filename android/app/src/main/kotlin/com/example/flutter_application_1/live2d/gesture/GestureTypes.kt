package com.example.flutter_application_1.live2d.gesture

import android.graphics.PointF
import kotlin.math.abs
import kotlin.math.atan2
import kotlin.math.sqrt

/**
 * 제스처 유형
 */
enum class GestureType {
    TAP,
    DOUBLE_TAP,
    LONG_PRESS,
    SWIPE_UP,
    SWIPE_DOWN,
    SWIPE_LEFT,
    SWIPE_RIGHT,
    HEAD_PAT,
    POKE,
    UNKNOWN
}

/**
 * 제스처 감지 결과
 */
data class GestureResult(
    val type: GestureType,
    val position: PointF,
    val velocity: Float = 0f,
    val extras: Map<String, Any> = emptyMap()
) {
    fun toMap(): Map<String, Any> {
        return mapOf(
            "type" to type.name.lowercase(),
            "x" to position.x,
            "y" to position.y,
            "velocity" to velocity,
            "timestamp" to System.currentTimeMillis()
        ) + extras
    }
}

/**
 * 제스처 설정
 */
data class GestureConfig(
    // 탭 인식 설정
    val tapTimeout: Long = 300L,                    // 탭으로 인식할 최대 시간 (ms)
    val tapMoveThreshold: Float = 20f,              // 탭으로 인식할 최대 이동 거리 (px)
    
    // 더블탭 인식 설정
    val doubleTapTimeout: Long = 300L,              // 더블탭 간격 최대 시간 (ms)
    val doubleTapDistanceThreshold: Float = 50f,    // 더블탭 위치 허용 오차 (px)
    
    // 롱프레스 인식 설정
    val longPressTimeout: Long = 500L,              // 롱프레스 인식 시간 (ms)
    val longPressMoveThreshold: Float = 20f,        // 롱프레스 중 허용 이동 거리 (px)
    
    // 스와이프 인식 설정
    val swipeMinDistance: Float = 100f,             // 스와이프 최소 거리 (px)
    val swipeMinVelocity: Float = 500f,             // 스와이프 최소 속도 (px/s)
    val swipeAngleTolerance: Float = 30f,           // 방향 인식 각도 허용 오차 (도)
    
    // 머리 쓰다듬기 인식 설정
    val headPatMinDirectionChanges: Int = 3,        // 방향 전환 최소 횟수
    val headPatMinDistance: Float = 50f,            // 최소 이동 거리 (px)
    
    // 찌르기 (연타) 인식 설정
    val pokeMinTaps: Int = 3,                       // 연타로 인식할 최소 탭 수
    val pokeMaxInterval: Long = 150L,               // 연타 간격 최대 시간 (ms)
    
    // 기능 활성화
    val enableSwipe: Boolean = true,
    val enableHeadPat: Boolean = true,
    val enablePoke: Boolean = true
)

/**
 * 터치 포인트 기록
 */
data class TouchPoint(
    val x: Float,
    val y: Float,
    val timestamp: Long
) {
    fun toPointF() = PointF(x, y)
    
    fun distanceTo(other: TouchPoint): Float {
        val dx = x - other.x
        val dy = y - other.y
        return sqrt(dx * dx + dy * dy)
    }
}

/**
 * 제스처 분석을 위한 유틸리티
 */
object GestureUtils {
    
    /**
     * 두 점 사이의 거리
     */
    fun distance(p1: PointF, p2: PointF): Float {
        val dx = p2.x - p1.x
        val dy = p2.y - p1.y
        return sqrt(dx * dx + dy * dy)
    }
    
    /**
     * 두 점 사이의 각도 (도)
     * 0도 = 오른쪽, 90도 = 아래쪽
     */
    fun angle(from: PointF, to: PointF): Float {
        val dx = to.x - from.x
        val dy = to.y - from.y
        return Math.toDegrees(atan2(dy.toDouble(), dx.toDouble())).toFloat()
    }
    
    /**
     * 각도를 스와이프 방향으로 변환
     */
    fun angleToSwipeDirection(angle: Float, tolerance: Float): GestureType? {
        // 각도 정규화 (-180 ~ 180)
        val normalizedAngle = ((angle % 360) + 360) % 360
        
        return when {
            // 오른쪽: -tolerance ~ +tolerance (0도 기준)
            normalizedAngle <= tolerance || normalizedAngle >= 360 - tolerance -> GestureType.SWIPE_RIGHT
            
            // 아래쪽: 90 - tolerance ~ 90 + tolerance
            normalizedAngle in (90 - tolerance)..(90 + tolerance) -> GestureType.SWIPE_DOWN
            
            // 왼쪽: 180 - tolerance ~ 180 + tolerance
            normalizedAngle in (180 - tolerance)..(180 + tolerance) -> GestureType.SWIPE_LEFT
            
            // 위쪽: 270 - tolerance ~ 270 + tolerance
            normalizedAngle in (270 - tolerance)..(270 + tolerance) -> GestureType.SWIPE_UP
            
            else -> null
        }
    }
    
    /**
     * 속도 계산 (px/s)
     */
    fun velocity(p1: TouchPoint, p2: TouchPoint): Float {
        val dist = p1.distanceTo(p2)
        val timeMs = abs(p2.timestamp - p1.timestamp)
        return if (timeMs > 0) dist * 1000f / timeMs else 0f
    }
    
    /**
     * 방향 전환 횟수 계산 (머리 쓰다듬기 감지용)
     */
    fun countDirectionChanges(points: List<TouchPoint>, axis: Axis = Axis.X): Int {
        if (points.size < 3) return 0
        
        var changes = 0
        var lastDirection = 0
        
        for (i in 1 until points.size) {
            val delta = when (axis) {
                Axis.X -> points[i].x - points[i - 1].x
                Axis.Y -> points[i].y - points[i - 1].y
            }
            
            val currentDirection = when {
                delta > 0 -> 1
                delta < 0 -> -1
                else -> 0
            }
            
            if (currentDirection != 0 && currentDirection != lastDirection && lastDirection != 0) {
                changes++
            }
            
            if (currentDirection != 0) {
                lastDirection = currentDirection
            }
        }
        
        return changes
    }
    
    enum class Axis { X, Y }
}

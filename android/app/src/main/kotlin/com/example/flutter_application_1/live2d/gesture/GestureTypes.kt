package com.example.flutter_application_1.live2d.gesture

import android.graphics.PointF
import kotlin.math.abs
import kotlin.math.atan2
import kotlin.math.sqrt

/**
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
 */
data class GestureConfig(
    val tapTimeout: Long = 300L,
    val tapMoveThreshold: Float = 20f,
    
    val doubleTapTimeout: Long = 300L,
    val doubleTapDistanceThreshold: Float = 50f,
    
    val longPressTimeout: Long = 500L,
    val longPressMoveThreshold: Float = 20f,
    
    val swipeMinDistance: Float = 100f,
    val swipeMinVelocity: Float = 500f,
    val swipeAngleTolerance: Float = 30f,
    
    val headPatMinDirectionChanges: Int = 3,
    val headPatMinDistance: Float = 50f,
    
    val pokeMinTaps: Int = 3,
    val pokeMaxInterval: Long = 150L,
    
    val enableSwipe: Boolean = true,
    val enableHeadPat: Boolean = true,
    val enablePoke: Boolean = true
)

/**
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
 */
object GestureUtils {
    
    /**
     */
    fun distance(p1: PointF, p2: PointF): Float {
        val dx = p2.x - p1.x
        val dy = p2.y - p1.y
        return sqrt(dx * dx + dy * dy)
    }
    
    /**
     */
    fun angle(from: PointF, to: PointF): Float {
        val dx = to.x - from.x
        val dy = to.y - from.y
        return Math.toDegrees(atan2(dy.toDouble(), dx.toDouble())).toFloat()
    }
    
    /**
     */
    fun angleToSwipeDirection(angle: Float, tolerance: Float): GestureType? {
        val normalizedAngle = ((angle % 360) + 360) % 360
        
        return when {
            normalizedAngle <= tolerance || normalizedAngle >= 360 - tolerance -> GestureType.SWIPE_RIGHT
            
            normalizedAngle in (90 - tolerance)..(90 + tolerance) -> GestureType.SWIPE_DOWN
            
            normalizedAngle in (180 - tolerance)..(180 + tolerance) -> GestureType.SWIPE_LEFT
            
            normalizedAngle in (270 - tolerance)..(270 + tolerance) -> GestureType.SWIPE_UP
            
            else -> null
        }
    }
    
    /**
     */
    fun velocity(p1: TouchPoint, p2: TouchPoint): Float {
        val dist = p1.distanceTo(p2)
        val timeMs = abs(p2.timestamp - p1.timestamp)
        return if (timeMs > 0) dist * 1000f / timeMs else 0f
    }
    
    /**
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

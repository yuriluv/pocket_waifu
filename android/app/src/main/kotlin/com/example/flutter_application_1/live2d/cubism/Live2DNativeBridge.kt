package com.example.flutter_application_1.live2d.cubism

import com.example.flutter_application_1.live2d.core.Live2DLogger

object Live2DNativeBridge {
    private const val TAG = "Live2DNativeBridge"
    private const val JNI_LIB_NAME = "live2d_jni"

    @Volatile private var isLoaded = false

    @Synchronized
    fun ensureLoaded(): Boolean {
        if (isLoaded) return true

        return try {
            System.loadLibrary(JNI_LIB_NAME)
            isLoaded = true
            Live2DLogger.i("$TAG: [Phase7-2] JNI library loaded", "lib$JNI_LIB_NAME.so")
            true
        } catch (e: UnsatisfiedLinkError) {
            Live2DLogger.e("$TAG: [Phase7-2] Failed to load JNI library", e)
            false
        }
    }

    fun isNativeAvailable(): Boolean = isLoaded || ensureLoaded()

    fun safeSetParameterValue(paramId: String, value: Float): Boolean {
        if (!isNativeAvailable()) return false
        return try {
            nativeSetParameterValue(paramId, value)
            true
        } catch (t: Throwable) {
            Live2DLogger.e("$TAG: nativeSetParameterValue failed", t)
            false
        }
    }

    fun safeGetParameterValue(paramId: String): Float? {
        if (!isNativeAvailable()) return null
        return try {
            nativeGetParameterValue(paramId)
        } catch (t: Throwable) {
            Live2DLogger.e("$TAG: nativeGetParameterValue failed", t)
            null
        }
    }

    fun safeGetParameterIds(): Array<String> {
        if (!isNativeAvailable()) return emptyArray()
        return try {
            nativeGetParameterIds()
        } catch (t: Throwable) {
            Live2DLogger.e("$TAG: nativeGetParameterIds failed", t)
            emptyArray()
        }
    }

    external fun nativeSetAssetManager(assetManager: android.content.res.AssetManager)
    external fun nativeInitializeFramework(): Boolean
    external fun nativeGetVersion(): Int
    external fun nativeDisposeFramework()

    external fun nativeCreateModel(mocPath: String): Boolean
    external fun nativeGetDrawableCount(): Int
    external fun nativeGetParameterCount(): Int
    external fun nativeGetPartCount(): Int
    external fun nativeGetCanvasWidth(): Float
    external fun nativeGetCanvasHeight(): Float

    external fun nativeCreateRenderer(): Boolean
    external fun nativeBindTexture(index: Int, textureId: Int)

    external fun nativeUpdate()
    external fun nativeDraw(mvp: FloatArray)

    external fun nativeReleaseModel()

    external fun nativeSetParameterValue(paramId: String, value: Float)
    external fun nativeGetParameterValue(paramId: String): Float
    external fun nativeGetParameterIds(): Array<String>
}

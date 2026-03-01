package com.example.flutter_application_1

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.PixelFormat
import android.hardware.display.DisplayManager
import android.hardware.display.VirtualDisplay
import android.media.ImageReader
import android.media.projection.MediaProjection
import android.media.projection.MediaProjectionManager
import android.os.Build
import android.util.Base64
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream

class ScreenCapturePlugin(
    private val context: Context,
    private val runOnUiThread: (Runnable) -> Unit,
) {
    companion object {
        const val REQUEST_CODE = 1002
    }

    private val mediaProjectionManager =
        context.getSystemService(Context.MEDIA_PROJECTION_SERVICE) as? MediaProjectionManager
    private var mediaProjection: MediaProjection? = null
    private var projectionResultCode: Int? = null
    private var projectionResultData: Intent? = null
    private var pendingPermissionResult: MethodChannel.Result? = null
    private var pendingCaptureResult: MethodChannel.Result? = null

    fun hasPermission(): Boolean {
        return projectionResultCode == Activity.RESULT_OK && projectionResultData != null
    }

    fun isAvailable(): Boolean {
        if (isProbablyEmulator()) {
            return false
        }
        return mediaProjectionManager != null
    }

    fun requestPermission(
        result: MethodChannel.Result,
        launchPermission: (Intent, Int) -> Unit,
    ) {
        if (hasPermission()) {
            result.success(true)
            return
        }

        val manager = mediaProjectionManager
        if (manager == null) {
            result.error("UNAVAILABLE", "MediaProjectionManager is unavailable", null)
            return
        }

        pendingPermissionResult = result
        launchPermission(manager.createScreenCaptureIntent(), REQUEST_CODE)
    }

    fun captureScreen(
        result: MethodChannel.Result,
        launchPermission: (Intent, Int) -> Unit,
    ) {
        if (!hasPermission()) {
            val manager = mediaProjectionManager
            if (manager == null) {
                result.error("UNAVAILABLE", "MediaProjectionManager is unavailable", null)
                return
            }
            pendingCaptureResult = result
            launchPermission(manager.createScreenCaptureIntent(), REQUEST_CODE)
            return
        }
        captureWithPermission(result)
    }

    fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != REQUEST_CODE) {
            return false
        }

        val ok = resultCode == Activity.RESULT_OK && data != null
        if (ok) {
            projectionResultCode = resultCode
            projectionResultData = data
            pendingPermissionResult?.success(true)
            pendingPermissionResult = null

            val captureResult = pendingCaptureResult
            pendingCaptureResult = null
            if (captureResult != null) {
                captureWithPermission(captureResult)
            }
            return true
        }

        pendingPermissionResult?.success(false)
        pendingPermissionResult = null
        pendingCaptureResult?.error(
            "PERMISSION_DENIED",
            "Screen capture permission denied",
            null,
        )
        pendingCaptureResult = null
        return true
    }

    fun release() {
        mediaProjection?.stop()
        mediaProjection = null
        projectionResultCode = null
        projectionResultData = null
    }

    private fun captureWithPermission(result: MethodChannel.Result) {
        val code = projectionResultCode
        val data = projectionResultData
        val manager = mediaProjectionManager
        if (code == null || data == null || manager == null) {
            result.error("PERMISSION_REQUIRED", "Screen capture permission required", null)
            return
        }

        Thread {
            var imageReader: ImageReader? = null
            var virtualDisplay: VirtualDisplay? = null

            try {
                if (mediaProjection == null) {
                    mediaProjection = manager.getMediaProjection(code, data)
                }

                val projection = mediaProjection
                if (projection == null) {
                    runOnUiThread(
                        Runnable {
                            result.error("PROJECTION_ERROR", "Failed to create MediaProjection", null)
                        },
                    )
                    return@Thread
                }

                val metrics = context.resources.displayMetrics
                val width = metrics.widthPixels
                val height = metrics.heightPixels
                val density = metrics.densityDpi

                imageReader = ImageReader.newInstance(width, height, PixelFormat.RGBA_8888, 2)
                virtualDisplay = projection.createVirtualDisplay(
                    "flutter_screen_capture",
                    width,
                    height,
                    density,
                    DisplayManager.VIRTUAL_DISPLAY_FLAG_AUTO_MIRROR,
                    imageReader.surface,
                    null,
                    null,
                )

                var image = imageReader.acquireLatestImage()
                var retryCount = 0
                while (image == null && retryCount < 20) {
                    Thread.sleep(50)
                    image = imageReader.acquireLatestImage()
                    retryCount += 1
                }

                if (image == null) {
                    runOnUiThread(
                        Runnable {
                            result.error("CAPTURE_FAILED", "Failed to acquire image buffer", null)
                        },
                    )
                    return@Thread
                }

                val captured = image
                try {
                    val plane = captured.planes[0]
                    val buffer = plane.buffer
                    val pixelStride = plane.pixelStride
                    val rowStride = plane.rowStride
                    val rowPadding = rowStride - pixelStride * width

                    val bitmap = Bitmap.createBitmap(
                        width + rowPadding / pixelStride,
                        height,
                        Bitmap.Config.ARGB_8888,
                    )
                    bitmap.copyPixelsFromBuffer(buffer)

                    val cropped = Bitmap.createBitmap(bitmap, 0, 0, width, height)
                    val stream = ByteArrayOutputStream()
                    try {
                        cropped.compress(Bitmap.CompressFormat.PNG, 100, stream)
                        val bytes = stream.toByteArray()
                        val base64 = Base64.encodeToString(bytes, Base64.NO_WRAP)

                        runOnUiThread(
                            Runnable {
                                result.success(
                                    mapOf(
                                        "base64Data" to base64,
                                        "mimeType" to "image/png",
                                        "width" to width,
                                        "height" to height,
                                    ),
                                )
                            },
                        )
                    } finally {
                        stream.close()
                        cropped.recycle()
                        bitmap.recycle()
                    }
                } finally {
                    captured.close()
                }
            } catch (e: Exception) {
                runOnUiThread(
                    Runnable {
                        result.error(
                            "CAPTURE_EXCEPTION",
                            e.message ?: "Unknown capture exception",
                            null,
                        )
                    },
                )
            } finally {
                virtualDisplay?.release()
                imageReader?.close()
            }
        }.start()
    }

    private fun isProbablyEmulator(): Boolean {
        val fingerprint = Build.FINGERPRINT.lowercase()
        val model = Build.MODEL.lowercase()
        val manufacturer = Build.MANUFACTURER.lowercase()
        val brand = Build.BRAND.lowercase()
        val device = Build.DEVICE.lowercase()
        val product = Build.PRODUCT.lowercase()

        return fingerprint.contains("generic") ||
            fingerprint.contains("emulator") ||
            model.contains("sdk") ||
            model.contains("emulator") ||
            manufacturer.contains("genymotion") ||
            brand.startsWith("generic") ||
            device.startsWith("generic") ||
            product.contains("sdk")
    }
}

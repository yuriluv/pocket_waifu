package com.example.flutter_application_1

import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.net.Uri
import android.util.Base64
import rikka.shizuku.Shizuku
import java.io.ByteArrayOutputStream

class AdbScreenCapturePlugin(private val context: Context) {
    private var permissionResultHandler: ((Boolean) -> Unit)? = null
    private val permissionListener: Shizuku.OnRequestPermissionResultListener

    init {
        permissionListener = Shizuku.OnRequestPermissionResultListener { requestCode, grantResult ->
            if (requestCode != REQUEST_CODE) {
                return@OnRequestPermissionResultListener
            }
            val granted = grantResult == PackageManager.PERMISSION_GRANTED
            permissionResultHandler?.invoke(granted)
            permissionResultHandler = null
            Shizuku.removeRequestPermissionResultListener(permissionListener)
        }
    }

    fun isShizukuInstalled(): Boolean {
        return try {
            context.packageManager.getPackageInfo(SHIZUKU_PACKAGE, 0)
            true
        } catch (_: Exception) {
            false
        }
    }

    fun isShizukuRunning(): Boolean {
        return try {
            Shizuku.pingBinder()
        } catch (_: Throwable) {
            false
        }
    }

    fun hasShizukuPermission(): Boolean {
        return try {
            Shizuku.checkSelfPermission() == PackageManager.PERMISSION_GRANTED
        } catch (_: Throwable) {
            false
        }
    }

    fun requestShizukuPermission(onResult: (Boolean) -> Unit) {
        permissionResultHandler = onResult
        Shizuku.addRequestPermissionResultListener(permissionListener)
        Shizuku.requestPermission(REQUEST_CODE)
    }

    fun captureScreen(maxResolution: Int = 0): Map<String, Any>? {
        if (!hasShizukuPermission()) {
            return null
        }

        val bytes = runScreencap() ?: return null
        if (bytes.isEmpty()) {
            return null
        }

        val decoded = BitmapFactory.decodeByteArray(bytes, 0, bytes.size) ?: return null
        val bitmap = if (maxResolution > 0) {
            resizeBitmap(decoded, maxResolution)
        } else {
            decoded
        }

        val outBytes = if (bitmap !== decoded) {
            val stream = ByteArrayOutputStream()
            bitmap.compress(Bitmap.CompressFormat.PNG, 100, stream)
            val result = stream.toByteArray()
            stream.close()
            decoded.recycle()
            bitmap.recycle()
            result
        } else {
            val result = bytes
            decoded.recycle()
            result
        }

        val finalBitmap = BitmapFactory.decodeByteArray(outBytes, 0, outBytes.size) ?: return null
        val result = mapOf(
            "base64Data" to Base64.encodeToString(outBytes, Base64.NO_WRAP),
            "mimeType" to "image/png",
            "width" to finalBitmap.width,
            "height" to finalBitmap.height,
        )
        finalBitmap.recycle()
        return result
    }

    fun openShizukuPlayStore() {
        val intent = Intent(Intent.ACTION_VIEW, Uri.parse("market://details?id=$SHIZUKU_PACKAGE")).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        context.startActivity(intent)
    }

    fun openShizukuApp() {
        val launchIntent = context.packageManager.getLaunchIntentForPackage(SHIZUKU_PACKAGE)
            ?: Intent(Intent.ACTION_VIEW, Uri.parse("https://play.google.com/store/apps/details?id=$SHIZUKU_PACKAGE"))
        launchIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        context.startActivity(launchIntent)
    }

    private fun runScreencap(): ByteArray? {
        val method = Shizuku::class.java.getDeclaredMethod(
            "newProcess",
            Array<String>::class.java,
            Array<String>::class.java,
            String::class.java,
        )
        method.isAccessible = true
        val process = method.invoke(
            null,
            arrayOf("screencap", "-p"),
            null,
            null,
        ) as Process
        return process.inputStream.use { it.readBytes() }.also {
            process.waitFor()
            process.destroy()
        }
    }

    private fun resizeBitmap(source: Bitmap, maxResolution: Int): Bitmap {
        if (maxResolution <= 0) {
            return source
        }
        val maxSide = maxOf(source.width, source.height)
        if (maxSide <= maxResolution) {
            return source
        }
        val ratio = maxResolution.toFloat() / maxSide.toFloat()
        val targetWidth = (source.width * ratio).toInt().coerceAtLeast(1)
        val targetHeight = (source.height * ratio).toInt().coerceAtLeast(1)
        return Bitmap.createScaledBitmap(source, targetWidth, targetHeight, true)
    }

    companion object {
        private const val SHIZUKU_PACKAGE = "moe.shizuku.privileged.api"
        private const val REQUEST_CODE = 1102
    }
}

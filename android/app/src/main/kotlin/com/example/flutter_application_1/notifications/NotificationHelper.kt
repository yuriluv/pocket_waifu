package com.example.flutter_application_1.notifications

import android.Manifest
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.app.RemoteInput
import androidx.core.content.ContextCompat
import com.example.flutter_application_1.MainActivity
import com.example.flutter_application_1.R

object NotificationHelper {
    private const val TAG = "NotificationHelper"

    fun createChannels(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val notificationManager =
            context.getSystemService(NotificationManager::class.java) ?: return

        val preResponseChannel = NotificationChannel(
            NotificationConstants.CHANNEL_PRE_RESPONSE,
            "Pocket Waifu 선응답 알림",
            NotificationManager.IMPORTANCE_HIGH
        ).apply {
            description = "AI 선응답 및 상호작용 알림"
            enableVibration(true)
        }

        notificationManager.createNotificationChannel(preResponseChannel)
    }

    fun buildPreResponseNotification(
        context: Context,
        title: String,
        message: String,
        isError: Boolean,
        sessionId: String?
    ): android.app.Notification {
        val openIntent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val openPendingIntent = PendingIntent.getActivity(
            context,
            0,
            openIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val replyIntent = Intent(context, NotificationActionReceiver::class.java).apply {
            action = NotificationConstants.ACTION_REPLY
            putExtra(NotificationConstants.EXTRA_SESSION_ID, sessionId)
            putExtra(NotificationConstants.EXTRA_TITLE, title)
        }
        val replyPendingIntent = PendingIntent.getBroadcast(
            context,
            1,
            replyIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val remoteInput = RemoteInput.Builder(NotificationConstants.REMOTE_INPUT_KEY)
            .setLabel("답장을 입력하세요")
            .build()

        val replyAction = NotificationCompat.Action.Builder(
            R.mipmap.ic_launcher,
            "Reply",
            replyPendingIntent
        )
            .addRemoteInput(remoteInput)
            .setAllowGeneratedReplies(true)
            .build()

        val menuIntent = Intent(context, NotificationActionReceiver::class.java).apply {
            action = NotificationConstants.ACTION_MENU
            putExtra(NotificationConstants.EXTRA_SESSION_ID, sessionId)
            putExtra(NotificationConstants.EXTRA_TITLE, title)
        }
        val menuPendingIntent = PendingIntent.getBroadcast(
            context,
            4,
            menuIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val menuAction = NotificationCompat.Action.Builder(
            R.mipmap.ic_launcher,
            "Menu",
            menuPendingIntent
        ).build()

        val statusText = if (isError) "오류: $message" else message

        return NotificationCompat.Builder(context, NotificationConstants.CHANNEL_PRE_RESPONSE)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(title)
            .setContentText(statusText)
            .setStyle(NotificationCompat.BigTextStyle().bigText(statusText))
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setDefaults(NotificationCompat.DEFAULT_ALL)
            .setContentIntent(openPendingIntent)
            .setAutoCancel(true)
            .addAction(replyAction)
            .addAction(menuAction)
            .build()
    }

    fun notifyPreResponse(
        context: Context,
        title: String,
        message: String,
        isError: Boolean,
        sessionId: String?
    ) {
        createChannels(context)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            val granted = ContextCompat.checkSelfPermission(
                context,
                Manifest.permission.POST_NOTIFICATIONS
            ) == PackageManager.PERMISSION_GRANTED
            if (!granted) {
                Log.d(TAG, "POST_NOTIFICATIONS denied - skipping notification")
                return
            }
        }

        val notificationManager =
            context.getSystemService(NotificationManager::class.java) ?: return
        val id = NotificationConstants.NOTIFICATION_ID_PRE_RESPONSE_BASE +
            (System.currentTimeMillis() % 1000).toInt()
        notificationManager.notify(
            id,
            buildPreResponseNotification(context, title, message, isError, sessionId)
        )
    }

    fun clearAll(context: Context) {
        val notificationManager =
            context.getSystemService(NotificationManager::class.java) ?: return
        notificationManager.cancelAll()
    }
}

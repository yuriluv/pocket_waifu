package com.example.flutter_application_1.notifications

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.app.RemoteInput
import com.example.flutter_application_1.MainActivity
import com.example.flutter_application_1.R

object NotificationHelper {
    fun createChannels(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val notificationManager =
            context.getSystemService(NotificationManager::class.java) ?: return

        val persistentChannel = NotificationChannel(
            NotificationConstants.CHANNEL_PERSISTENT,
            "Pocket Waifu 상태 알림",
            NotificationManager.IMPORTANCE_LOW
        ).apply {
            description = "앱 상태 및 응답 표시"
            setShowBadge(false)
            enableVibration(false)
            setSound(null, null)
        }

        val headsUpChannel = NotificationChannel(
            NotificationConstants.CHANNEL_HEADS_UP,
            "Pocket Waifu 응답 알림",
            NotificationManager.IMPORTANCE_HIGH
        ).apply {
            description = "AI 응답 헤드업 알림"
            enableVibration(true)
        }

        notificationManager.createNotificationChannel(persistentChannel)
        notificationManager.createNotificationChannel(headsUpChannel)
    }

    fun buildPersistentNotification(
        context: Context,
        title: String,
        message: String,
        ongoing: Boolean,
        isLoading: Boolean,
        isError: Boolean,
        sessionId: String?
    ): Notification {
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
            .setLabel("Reply")
            .build()

        val replyAction = NotificationCompat.Action.Builder(
            R.mipmap.ic_launcher,
            "Reply",
            replyPendingIntent
        )
            .addRemoteInput(remoteInput)
            .setAllowGeneratedReplies(true)
            .build()

        val cancelIntent = Intent(context, NotificationActionReceiver::class.java).apply {
            action = NotificationConstants.ACTION_CANCEL_REPLY
            putExtra(NotificationConstants.EXTRA_SESSION_ID, sessionId)
            putExtra(NotificationConstants.EXTRA_TITLE, title)
        }
        val cancelPendingIntent = PendingIntent.getBroadcast(
            context,
            2,
            cancelIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val cancelAction = NotificationCompat.Action.Builder(
            R.mipmap.ic_launcher,
            "Cancel",
            cancelPendingIntent
        ).build()

        val touchIntent = Intent(context, NotificationActionReceiver::class.java).apply {
            action = NotificationConstants.ACTION_TOUCH_THROUGH
            putExtra(NotificationConstants.EXTRA_SESSION_ID, sessionId)
            putExtra(NotificationConstants.EXTRA_TITLE, title)
        }
        val touchPendingIntent = PendingIntent.getBroadcast(
            context,
            3,
            touchIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val touchAction = NotificationCompat.Action.Builder(
            R.mipmap.ic_launcher,
            "Touch-Through",
            touchPendingIntent
        ).build()

        val statusText = when {
            isLoading -> "Responding..."
            isError -> "오류"
            else -> message
        }

        return NotificationCompat.Builder(context, NotificationConstants.CHANNEL_PERSISTENT)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(title)
            .setContentText(statusText)
            .setStyle(NotificationCompat.BigTextStyle().bigText(statusText))
            .setContentIntent(openPendingIntent)
            .setOngoing(ongoing)
            .setAutoCancel(false)
            .setOnlyAlertOnce(true)
            .addAction(replyAction)
            .addAction(cancelAction)
            .addAction(touchAction)
            .build()
    }

    fun buildHeadsUpNotification(
        context: Context,
        title: String,
        message: String,
        sessionId: String?
    ): Notification {
        val openIntent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val openPendingIntent = PendingIntent.getActivity(
            context,
            4,
            openIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        return NotificationCompat.Builder(context, NotificationConstants.CHANNEL_HEADS_UP)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(title)
            .setContentText(message)
            .setStyle(NotificationCompat.BigTextStyle().bigText(message))
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setDefaults(NotificationCompat.DEFAULT_ALL)
            .setContentIntent(openPendingIntent)
            .setAutoCancel(true)
            .build()
    }

    fun notifyPersistent(
        context: Context,
        title: String,
        message: String,
        ongoing: Boolean,
        isLoading: Boolean,
        isError: Boolean,
        sessionId: String?
    ) {
        val notificationManager =
            context.getSystemService(NotificationManager::class.java) ?: return
        val notification = buildPersistentNotification(
            context, title, message, ongoing, isLoading, isError, sessionId
        )
        notificationManager.notify(
            NotificationConstants.NOTIFICATION_ID_PERSISTENT,
            notification
        )
    }

    fun notifyHeadsUp(context: Context, title: String, message: String, sessionId: String?) {
        val notificationManager =
            context.getSystemService(NotificationManager::class.java) ?: return
        val id = NotificationConstants.NOTIFICATION_ID_HEADS_UP_BASE +
            (System.currentTimeMillis() % 1000).toInt()
        notificationManager.notify(id, buildHeadsUpNotification(context, title, message, sessionId))
    }

    fun clearAll(context: Context) {
        val notificationManager =
            context.getSystemService(NotificationManager::class.java) ?: return
        notificationManager.cancelAll()
    }
}

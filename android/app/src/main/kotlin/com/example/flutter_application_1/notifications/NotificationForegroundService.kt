package com.example.flutter_application_1.notifications

import android.app.Service
import android.content.Intent
import android.os.IBinder

class NotificationForegroundService : Service() {
    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        NotificationHelper.createChannels(this)
        val title = intent?.getStringExtra(NotificationConstants.EXTRA_TITLE) ?: "Pocket Waifu"
        val message = intent?.getStringExtra(NotificationConstants.EXTRA_MESSAGE) ?: "대기 중"
        val ongoing = intent?.getBooleanExtra(NotificationConstants.EXTRA_ONGOING, true) ?: true
        val isLoading = intent?.getBooleanExtra(NotificationConstants.EXTRA_LOADING, false) ?: false
        val isError = intent?.getBooleanExtra(NotificationConstants.EXTRA_ERROR, false) ?: false
        val sessionId = intent?.getStringExtra(NotificationConstants.EXTRA_SESSION_ID)

        val notification = NotificationHelper.buildPersistentNotification(
            this, title, message, ongoing, isLoading, isError, sessionId
        )
        startForeground(NotificationConstants.NOTIFICATION_ID_PERSISTENT, notification)
        return START_STICKY
    }
}

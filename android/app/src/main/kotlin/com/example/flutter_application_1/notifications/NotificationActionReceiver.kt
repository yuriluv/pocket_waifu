package com.example.flutter_application_1.notifications

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import androidx.core.app.RemoteInput

class NotificationActionReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val sessionId = intent.getStringExtra(NotificationConstants.EXTRA_SESSION_ID)
        when (intent.action) {
            NotificationConstants.ACTION_REPLY -> {
                val replyText = getReplyMessage(intent)
                if (!replyText.isNullOrBlank()) {
                    NotificationActionStore.enqueueAction(
                        context,
                        mapOf(
                            "type" to "reply",
                            "message" to replyText,
                            "sessionId" to sessionId
                        )
                    )
                }
            }
            NotificationConstants.ACTION_TOUCH_THROUGH -> {
                NotificationActionStore.enqueueAction(
                    context,
                    mapOf(
                        "type" to "touchThrough",
                        "sessionId" to sessionId
                    )
                )
            }
            NotificationConstants.ACTION_CANCEL_REPLY -> {
                NotificationActionStore.enqueueAction(
                    context,
                    mapOf(
                        "type" to "cancelReply",
                        "sessionId" to sessionId
                    )
                )
            }
        }
    }

    private fun getReplyMessage(intent: Intent): String? {
        val results = RemoteInput.getResultsFromIntent(intent) ?: return null
        val input = results.getCharSequence(NotificationConstants.REMOTE_INPUT_KEY)
        return input?.toString()
    }
}

package com.example.flutter_application_1.notifications

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log
import androidx.core.app.RemoteInput

class NotificationActionReceiver : BroadcastReceiver() {
    companion object {
        private const val TAG = "NotificationActionReceiver"
        private const val LEGACY_ACTION_TOUCH_THROUGH = "com.example.flutter_application_1.notifications.TOUCH_THROUGH"
        private const val LEGACY_ACTION_CANCEL_REPLY = "com.example.flutter_application_1.notifications.CANCEL_REPLY"
    }

    override fun onReceive(context: Context, intent: Intent) {
        val sessionId = intent.getStringExtra(NotificationConstants.EXTRA_SESSION_ID)
        Log.d(TAG, "onReceive action=${intent.action} sessionId=$sessionId")
        when (intent.action) {
            NotificationConstants.ACTION_REPLY -> {
                val replyText = getReplyMessage(intent)
                Log.d(TAG, "reply payload=${!replyText.isNullOrBlank()}")
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
            NotificationConstants.ACTION_MENU -> {
                Log.d(TAG, "menu action enqueued")
                NotificationActionStore.enqueueAction(
                    context,
                    mapOf(
                        "type" to "menu",
                        "sessionId" to sessionId
                    )
                )
            }
            LEGACY_ACTION_TOUCH_THROUGH -> {
                Log.d(TAG, "legacy touchThrough action enqueued")
                NotificationActionStore.enqueueAction(
                    context,
                    mapOf(
                        "type" to "touchThrough",
                        "sessionId" to sessionId
                    )
                )
            }
            LEGACY_ACTION_CANCEL_REPLY -> {
                Log.d(TAG, "legacy cancelReply action enqueued")
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

package com.example.flutter_application_1.notifications

object NotificationConstants {
    const val CHANNEL_PERSISTENT = "newcastle_persistent"
    const val CHANNEL_HEADS_UP = "newcastle_heads_up"

    const val NOTIFICATION_ID_PERSISTENT = 4201
    const val NOTIFICATION_ID_HEADS_UP_BASE = 5200

    const val ACTION_REPLY = "com.example.flutter_application_1.notifications.REPLY"
    const val ACTION_TOUCH_THROUGH = "com.example.flutter_application_1.notifications.TOUCH_THROUGH"
    const val ACTION_CANCEL_REPLY = "com.example.flutter_application_1.notifications.CANCEL_REPLY"

    const val EXTRA_SESSION_ID = "sessionId"
    const val EXTRA_MESSAGE = "message"
    const val EXTRA_TITLE = "title"
    const val EXTRA_ONGOING = "ongoing"
    const val EXTRA_LOADING = "isLoading"
    const val EXTRA_ERROR = "isError"

    const val REMOTE_INPUT_KEY = "key_text_reply"
}

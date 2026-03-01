package com.example.flutter_application_1.notifications

object NotificationConstants {
    const val CHANNEL_PRE_RESPONSE = "newcastle_pre_response"
    const val NOTIFICATION_ID_PRE_RESPONSE_BASE = 5200

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

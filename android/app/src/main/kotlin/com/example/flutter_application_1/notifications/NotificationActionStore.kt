package com.example.flutter_application_1.notifications

import android.content.Context
import android.util.Log
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray
import org.json.JSONObject

object NotificationActionStore {
    private const val TAG = "NotificationActionStore"
    private const val PREFS_NAME = "notification_actions"
    private const val KEY_ACTIONS = "pending_actions"
    private const val CHANNEL = "com.example.flutter_application_1/notifications"
    private const val ENGINE_ID = "main_engine"

    fun enqueueAction(context: Context, action: Map<String, Any?>) {
        Log.d(TAG, "enqueueAction type=${action["type"]} sessionId=${action["sessionId"]}")
        if (dispatchToFlutter(action)) return
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val existing = prefs.getString(KEY_ACTIONS, "[]") ?: "[]"
        val array = JSONArray(existing)
        array.put(JSONObject(action))
        prefs.edit().putString(KEY_ACTIONS, array.toString()).apply()
    }

    fun drainActions(context: Context): List<Map<String, Any?>> {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val existing = prefs.getString(KEY_ACTIONS, "[]") ?: "[]"
        prefs.edit().remove(KEY_ACTIONS).apply()
        val array = JSONArray(existing)
        val results = mutableListOf<Map<String, Any?>>()
        for (i in 0 until array.length()) {
            val obj = array.getJSONObject(i)
            val map = mutableMapOf<String, Any?>()
            obj.keys().forEach { key ->
                map[key] = obj.get(key)
            }
            results.add(map)
        }
        Log.d(TAG, "drainActions count=${results.size}")
        return results
    }

    private fun dispatchToFlutter(action: Map<String, Any?>): Boolean {
        return try {
            val engine = FlutterEngineCache.getInstance().get(ENGINE_ID) ?: return false
            val channel = MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL)
            channel.invokeMethod("notificationAction", action)
            Log.d(TAG, "dispatchToFlutter success type=${action["type"]}")
            true
        } catch (e: Exception) {
            Log.w(TAG, "dispatchToFlutter failed: ${e.message}")
            false
        }
    }
}

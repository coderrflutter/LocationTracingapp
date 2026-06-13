package com.example.backround_location_tracking

import android.content.Context

object TrackingPreferences {
    const val PREFS_NAME = "tracking_prefs"
    const val KEY_IS_ACTIVE = "is_active"
    const val KEY_SESSION_ID = "session_id"
    const val KEY_INTERVAL = "interval_seconds"

    fun save(
        context: Context,
        active: Boolean,
        sessionId: String,
        intervalSeconds: Int,
    ) {
        prefs(context).edit()
            .putBoolean(KEY_IS_ACTIVE, active)
            .putString(KEY_SESSION_ID, sessionId)
            .putInt(KEY_INTERVAL, intervalSeconds)
            .commit()
    }

    fun isActive(context: Context): Boolean {
        return prefs(context).getBoolean(KEY_IS_ACTIVE, false)
    }

    fun load(context: Context): TrackingState? {
        val prefs = prefs(context)
        if (!prefs.getBoolean(KEY_IS_ACTIVE, false)) return null
        val sessionId = prefs.getString(KEY_SESSION_ID, null) ?: return null
        val interval = prefs.getInt(KEY_INTERVAL, 60)
        return TrackingState(sessionId, interval)
    }

    private fun prefs(context: Context) =
        context.applicationContext.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

    data class TrackingState(
        val sessionId: String,
        val intervalSeconds: Int,
    )
}

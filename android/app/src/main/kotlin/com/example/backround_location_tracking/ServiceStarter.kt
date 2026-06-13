package com.example.backround_location_tracking

import android.app.ActivityManager
import android.content.Context
import android.content.Intent
import android.os.Build

/** Helper to start/stop the foreground location service. */
object ServiceStarter {
    private val serviceClassName = LocationTrackingService::class.java.name

    /** Starts tracking or updates session — used when user taps START. */
    fun startOrUpdate(context: Context, sessionId: String, intervalSeconds: Int) {
        val appContext = context.applicationContext
        val intent = Intent(appContext, LocationTrackingService::class.java).apply {
            action = LocationTrackingService.ACTION_START
            putExtra(LocationTrackingService.EXTRA_SESSION_ID, sessionId)
            putExtra(LocationTrackingService.EXTRA_INTERVAL_SECONDS, intervalSeconds)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            appContext.startForegroundService(intent)
        } else {
            appContext.startService(intent)
        }
    }

    fun stop(context: Context) {
        val appContext = context.applicationContext
        val intent = Intent(appContext, LocationTrackingService::class.java).apply {
            action = LocationTrackingService.ACTION_STOP
        }
        appContext.startService(intent)
    }

    /**
     * Starts the service only if it is not already running.
     * Used on app reopen — never restart a live service (that was stopping tracking).
     */
    fun ensureRunning(context: Context) {
        if (isServiceRunning(context)) return
        val state = TrackingPreferences.load(context) ?: return
        startOrUpdate(context, state.sessionId, state.intervalSeconds)
    }

    fun isServiceRunning(context: Context): Boolean {
        val manager = context.getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
        @Suppress("DEPRECATION")
        return manager.getRunningServices(Int.MAX_VALUE).any { info ->
            info.service.className == serviceClassName
        }
    }

    fun isTrackingActive(context: Context): Boolean {
        return TrackingPreferences.isActive(context) || isServiceRunning(context)
    }
}

package com.example.backround_location_tracking

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/**
 * Restarts the foreground location service after process death (force-kill / swipe away).
 */
class TrackingRestartReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        val sessionId = intent?.getStringExtra(EXTRA_SESSION_ID)
        val interval = intent?.getIntExtra(EXTRA_INTERVAL_SECONDS, 0) ?: 0

        val state = if (sessionId != null && interval > 0) {
            TrackingPreferences.TrackingState(sessionId, interval)
        } else {
            TrackingPreferences.load(context)
        } ?: return

        if (!TrackingPreferences.isActive(context)) return

        ServiceStarter.startOrUpdate(context, state.sessionId, state.intervalSeconds)
    }

    companion object {
        const val ACTION_RESTART = "com.example.backround_location_tracking.RESTART"
        const val EXTRA_SESSION_ID = "session_id"
        const val EXTRA_INTERVAL_SECONDS = "interval_seconds"

        fun scheduleRestart(context: Context, sessionId: String, intervalSeconds: Int) {
            val alarmManager =
                context.getSystemService(Context.ALARM_SERVICE) as android.app.AlarmManager
            val intent = Intent(context, TrackingRestartReceiver::class.java).apply {
                action = ACTION_RESTART
                putExtra(EXTRA_SESSION_ID, sessionId)
                putExtra(EXTRA_INTERVAL_SECONDS, intervalSeconds)
            }
            val pendingIntent = android.app.PendingIntent.getBroadcast(
                context,
                1001,
                intent,
                android.app.PendingIntent.FLAG_UPDATE_CURRENT or
                    android.app.PendingIntent.FLAG_IMMUTABLE,
            )
            alarmManager.setExactAndAllowWhileIdle(
                android.app.AlarmManager.ELAPSED_REALTIME_WAKEUP,
                android.os.SystemClock.elapsedRealtime() + 3_000,
                pendingIntent,
            )
        }

        fun cancelRestart(context: Context) {
            val alarmManager =
                context.getSystemService(Context.ALARM_SERVICE) as android.app.AlarmManager
            val intent = Intent(context, TrackingRestartReceiver::class.java)
            val pendingIntent = android.app.PendingIntent.getBroadcast(
                context,
                1001,
                intent,
                android.app.PendingIntent.FLAG_UPDATE_CURRENT or
                    android.app.PendingIntent.FLAG_IMMUTABLE,
            )
            alarmManager.cancel(pendingIntent)
        }
    }
}

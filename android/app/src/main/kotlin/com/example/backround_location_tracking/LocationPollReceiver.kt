package com.example.backround_location_tracking

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.SystemClock

class LocationPollReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        if (!TrackingPreferences.isActive(context)) return

        val pollIntent = Intent(context, LocationTrackingService::class.java).apply {
            action = LocationTrackingService.ACTION_POLL
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            context.startForegroundService(pollIntent)
        } else {
            context.startService(pollIntent)
        }

        val state = TrackingPreferences.load(context) ?: return
        scheduleNext(context, state.intervalSeconds)
    }

    companion object {
        const val ACTION = "com.example.backround_location_tracking.LOCATION_POLL"

        fun scheduleNext(context: Context, intervalSeconds: Int) {
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            val intent = Intent(context, LocationPollReceiver::class.java).apply {
                action = ACTION
            }
            val pending = PendingIntent.getBroadcast(
                context,
                2002,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
            val trigger = SystemClock.elapsedRealtime() + intervalSeconds * 1000L
            alarmManager.setExactAndAllowWhileIdle(
                AlarmManager.ELAPSED_REALTIME_WAKEUP,
                trigger,
                pending,
            )
        }

        fun cancel(context: Context) {
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            val intent = Intent(context, LocationPollReceiver::class.java)
            val pending = PendingIntent.getBroadcast(
                context,
                2002,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
            alarmManager.cancel(pending)
        }
    }
}

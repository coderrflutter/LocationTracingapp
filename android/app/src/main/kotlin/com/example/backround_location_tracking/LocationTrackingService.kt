package com.example.backround_location_tracking

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.location.Location
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.PowerManager
import android.util.Log
import androidx.core.app.NotificationCompat
import com.google.android.gms.location.LocationCallback
import com.google.android.gms.location.LocationRequest
import com.google.android.gms.location.LocationResult
import com.google.android.gms.location.LocationServices
import com.google.android.gms.location.Priority
import com.google.android.gms.tasks.CancellationTokenSource
import java.util.UUID
import java.util.concurrent.atomic.AtomicBoolean

/**
 * Foreground service — records GPS every 60 seconds into LocationStore (SQLite).
 * Uses requestLocationUpdates + Handler poll + AlarmManager for reliability.
 */
class LocationTrackingService : Service() {

    private val handler = Handler(Looper.getMainLooper())
    private val fusedClient by lazy {
        LocationServices.getFusedLocationProviderClient(this)
    }
    private var sessionId: String = ""
    private var intervalSeconds: Int = 60
    private val isRunning = AtomicBoolean(false)
    private var intentionallyStopped = false
    private var wakeLock: PowerManager.WakeLock? = null
    private var lastRecordedAtMs = 0L

    private val locationCallback = object : LocationCallback() {
        override fun onLocationResult(result: LocationResult) {
            val location = result.lastLocation ?: return
            maybeRecordLocation(location)
        }
    }

    private val handlerPollRunnable = object : Runnable {
        override fun run() {
            if (!isRunning.get()) return
            fetchLocationNow()
            handler.postDelayed(this, intervalSeconds * 1000L)
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        acquireWakeLock()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_STOP -> {
                intentionallyStopped = true
                shutdownTracking(markInactive = true)
                stopSelf()
                return START_NOT_STICKY
            }
            ACTION_POLL -> {
                if (TrackingPreferences.isActive(this) && isRunning.get()) {
                    fetchLocationNow()
                    updateNotification()
                }
            }
            ACTION_START -> {
                intentionallyStopped = false
                sessionId = intent.getStringExtra(EXTRA_SESSION_ID) ?: UUID.randomUUID().toString()
                intervalSeconds = intent.getIntExtra(EXTRA_INTERVAL_SECONDS, 60)
                TrackingPreferences.save(this, true, sessionId, intervalSeconds)
                beginTracking()
            }
            else -> {
                val saved = TrackingPreferences.load(this)
                if (saved != null && !intentionallyStopped) {
                    sessionId = saved.sessionId
                    intervalSeconds = saved.intervalSeconds
                    beginTracking()
                }
            }
        }
        return START_STICKY
    }

    override fun onDestroy() {
        val shouldRestart = isRunning.get() && !intentionallyStopped
        shutdownTracking(
            markInactive = intentionallyStopped,
            removeNotification = !shouldRestart,
        )
        if (shouldRestart) {
            TrackingRestartReceiver.scheduleRestart(this, sessionId, intervalSeconds)
        }
        releaseWakeLock()
        super.onDestroy()
    }

    override fun onTaskRemoved(rootIntent: Intent?) {
        if (TrackingPreferences.isActive(this) && !intentionallyStopped && isRunning.get()) {
            TrackingRestartReceiver.scheduleRestart(this, sessionId, intervalSeconds)
        }
        super.onTaskRemoved(rootIntent)
    }

    private fun beginTracking() {
        createNotificationChannel()
        startForegroundWithNotification("Starting GPS tracking…")

        if (!isRunning.get()) {
            isRunning.set(true)
            lastRecordedAtMs = 0L
            startLocationUpdates()
            handler.removeCallbacks(handlerPollRunnable)
            handler.post(handlerPollRunnable)
            LocationPollReceiver.scheduleNext(this, intervalSeconds)
            fetchLocationNow()
        } else {
            updateNotification()
        }
    }

    private fun startForegroundWithNotification(text: String) {
        val notification = buildNotification(text)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(
                NOTIFICATION_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_LOCATION,
            )
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
    }

    private fun startLocationUpdates() {
        val intervalMs = intervalSeconds * 1000L
        val request = LocationRequest.Builder(intervalMs)
            .setMinUpdateIntervalMillis(intervalMs)
            .setMaxUpdateDelayMillis(intervalMs)
            .setPriority(Priority.PRIORITY_HIGH_ACCURACY)
            .setWaitForAccurateLocation(false)
            .build()
        try {
            fusedClient.removeLocationUpdates(locationCallback)
            fusedClient.requestLocationUpdates(request, locationCallback, Looper.getMainLooper())
        } catch (e: SecurityException) {
            Log.e(TAG, "Missing location permission", e)
        }
    }

    private fun fetchLocationNow() {
        val token = CancellationTokenSource()
        fusedClient
            .getCurrentLocation(Priority.PRIORITY_HIGH_ACCURACY, token.token)
            .addOnSuccessListener { loc -> if (loc != null) maybeRecordLocation(loc) }
            .addOnFailureListener { e -> Log.e(TAG, "getCurrentLocation failed: ${e.message}") }
    }

    private fun maybeRecordLocation(location: Location) {
        val now = System.currentTimeMillis()
        val intervalMs = intervalSeconds * 1000L
        if (lastRecordedAtMs > 0 && now - lastRecordedAtMs < intervalMs - 5000) {
            return
        }
        lastRecordedAtMs = now
        dispatchLocation(location, now)
        updateNotification()
    }

    private fun dispatchLocation(location: Location, recordedAtMs: Long) {
        val id = LocationStore.insert(
            context = applicationContext,
            sessionId = sessionId,
            latitude = location.latitude,
            longitude = location.longitude,
            accuracy = location.accuracy,
            timestamp = recordedAtMs,
        )

        val payload = mapOf(
            "id" to id,
            "sessionId" to sessionId,
            "latitude" to location.latitude,
            "longitude" to location.longitude,
            "accuracy" to location.accuracy.toDouble(),
            "timestamp" to recordedAtMs,
        )
        LocationBroadcast.send(applicationContext, payload)
        Log.i(TAG, "Saved location at $recordedAtMs total=${LocationStore.countForSession(applicationContext, sessionId)}")
    }

    private fun updateNotification() {
        val count = LocationStore.countForSession(applicationContext, sessionId)
        val notification = buildNotification("Tracking every ${intervalSeconds}s · $count points saved")
        getSystemService(NotificationManager::class.java).notify(NOTIFICATION_ID, notification)
    }

    private fun shutdownTracking(markInactive: Boolean, removeNotification: Boolean = true) {
        isRunning.set(false)
        handler.removeCallbacks(handlerPollRunnable)
        fusedClient.removeLocationUpdates(locationCallback)
        LocationPollReceiver.cancel(this)
        if (markInactive) {
            TrackingPreferences.save(this, false, sessionId, intervalSeconds)
            TrackingRestartReceiver.cancelRestart(this)
        }
        if (removeNotification) {
            stopForeground(STOP_FOREGROUND_REMOVE)
        }
    }

    private fun acquireWakeLock() {
        val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
        wakeLock = pm.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "LocationTracker::WakeLock").apply {
            setReferenceCounted(false)
            acquire(10 * 60 * 60 * 1000L)
        }
    }

    private fun releaseWakeLock() {
        wakeLock?.let { if (it.isHeld) it.release() }
        wakeLock = null
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(CHANNEL_ID, "Location Tracking", NotificationManager.IMPORTANCE_DEFAULT)
            getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
        }
    }

    private fun buildNotification(content: String): Notification {
        val pendingIntent = PendingIntent.getActivity(
            this, 0,
            packageManager.getLaunchIntentForPackage(packageName),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Background Location Tracker")
            .setContentText(content)
            .setSmallIcon(android.R.drawable.ic_menu_mylocation)
            .setOngoing(true)
            .setContentIntent(pendingIntent)
            .build()
    }

    companion object {
        private const val TAG = "LocationTrackingService"
        const val ACTION_START = "com.example.backround_location_tracking.START"
        const val ACTION_STOP = "com.example.backround_location_tracking.STOP"
        const val ACTION_POLL = "com.example.backround_location_tracking.POLL"
        const val EXTRA_SESSION_ID = "session_id"
        const val EXTRA_INTERVAL_SECONDS = "interval_seconds"
        private const val CHANNEL_ID = "location_tracking_channel"
        private const val NOTIFICATION_ID = 9001
    }
}

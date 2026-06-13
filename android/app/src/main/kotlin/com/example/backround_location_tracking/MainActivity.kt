package com.example.backround_location_tracking

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

/**
 * Registers platform channels for tracking control, battery level, and location events.
 */
class MainActivity : FlutterActivity() {

    private var locationReceiver: BroadcastReceiver? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            TRACKING_CHANNEL,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "startTracking" -> {
                    val sessionId = call.argument<String>("sessionId")
                    val interval = call.argument<Int>("intervalSeconds") ?: 60
                    if (sessionId == null) {
                        result.error("INVALID", "sessionId required", null)
                        return@setMethodCallHandler
                    }
                    ServiceStarter.startOrUpdate(this, sessionId, interval)
                    result.success(true)
                }
                "stopTracking" -> {
                    ServiceStarter.stop(this)
                    result.success(true)
                }
                "isTrackingActive" -> {
                    result.success(ServiceStarter.isTrackingActive(this))
                }
                "getTrackingState" -> {
                    val state = TrackingPreferences.load(this)
                    result.success(
                        mapOf(
                            "isActive" to ServiceStarter.isTrackingActive(this),
                            "sessionId" to state?.sessionId,
                            "intervalSeconds" to state?.intervalSeconds,
                            "serviceRunning" to ServiceStarter.isServiceRunning(this),
                        ),
                    )
                }
                "getSessionLocations" -> {
                    val sessionId = call.argument<String>("sessionId")
                    if (sessionId == null) {
                        result.error("INVALID", "sessionId required", null)
                        return@setMethodCallHandler
                    }
                    result.success(LocationStore.getBySession(applicationContext, sessionId))
                }
                "getSavedLocationCount" -> {
                    val sessionId = call.argument<String>("sessionId")
                    val count = if (sessionId != null) {
                        LocationStore.countForSession(applicationContext, sessionId)
                    } else {
                        LocationStore.countAll(applicationContext)
                    }
                    result.success(count)
                }
                "requestBatteryOptimizationExemption" -> {
                    DeviceSettingsHelper.openBatteryOptimizationSettings(this)
                    result.success(true)
                }
                "openAutostartSettings" -> {
                    DeviceSettingsHelper.openAutostartSettings(this)
                    result.success(true)
                }
                "openVivoBackgroundSettings" -> {
                    DeviceSettingsHelper.openVivoBackgroundSettings(this)
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            BATTERY_CHANNEL,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "getBatteryLevel" -> result.success(getBatteryLevel())
                else -> result.notImplemented()
            }
        }

        EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            EVENT_CHANNEL,
        ).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    LocationEventBridge.setSink(events)
                }

                override fun onCancel(arguments: Any?) {
                    LocationEventBridge.setSink(null)
                }
            },
        )

        registerLocationReceiver()
        // Only start if the service actually died — never restart an already-running service.
        ServiceStarter.ensureRunning(this)
    }

    override fun onResume() {
        super.onResume()
        // Sync UI only; do not blindly restart the service on every resume.
        ServiceStarter.ensureRunning(this)
    }

    override fun onDestroy() {
        locationReceiver?.let { unregisterReceiver(it) }
        locationReceiver = null
        super.onDestroy()
    }

    /** Receives GPS updates from the foreground service and forwards to Flutter. */
    private fun registerLocationReceiver() {
        if (locationReceiver != null) return

        locationReceiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context?, intent: Intent?) {
                if (intent?.action != LocationBroadcast.ACTION) return
                val payload = LocationBroadcast.fromIntent(intent) ?: return
                LocationEventBridge.send(payload)
            }
        }

        val filter = IntentFilter(LocationBroadcast.ACTION)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(locationReceiver, filter, RECEIVER_NOT_EXPORTED)
        } else {
            @Suppress("UnspecifiedRegisterReceiverFlag")
            registerReceiver(locationReceiver, filter)
        }
    }

    private fun getBatteryLevel(): Int {
        val batteryManager = getSystemService(BATTERY_SERVICE) as android.os.BatteryManager
        return batteryManager.getIntProperty(android.os.BatteryManager.BATTERY_PROPERTY_CAPACITY)
    }

    companion object {
        private const val TRACKING_CHANNEL =
            "com.example.backround_location_tracking/tracking"
        private const val BATTERY_CHANNEL =
            "com.example.backround_location_tracking/battery"
        private const val EVENT_CHANNEL =
            "com.example.backround_location_tracking/location_events"
    }
}

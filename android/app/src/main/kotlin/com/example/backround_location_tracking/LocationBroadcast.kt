package com.example.backround_location_tracking

import android.content.Context
import android.content.Intent

object LocationBroadcast {
    const val ACTION = "com.example.backround_location_tracking.LOCATION_UPDATE"
    const val EXTRA_ID = "id"
    const val EXTRA_SESSION_ID = "sessionId"
    const val EXTRA_LATITUDE = "latitude"
    const val EXTRA_LONGITUDE = "longitude"
    const val EXTRA_ACCURACY = "accuracy"
    const val EXTRA_TIMESTAMP = "timestamp"

    fun send(context: Context, payload: Map<String, Any?>) {
        val intent = Intent(ACTION).apply {
            setPackage(context.packageName)
            putExtra(EXTRA_ID, payload["id"] as? String)
            putExtra(EXTRA_SESSION_ID, payload["sessionId"] as? String)
            putExtra(EXTRA_LATITUDE, payload["latitude"] as? Double)
            putExtra(EXTRA_LONGITUDE, payload["longitude"] as? Double)
            putExtra(EXTRA_ACCURACY, payload["accuracy"] as? Double)
            putExtra(EXTRA_TIMESTAMP, payload["timestamp"] as? Long)
        }
        context.sendBroadcast(intent)
    }

    fun fromIntent(intent: Intent): Map<String, Any?>? {
        if (!intent.hasExtra(EXTRA_LATITUDE)) return null
        return mapOf(
            "id" to (intent.getStringExtra(EXTRA_ID) ?: ""),
            "sessionId" to (intent.getStringExtra(EXTRA_SESSION_ID) ?: ""),
            "latitude" to intent.getDoubleExtra(EXTRA_LATITUDE, 0.0),
            "longitude" to intent.getDoubleExtra(EXTRA_LONGITUDE, 0.0),
            "accuracy" to intent.getDoubleExtra(EXTRA_ACCURACY, 0.0),
            "timestamp" to intent.getLongExtra(EXTRA_TIMESTAMP, 0L),
        )
    }
}

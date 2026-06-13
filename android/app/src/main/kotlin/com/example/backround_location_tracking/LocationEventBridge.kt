package com.example.backround_location_tracking

import io.flutter.plugin.common.EventChannel

/**
 * Holds the active EventChannel sink so the foreground service can stream locations to Flutter.
 */
object LocationEventBridge {
    private var eventSink: EventChannel.EventSink? = null

    fun setSink(sink: EventChannel.EventSink?) {
        eventSink = sink
    }

    fun send(payload: Map<String, Any?>) {
        eventSink?.success(payload)
    }
}

package com.example.backround_location_tracking

import io.flutter.plugin.common.EventChannel

object LocationEventBridge {
    private var eventSink: EventChannel.EventSink? = null

    fun setSink(sink: EventChannel.EventSink?) {
        eventSink = sink
    }

    fun send(payload: Map<String, Any?>) {
        eventSink?.success(payload)
    }
}

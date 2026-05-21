package com.example.xiangji.bridge

import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.EventChannel

object CameraBridgeEventBus {
    private val mainHandler = Handler(Looper.getMainLooper())
    private var sink: EventChannel.EventSink? = null

    fun attach(eventSink: EventChannel.EventSink) {
        mainHandler.post {
            sink = eventSink
        }
    }

    fun detach() {
        mainHandler.post {
            sink = null
        }
    }

    fun devices(devices: List<Map<String, Any?>>) {
        emit(
            mapOf(
                "type" to "devices",
                "devices" to devices,
            ),
        )
    }

    fun permission(deviceId: String, granted: Boolean) {
        emit(
            mapOf(
                "type" to "permission",
                "deviceId" to deviceId,
                "granted" to granted,
            ),
        )
    }

    fun status(phase: String, message: String) {
        emit(
            mapOf(
                "type" to "status",
                "phase" to phase,
                "message" to message,
            ),
        )
    }

    fun log(level: String, message: String) {
        emit(
            mapOf(
                "type" to "log",
                "level" to level,
                "message" to message,
            ),
        )
    }

    fun error(message: String, details: String? = null) {
        emit(
            mapOf(
                "type" to "error",
                "message" to message,
                "details" to details,
            ),
        )
    }

    fun segment(segment: Map<String, Any?>) {
        emit(
            mapOf(
                "type" to "segment",
                "segment" to segment,
            ),
        )
    }

    private fun emit(event: Map<String, Any?>) {
        mainHandler.post {
            sink?.success(event)
        }
    }
}

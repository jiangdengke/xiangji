package com.example.xiangji.service

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Intent
import android.os.Build
import android.os.IBinder
import com.example.xiangji.bridge.CameraBridgeEventBus

class CameraStreamService : Service() {
    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val deviceId = intent?.getStringExtra(EXTRA_DEVICE_ID).orEmpty()
        val streamId = intent?.getStringExtra(EXTRA_STREAM_ID) ?: "camera-001"
        val fragmentDurationMs = intent?.getIntExtra(
            EXTRA_FRAGMENT_DURATION_MS,
            2000,
        ) ?: 2000

        startForeground(
            NOTIFICATION_ID,
            buildNotification(streamId, fragmentDurationMs),
        )

        CameraBridgeEventBus.status(
            phase = "streaming",
            message = "Camera foreground service is running.",
        )
        CameraBridgeEventBus.log(
            level = "info",
            message = "CameraStreamService started for $deviceId, stream=$streamId, fragment=${fragmentDurationMs}ms.",
        )

        // Wire the concrete UVC backend here. It should write each encoded
        // segment to app storage, then call CameraBridgeEventBus.segment(...).
        return START_STICKY
    }

    override fun onDestroy() {
        CameraBridgeEventBus.status(
            phase = "idle",
            message = "Camera foreground service stopped.",
        )
        CameraBridgeEventBus.log(
            level = "info",
            message = "CameraStreamService stopped.",
        )
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            return
        }
        val channel = NotificationChannel(
            CHANNEL_ID,
            "Xiangji camera stream",
            NotificationManager.IMPORTANCE_LOW,
        ).apply {
            description = "Keeps the USB camera stream service alive."
        }
        getSystemService(NotificationManager::class.java)
            .createNotificationChannel(channel)
    }

    private fun buildNotification(
        streamId: String,
        fragmentDurationMs: Int,
    ): Notification {
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
        }

        return builder
            .setSmallIcon(android.R.drawable.stat_sys_upload)
            .setContentTitle("Xiangji camera stream")
            .setContentText("Stream $streamId, ${fragmentDurationMs}ms fragments")
            .setOngoing(true)
            .build()
    }

    companion object {
        const val EXTRA_DEVICE_ID = "extra_device_id"
        const val EXTRA_STREAM_ID = "extra_stream_id"
        const val EXTRA_FRAGMENT_DURATION_MS = "extra_fragment_duration_ms"

        private const val CHANNEL_ID = "xiangji_camera_stream"
        private const val NOTIFICATION_ID = 5201
    }
}

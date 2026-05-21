package com.example.xiangji.service

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import com.example.xiangji.bridge.CameraBridgeEventBus
import com.example.xiangji.camera.Camera2SegmentRecorder

class CameraStreamService : Service() {
    private var recorder: Camera2SegmentRecorder? = null

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

        startCameraForeground(streamId, fragmentDurationMs)

        CameraBridgeEventBus.status(
            phase = "starting",
            message = "摄像头前台服务正在启动录制器。",
        )
        CameraBridgeEventBus.log(
            level = "info",
            message = "摄像头服务已启动：设备=$deviceId，流=$streamId，分片=${fragmentDurationMs}ms。",
        )

        recorder?.stop()
        recorder = Camera2SegmentRecorder(applicationContext).also { recorder ->
            recorder.start(
                Camera2SegmentRecorder.RecorderConfig(
                    deviceId = deviceId,
                    streamId = streamId,
                    fragmentDurationMs = fragmentDurationMs.coerceAtLeast(500),
                ),
            )
        }
        return START_STICKY
    }

    override fun onDestroy() {
        recorder?.stop()
        recorder = null
        CameraBridgeEventBus.status(
            phase = "idle",
            message = "摄像头前台服务已停止。",
        )
        CameraBridgeEventBus.log(
            level = "info",
            message = "摄像头服务已停止。",
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
            "巡摄录制服务",
            NotificationManager.IMPORTANCE_LOW,
        ).apply {
            description = "保持 USB 摄像头录制服务运行。"
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
            .setContentTitle("巡摄正在录制")
            .setContentText("流 $streamId，分片 ${fragmentDurationMs}ms")
            .setOngoing(true)
            .build()
    }

    private fun startCameraForeground(
        streamId: String,
        fragmentDurationMs: Int,
    ) {
        val notification = buildNotification(streamId, fragmentDurationMs)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(
                NOTIFICATION_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_CAMERA or
                    ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC,
            )
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
    }

    companion object {
        const val EXTRA_DEVICE_ID = "extra_device_id"
        const val EXTRA_STREAM_ID = "extra_stream_id"
        const val EXTRA_FRAGMENT_DURATION_MS = "extra_fragment_duration_ms"

        private const val CHANNEL_ID = "xiangji_camera_stream"
        private const val NOTIFICATION_ID = 5201
    }
}

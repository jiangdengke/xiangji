package com.example.xiangji.service

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.hardware.camera2.CameraCharacteristics
import android.hardware.camera2.CameraManager
import android.os.Build
import android.os.IBinder
import com.example.xiangji.bridge.CameraBridgeEventBus
import com.example.xiangji.camera.Camera2SegmentRecorder

class CameraStreamService : Service() {
    private val recorders = mutableMapOf<String, Camera2SegmentRecorder>()
    private val cameraAssignments = mutableMapOf<String, String>()
    private lateinit var cameraManager: CameraManager
    private var lastFragmentDurationMs = 2000

    override fun onCreate() {
        super.onCreate()
        cameraManager = getSystemService(Context.CAMERA_SERVICE) as CameraManager
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        return when (intent?.action) {
            ACTION_STOP_DEVICE -> {
                stopRecorder(intent.getStringExtra(EXTRA_DEVICE_ID).orEmpty())
                if (recorders.isEmpty()) {
                    stopSelfResult(startId)
                    START_NOT_STICKY
                } else {
                    START_STICKY
                }
            }

            else -> {
                val deviceId = intent?.getStringExtra(EXTRA_DEVICE_ID).orEmpty()
                val streamId = intent?.getStringExtra(EXTRA_STREAM_ID) ?: "camera-001"
                val fragmentDurationMs = intent?.getIntExtra(
                    EXTRA_FRAGMENT_DURATION_MS,
                    2000,
                ) ?: 2000

                lastFragmentDurationMs = fragmentDurationMs.coerceAtLeast(500)
                updateForegroundNotification()
                startRecorder(
                    deviceId = deviceId,
                    streamId = streamId,
                    fragmentDurationMs = lastFragmentDurationMs,
                )
                updateForegroundNotification()
                if (recorders.isEmpty()) {
                    stopCameraForeground()
                    stopSelfResult(startId)
                    START_NOT_STICKY
                } else {
                    START_STICKY
                }
            }
        }
    }

    override fun onDestroy() {
        stopAllRecorders()
        stopCameraForeground()
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

    private fun startRecorder(
        deviceId: String,
        streamId: String,
        fragmentDurationMs: Int,
    ) {
        if (deviceId.isBlank()) {
            CameraBridgeEventBus.error("启动录制失败：缺少 USB 设备 ID。")
            return
        }

        val cameraId = acquireCameraId(deviceId)
        if (cameraId == null) {
            CameraBridgeEventBus.error(
                message = "没有空闲的 Camera2 摄像头可用于 $deviceId。",
                details = "请确认系统 Camera2 列表中有足够的外置摄像头。",
            )
            return
        }

        recorders.remove(deviceId)?.stop()
        val recorder = Camera2SegmentRecorder(applicationContext)
        val started = recorder.start(
            Camera2SegmentRecorder.RecorderConfig(
                deviceId = deviceId,
                streamId = streamId,
                fragmentDurationMs = fragmentDurationMs,
                cameraId = cameraId,
            ),
        )
        if (!started) {
            cameraAssignments.remove(deviceId)
            recorder.stop()
            return
        }
        recorders[deviceId] = recorder

        CameraBridgeEventBus.log(
            level = "info",
            message = "已启动设备 $deviceId：Camera2=$cameraId，流=$streamId，分片=${fragmentDurationMs}ms。",
        )
        CameraBridgeEventBus.status(
            phase = "streaming",
            message = "正在录制 ${recorders.size} 路摄像头。",
        )
    }

    private fun stopRecorder(deviceId: String) {
        if (deviceId.isBlank()) {
            return
        }

        val recorder = recorders.remove(deviceId)
        val cameraId = cameraAssignments.remove(deviceId)
        if (recorder == null) {
            CameraBridgeEventBus.log(
                level = "warning",
                message = "停止设备 $deviceId 时没有找到正在运行的录制器。",
            )
            return
        }

        recorder.stop()
        CameraBridgeEventBus.log(
            level = "info",
            message = "已停止设备 $deviceId 的录制器${cameraId?.let { "（Camera2=$it）" } ?: ""}。",
        )

        if (recorders.isEmpty()) {
            stopSelf()
            return
        }

        updateForegroundNotification()
        CameraBridgeEventBus.status(
            phase = "streaming",
            message = "已有 ${recorders.size} 路摄像头继续录制。",
        )
    }

    private fun stopAllRecorders() {
        if (recorders.isEmpty()) {
            cameraAssignments.clear()
            return
        }

        val count = recorders.size
        recorders.values.forEach { recorder ->
            recorder.stop()
        }
        recorders.clear()
        cameraAssignments.clear()
        CameraBridgeEventBus.log(
            level = "info",
            message = "已停止 $count 路摄像头录制器。",
        )
    }

    private fun acquireCameraId(deviceId: String): String? {
        cameraAssignments[deviceId]?.let { cameraId ->
            return cameraId
        }

        val cameraIds = availableCameraIds()
        val assignedCameraIds = cameraAssignments.values.toSet()
        val cameraId = cameraIds.firstOrNull { candidate ->
            candidate !in assignedCameraIds
        } ?: return null

        cameraAssignments[deviceId] = cameraId
        CameraBridgeEventBus.log(
            level = "debug",
            message = "设备 $deviceId 分配到 Camera2 摄像头 $cameraId。可用摄像头：${cameraIds.joinToString()}。",
        )
        return cameraId
    }

    private fun availableCameraIds(): List<String> {
        val cameraIds = runCatching {
            cameraManager.cameraIdList.toList()
        }.getOrElse { error ->
            CameraBridgeEventBus.error(
                message = "读取 Camera2 摄像头列表失败。",
                details = error.message ?: error.toString(),
            )
            return emptyList()
        }

        val externalCameraIds = cameraIds.filter { cameraId ->
            runCatching {
                cameraManager.getCameraCharacteristics(cameraId)
                    .get(CameraCharacteristics.LENS_FACING) ==
                    CameraCharacteristics.LENS_FACING_EXTERNAL
            }.getOrDefault(false)
        }
        return externalCameraIds.ifEmpty { cameraIds }
    }

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

    private fun buildNotification(): Notification {
        val activeCount = recorders.size
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
        }

        val contentText = if (activeCount == 0) {
            "正在准备摄像头录制"
        } else {
            "正在录制 $activeCount 路摄像头，分片 ${lastFragmentDurationMs}ms"
        }

        return builder
            .setSmallIcon(android.R.drawable.stat_sys_upload)
            .setContentTitle("巡摄正在录制")
            .setContentText(contentText)
            .setOngoing(true)
            .build()
    }

    private fun updateForegroundNotification() {
        val notification = buildNotification()
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

    private fun stopCameraForeground() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            stopForeground(STOP_FOREGROUND_REMOVE)
        } else {
            @Suppress("DEPRECATION")
            stopForeground(true)
        }
    }

    companion object {
        const val EXTRA_DEVICE_ID = "extra_device_id"
        const val EXTRA_STREAM_ID = "extra_stream_id"
        const val EXTRA_FRAGMENT_DURATION_MS = "extra_fragment_duration_ms"

        const val ACTION_START_OR_UPDATE = "com.example.xiangji.action.START_OR_UPDATE"
        const val ACTION_STOP_DEVICE = "com.example.xiangji.action.STOP_DEVICE"

        private const val CHANNEL_ID = "xiangji_camera_stream"
        private const val NOTIFICATION_ID = 5201

        fun startIntent(
            context: Context,
            deviceId: String,
            streamId: String,
            fragmentDurationMs: Int,
        ): Intent {
            return Intent(context, CameraStreamService::class.java).apply {
                action = ACTION_START_OR_UPDATE
                putExtra(EXTRA_DEVICE_ID, deviceId)
                putExtra(EXTRA_STREAM_ID, streamId)
                putExtra(EXTRA_FRAGMENT_DURATION_MS, fragmentDurationMs)
            }
        }

        fun stopDeviceIntent(context: Context, deviceId: String): Intent {
            return Intent(context, CameraStreamService::class.java).apply {
                action = ACTION_STOP_DEVICE
                putExtra(EXTRA_DEVICE_ID, deviceId)
            }
        }
    }
}

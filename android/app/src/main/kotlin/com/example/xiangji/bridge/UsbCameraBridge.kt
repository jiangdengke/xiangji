package com.example.xiangji.bridge

import android.Manifest
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.hardware.camera2.CameraCharacteristics
import android.hardware.camera2.CameraManager
import android.hardware.usb.UsbConstants
import android.hardware.usb.UsbDevice
import android.hardware.usb.UsbManager
import android.os.Build
import com.example.xiangji.service.CameraStreamService
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class UsbCameraBridge(
    context: Context,
    messenger: BinaryMessenger,
) : MethodChannel.MethodCallHandler, EventChannel.StreamHandler {
    private val appContext = context.applicationContext
    private val usbManager = appContext.getSystemService(Context.USB_SERVICE) as UsbManager
    private val cameraManager = appContext.getSystemService(Context.CAMERA_SERVICE) as CameraManager
    private val methodChannel = MethodChannel(messenger, METHOD_CHANNEL)
    private val eventChannel = EventChannel(messenger, EVENT_CHANNEL)
    private var receiverRegistered = false
    private val activeStreamDeviceIds = mutableSetOf<String>()

    private val usbStateReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            when (intent.action) {
                ACTION_USB_PERMISSION -> handleUsbPermission(intent)
                UsbManager.ACTION_USB_DEVICE_ATTACHED -> handleUsbChange(
                    action = "attached",
                    device = intent.usbDevice(),
                )
                UsbManager.ACTION_USB_DEVICE_DETACHED -> handleUsbChange(
                    action = "detached",
                    device = intent.usbDevice(),
                )
            }
        }
    }

    private fun handleUsbPermission(intent: Intent) {
        val device = intent.usbDevice()
        val granted = intent.getBooleanExtra(
            UsbManager.EXTRA_PERMISSION_GRANTED,
            false,
        )
        val deviceId = device?.deviceName.orEmpty()

        CameraBridgeEventBus.permission(deviceId, granted)
        publishInventorySnapshot(
            reason = if (granted) "权限已授予" else "权限被拒绝",
            announceStatus = true,
        )
        if (!granted) {
            CameraBridgeEventBus.error(
                message = "USB 权限被拒绝。",
                details = deviceId,
            )
            return
        }

        if (activeStreamDeviceIds.isEmpty()) {
            CameraBridgeEventBus.status(
                phase = "ready",
                message = "USB 权限已授予。",
            )
        }
    }

    private fun handleUsbChange(
        action: String,
        device: UsbDevice?,
    ) {
        val deviceId = device?.deviceName.orEmpty()
        val cameraRemoved = action == "detached" && activeStreamDeviceIds.contains(deviceId)

        if (cameraRemoved) {
            activeStreamDeviceIds.remove(deviceId)
            CameraBridgeEventBus.log(
                level = "error",
                message = "正在录制的一路 USB 摄像头已拔出：$deviceId。",
            )
            runCatching {
                appContext.startService(
                    CameraStreamService.stopDeviceIntent(appContext, deviceId),
                )
            }.onFailure { error ->
                CameraBridgeEventBus.log(
                    level = "warning",
                    message = "停止已拔出摄像头服务失败：${error.message}",
                )
            }
            publishInventorySnapshot(
                reason = "录制中摄像头拔出",
                announceStatus = false,
            )
            return
        }

        if (device != null) {
            CameraBridgeEventBus.log(
                level = "info",
                message = "USB 设备${if (action == "attached") "已接入" else "已移除"}：${device.displayName()}（${device.deviceName}）。",
            )
        }

        publishInventorySnapshot(
            reason = if (action == "attached") "USB 设备接入" else "USB 设备移除",
            announceStatus = true,
        )
    }

    private fun publishInventorySnapshot(
        reason: String,
        announceStatus: Boolean,
    ) {
        val devices = listDeviceMaps()
        val summary = buildInventorySummary(devices)

        CameraBridgeEventBus.devices(devices)
        CameraBridgeEventBus.log(
            level = "debug",
            message = "$reason：$summary",
        )

        if (!announceStatus || activeStreamDeviceIds.isNotEmpty()) {
            return
        }

        if (devices.any { it["videoClass"] == true }) {
            CameraBridgeEventBus.status(
                phase = "ready",
                message = summary,
            )
        } else {
            CameraBridgeEventBus.log(
                level = if (devices.isEmpty()) "info" else "warning",
                message = summary,
            )
            CameraBridgeEventBus.status(
                phase = "idle",
                message = summary,
            )
        }
    }

    fun attach() {
        methodChannel.setMethodCallHandler(this)
        eventChannel.setStreamHandler(this)
        registerPermissionReceiver()
    }

    fun detach() {
        methodChannel.setMethodCallHandler(null)
        eventChannel.setStreamHandler(null)
        unregisterPermissionReceiver()
        CameraBridgeEventBus.detach()
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
        CameraBridgeEventBus.attach(events)
        CameraBridgeEventBus.log("debug", "USB 事件通道已连接。")
        publishInventorySnapshot(
            reason = "初始 USB 扫描",
            announceStatus = true,
        )
    }

    override fun onCancel(arguments: Any?) {
        CameraBridgeEventBus.detach()
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "isSupported" -> result.success(true)
            "listDevices" -> result.success(listDeviceMaps())
            "requestPermission" -> requestPermission(call, result)
            "startSession" -> startSession(call, result)
            "stopSession" -> stopSession(result)
            else -> result.notImplemented()
        }
    }

    private fun requestPermission(call: MethodCall, result: MethodChannel.Result) {
        val deviceId = call.stringArgument("deviceId")
        if (deviceId.isNullOrBlank()) {
            result.error("bad_args", "必须提供 deviceId。", null)
            return
        }

        if (camera2IdFromDeviceId(deviceId) != null) {
            val granted = hasCameraPermission()
            CameraBridgeEventBus.permission(deviceId, granted)
            result.success(granted)
            return
        }

        val device = findDevice(deviceId)
        if (device == null) {
            result.error("not_found", "未找到 USB 设备。", deviceId)
            return
        }

        if (usbManager.hasPermission(device)) {
            CameraBridgeEventBus.permission(device.deviceName, true)
            CameraBridgeEventBus.devices(listDeviceMaps())
            result.success(true)
            return
        }

        val pendingIntent = PendingIntent.getBroadcast(
            appContext,
            0,
            Intent(ACTION_USB_PERMISSION).setPackage(appContext.packageName),
            PendingIntent.FLAG_UPDATE_CURRENT or immutableFlag(),
        )

        CameraBridgeEventBus.status(
            phase = "permissionRequested",
            message = "正在请求 USB 权限。",
        )
        usbManager.requestPermission(device, pendingIntent)
        result.success(false)
    }

    private fun startSession(call: MethodCall, result: MethodChannel.Result) {
        val deviceId = call.stringArgument("deviceId")
        if (deviceId.isNullOrBlank()) {
            result.error("bad_args", "必须提供 deviceId。", null)
            return
        }

        val streamId = call.stringArgument("streamId") ?: "camera-001"
        val fragmentDurationMs = call.intArgument("fragmentDurationMs", 2000)
        val camera2Id = camera2IdFromDeviceId(deviceId)
        val device = if (camera2Id == null) findDevice(deviceId) else null

        if (camera2Id == null && device == null) {
            result.error("not_found", "未找到 USB 设备。", deviceId)
            return
        }

        if (camera2Id == null && device != null && !isVideoClass(device)) {
            result.error(
                "not_video_class",
                "所选 USB 设备不是视频摄像头。",
                deviceId,
            )
            return
        }

        if (camera2Id == null && device != null && !usbManager.hasPermission(device)) {
            result.error("permission_missing", "需要 USB 权限。", deviceId)
            return
        }

        if (!hasCameraPermission()) {
            CameraBridgeEventBus.error(
                message = "需要 Android 相机权限。",
                details = "授予 CAMERA 权限后才能开始录制。",
            )
            result.error(
                "camera_permission_missing",
                "需要 Android 相机权限。",
                null,
            )
            return
        }

        val nextActiveCount = activeStreamDeviceIds.plus(deviceId).size
        val intent = CameraStreamService.startIntent(
            context = appContext,
            deviceId = deviceId,
            streamId = streamId,
            fragmentDurationMs = fragmentDurationMs,
        )

        CameraBridgeEventBus.status(
            phase = "starting",
            message = "正在启动 ${device?.displayName() ?: "Camera2 $camera2Id"}，当前将录制 $nextActiveCount 路摄像头。",
        )
        activeStreamDeviceIds.add(deviceId)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            appContext.startForegroundService(intent)
        } else {
            appContext.startService(intent)
        }
        result.success(null)
    }

    private fun stopSession(result: MethodChannel.Result) {
        CameraBridgeEventBus.status(
            phase = "stopping",
            message = "正在停止摄像头前台服务。",
        )
        activeStreamDeviceIds.clear()
        appContext.stopService(Intent(appContext, CameraStreamService::class.java))
        result.success(null)
    }

    private fun registerPermissionReceiver() {
        if (receiverRegistered) {
            return
        }
        val filter = IntentFilter().apply {
            addAction(ACTION_USB_PERMISSION)
            addAction(UsbManager.ACTION_USB_DEVICE_ATTACHED)
            addAction(UsbManager.ACTION_USB_DEVICE_DETACHED)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            appContext.registerReceiver(
                usbStateReceiver,
                filter,
                Context.RECEIVER_NOT_EXPORTED,
            )
        } else {
            @Suppress("DEPRECATION")
            appContext.registerReceiver(usbStateReceiver, filter)
        }
        receiverRegistered = true
    }

    private fun unregisterPermissionReceiver() {
        if (!receiverRegistered) {
            return
        }
        runCatching {
            appContext.unregisterReceiver(usbStateReceiver)
        }
        receiverRegistered = false
    }

    private fun listDeviceMaps(): List<Map<String, Any?>> {
        val usbDevices = usbManager.deviceList.values.map { device ->
            mapOf(
                "deviceId" to device.deviceName,
                "deviceName" to device.displayName(),
                "vendorId" to device.vendorId,
                "productId" to device.productId,
                "permissionGranted" to usbManager.hasPermission(device),
                "videoClass" to isVideoClass(device),
                "interfaceCount" to device.interfaceCount,
            )
        }
        val hasUsbVideoCamera = usbDevices.any { it["videoClass"] == true }
        if (hasUsbVideoCamera) {
            return usbDevices
        }
        return usbDevices + listCamera2DeviceMaps()
    }

    private fun listCamera2DeviceMaps(): List<Map<String, Any?>> {
        return runCatching {
            cameraManager.cameraIdList.map { cameraId ->
                val lensFacing = runCatching {
                    cameraManager.getCameraCharacteristics(cameraId)
                        .get(CameraCharacteristics.LENS_FACING)
                }.getOrNull()
                mapOf(
                    "deviceId" to "$CAMERA2_DEVICE_PREFIX$cameraId",
                    "deviceName" to "Camera2 ${lensFacingLabel(lensFacing)}摄像头 $cameraId",
                    "vendorId" to 0,
                    "productId" to 0,
                    "permissionGranted" to hasCameraPermission(),
                    "videoClass" to true,
                    "interfaceCount" to 0,
                )
            }
        }.getOrElse { error ->
            CameraBridgeEventBus.log(
                level = "warning",
                message = "读取 Camera2 摄像头失败：${error.message ?: error}",
            )
            emptyList()
        }
    }

    private fun buildInventorySummary(devices: List<Map<String, Any?>>): String {
        val usbCount = devices.size
        val cameraCount = devices.count { it["videoClass"] == true }

        return when {
            usbCount == 0 -> "未检测到 USB 设备。"
            cameraCount == 0 -> "检测到 $usbCount 个 USB 设备，但没有视频摄像头。"
            usbCount == cameraCount -> "已检测到 $cameraCount 个 USB 摄像头。"
            else -> "在 $usbCount 个 USB 设备中检测到 $cameraCount 个 USB 摄像头。"
        }
    }

    private fun findDevice(deviceId: String): UsbDevice? {
        return usbManager.deviceList.values.firstOrNull { device ->
            device.deviceName == deviceId
        }
    }

    private fun isVideoClass(device: UsbDevice): Boolean {
        for (index in 0 until device.interfaceCount) {
            if (device.getInterface(index).interfaceClass == UsbConstants.USB_CLASS_VIDEO) {
                return true
            }
        }
        return false
    }

    private fun camera2IdFromDeviceId(deviceId: String): String? {
        if (!deviceId.startsWith(CAMERA2_DEVICE_PREFIX)) {
            return null
        }
        return deviceId.removePrefix(CAMERA2_DEVICE_PREFIX).takeIf { it.isNotBlank() }
    }

    private fun lensFacingLabel(value: Int?): String {
        return when (value) {
            CameraCharacteristics.LENS_FACING_EXTERNAL -> "外置"
            CameraCharacteristics.LENS_FACING_FRONT -> "前置"
            CameraCharacteristics.LENS_FACING_BACK -> "后置"
            else -> ""
        }
    }

    private fun hasCameraPermission(): Boolean {
        return Build.VERSION.SDK_INT < Build.VERSION_CODES.M ||
            appContext.checkSelfPermission(Manifest.permission.CAMERA) ==
            PackageManager.PERMISSION_GRANTED
    }

    private fun UsbDevice.displayName(): String {
        return productName ?: manufacturerName ?: deviceName
    }

    private fun MethodCall.stringArgument(key: String): String? {
        return (arguments as? Map<*, *>)?.get(key)?.toString()
    }

    private fun MethodCall.intArgument(key: String, fallback: Int): Int {
        return when (val value = (arguments as? Map<*, *>)?.get(key)) {
            is Int -> value
            is Long -> value.toInt()
            is Number -> value.toInt()
            is String -> value.toIntOrNull() ?: fallback
            else -> fallback
        }
    }

    private fun immutableFlag(): Int {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            PendingIntent.FLAG_IMMUTABLE
        } else {
            0
        }
    }

    @Suppress("DEPRECATION")
    private fun Intent.legacyUsbDevice(): UsbDevice? {
        return getParcelableExtra(UsbManager.EXTRA_DEVICE)
    }

    private fun Intent.usbDevice(): UsbDevice? {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            getParcelableExtra(UsbManager.EXTRA_DEVICE, UsbDevice::class.java)
        } else {
            legacyUsbDevice()
        }
    }

    private companion object {
        const val METHOD_CHANNEL = "xiangji/usb_camera/method"
        const val EVENT_CHANNEL = "xiangji/usb_camera/events"
        const val ACTION_USB_PERMISSION = "com.example.xiangji.USB_PERMISSION"
        const val CAMERA2_DEVICE_PREFIX = "camera2:"
    }
}

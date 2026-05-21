package com.example.xiangji.bridge

import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
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
    private val methodChannel = MethodChannel(messenger, METHOD_CHANNEL)
    private val eventChannel = EventChannel(messenger, EVENT_CHANNEL)
    private var receiverRegistered = false

    private val permissionReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            if (intent.action != ACTION_USB_PERMISSION) {
                return
            }

            val device = intent.usbDevice()
            val granted = intent.getBooleanExtra(
                UsbManager.EXTRA_PERMISSION_GRANTED,
                false,
            )
            val deviceId = device?.deviceName.orEmpty()

            CameraBridgeEventBus.permission(deviceId, granted)
            CameraBridgeEventBus.devices(listDeviceMaps())
            if (granted) {
                CameraBridgeEventBus.status(
                    phase = "ready",
                    message = "USB permission granted.",
                )
            } else {
                CameraBridgeEventBus.error(
                    message = "USB permission denied.",
                    details = deviceId,
                )
            }
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
        CameraBridgeEventBus.log("debug", "USB event channel attached.")
        CameraBridgeEventBus.devices(listDeviceMaps())
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
            result.error("bad_args", "deviceId is required.", null)
            return
        }

        val device = findDevice(deviceId)
        if (device == null) {
            result.error("not_found", "USB device was not found.", deviceId)
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
            message = "Requesting USB permission.",
        )
        usbManager.requestPermission(device, pendingIntent)
        result.success(false)
    }

    private fun startSession(call: MethodCall, result: MethodChannel.Result) {
        val deviceId = call.stringArgument("deviceId")
        if (deviceId.isNullOrBlank()) {
            result.error("bad_args", "deviceId is required.", null)
            return
        }

        val streamId = call.stringArgument("streamId") ?: "camera-001"
        val fragmentDurationMs = call.intArgument("fragmentDurationMs", 2000)
        val device = findDevice(deviceId)

        if (device == null) {
            result.error("not_found", "USB device was not found.", deviceId)
            return
        }

        if (!isVideoClass(device)) {
            result.error(
                "not_video_class",
                "Selected USB device is not a video-class device.",
                deviceId,
            )
            return
        }

        if (!usbManager.hasPermission(device)) {
            result.error("permission_missing", "USB permission is required.", deviceId)
            return
        }

        val intent = Intent(appContext, CameraStreamService::class.java).apply {
            putExtra(CameraStreamService.EXTRA_DEVICE_ID, deviceId)
            putExtra(CameraStreamService.EXTRA_STREAM_ID, streamId)
            putExtra(
                CameraStreamService.EXTRA_FRAGMENT_DURATION_MS,
                fragmentDurationMs,
            )
        }

        CameraBridgeEventBus.status(
            phase = "starting",
            message = "Starting camera foreground service.",
        )
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
            message = "Stopping camera foreground service.",
        )
        appContext.stopService(Intent(appContext, CameraStreamService::class.java))
        result.success(null)
    }

    private fun registerPermissionReceiver() {
        if (receiverRegistered) {
            return
        }
        val filter = IntentFilter(ACTION_USB_PERMISSION)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            appContext.registerReceiver(
                permissionReceiver,
                filter,
                Context.RECEIVER_NOT_EXPORTED,
            )
        } else {
            @Suppress("DEPRECATION")
            appContext.registerReceiver(permissionReceiver, filter)
        }
        receiverRegistered = true
    }

    private fun unregisterPermissionReceiver() {
        if (!receiverRegistered) {
            return
        }
        runCatching {
            appContext.unregisterReceiver(permissionReceiver)
        }
        receiverRegistered = false
    }

    private fun listDeviceMaps(): List<Map<String, Any?>> {
        return usbManager.deviceList.values.map { device ->
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
    }
}

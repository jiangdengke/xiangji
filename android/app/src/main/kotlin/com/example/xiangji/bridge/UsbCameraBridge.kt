package com.example.xiangji.bridge

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.hardware.camera2.CameraManager
import android.hardware.usb.UsbDevice
import android.hardware.usb.UsbManager
import android.os.Build
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class UsbCameraBridge(
    context: Context,
    messenger: BinaryMessenger,
) : EventChannel.StreamHandler {
    private val appContext = context.applicationContext
    private val usbManager = appContext.getSystemService(Context.USB_SERVICE) as UsbManager
    private val cameraManager = appContext.getSystemService(Context.CAMERA_SERVICE) as CameraManager
    private val inventory = UsbCameraInventory(
        usbManager = usbManager,
        cameraManager = cameraManager,
        hasCameraPermission = ::hasCameraPermission,
    ) { level, message ->
        CameraBridgeEventBus.log(level, message)
    }
    private val inventoryPublisher = UsbCameraInventoryPublisher(
        inventory = inventory
    )
    private val permissionRequester = UsbCameraPermissionRequester(
        appContext = appContext,
        usbManager = usbManager,
        inventory = inventory,
        permissionAction = ACTION_USB_PERMISSION,
        hasCameraPermission = ::hasCameraPermission,
        deviceMapsProvider = inventoryPublisher::listDeviceMaps,
    )
    private val methodHandler = UsbCameraMethodHandler(
        listDeviceMaps = inventoryPublisher::listDeviceMaps,
        permissionRequester = permissionRequester,
    )
    private val methodChannel = MethodChannel(messenger, METHOD_CHANNEL)
    private val eventChannel = EventChannel(messenger, EVENT_CHANNEL)
    private val usbStateReceiver = UsbCameraBroadcastReceiver(
        appContext = appContext,
        permissionAction = ACTION_USB_PERMISSION,
        onPermission = ::handleUsbPermission,
        onUsbChange = ::handleUsbChange,
    )

    private fun handleUsbPermission(device: UsbDevice?, granted: Boolean) {
        val deviceId = device?.deviceName.orEmpty()

        CameraBridgeEventBus.permission(deviceId, granted)
        inventoryPublisher.publish(
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

        CameraBridgeEventBus.status(
            phase = "ready",
            message = "USB 权限已授予。",
        )
    }

    private fun handleUsbChange(
        action: String,
        device: UsbDevice?,
    ) {
        if (device != null) {
            CameraBridgeEventBus.log(
                level = "info",
                message = "USB 设备${if (action == "attached") "已接入" else "已移除"}：" +
                    "${inventory.displayName(device)}（${device.deviceName}）。",
            )
        }

        inventoryPublisher.publish(
            reason = if (action == "attached") "USB 设备接入" else "USB 设备移除",
            announceStatus = true,
        )
    }

    fun attach() {
        methodChannel.setMethodCallHandler(methodHandler)
        eventChannel.setStreamHandler(this)
        usbStateReceiver.register()
    }

    fun detach() {
        methodChannel.setMethodCallHandler(null)
        eventChannel.setStreamHandler(null)
        usbStateReceiver.unregister()
        CameraBridgeEventBus.detach()
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
        CameraBridgeEventBus.attach(events)
        CameraBridgeEventBus.log("debug", "USB 事件通道已连接。")
        inventoryPublisher.publish(
            reason = "初始 USB 扫描",
            announceStatus = true,
        )
    }

    override fun onCancel(arguments: Any?) {
        CameraBridgeEventBus.detach()
    }

    private fun hasCameraPermission(): Boolean {
        return Build.VERSION.SDK_INT < Build.VERSION_CODES.M ||
            appContext.checkSelfPermission(Manifest.permission.CAMERA) ==
            PackageManager.PERMISSION_GRANTED
    }

    private companion object {
        const val METHOD_CHANNEL = "xiangji/usb_camera/method"
        const val EVENT_CHANNEL = "xiangji/usb_camera/events"
        const val ACTION_USB_PERMISSION = "com.example.xiangji.USB_PERMISSION"
    }
}

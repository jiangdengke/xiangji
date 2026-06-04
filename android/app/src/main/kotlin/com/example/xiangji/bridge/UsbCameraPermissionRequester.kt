package com.example.xiangji.bridge

import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.hardware.usb.UsbManager
import android.os.Build

data class UsbCameraPermissionResult(
    val granted: Boolean? = null,
    val errorCode: String? = null,
    val errorMessage: String? = null,
    val errorDetails: Any? = null,
) {
    val isError: Boolean
        get() = errorCode != null

    companion object {
        fun success(granted: Boolean): UsbCameraPermissionResult {
            return UsbCameraPermissionResult(granted = granted)
        }

        fun error(
            code: String,
            message: String,
            details: Any?,
        ): UsbCameraPermissionResult {
            return UsbCameraPermissionResult(
                errorCode = code,
                errorMessage = message,
                errorDetails = details,
            )
        }
    }
}

class UsbCameraPermissionRequester(
    private val appContext: Context,
    private val usbManager: UsbManager,
    private val inventory: UsbCameraInventory,
    private val permissionAction: String,
    private val hasCameraPermission: () -> Boolean,
    private val deviceMapsProvider: () -> List<Map<String, Any?>>,
) {
    fun request(deviceId: String): UsbCameraPermissionResult {
        if (UsbCameraInventory.camera2IdFromDeviceId(deviceId) != null) {
            val granted = hasCameraPermission()
            CameraBridgeEventBus.permission(deviceId, granted)
            return UsbCameraPermissionResult.success(granted)
        }

        val device = inventory.findUsbDevice(deviceId)
            ?: return UsbCameraPermissionResult.error(
                code = "not_found",
                message = "未找到 USB 设备。",
                details = deviceId,
            )

        if (usbManager.hasPermission(device)) {
            CameraBridgeEventBus.permission(device.deviceName, true)
            CameraBridgeEventBus.devices(deviceMapsProvider())
            return UsbCameraPermissionResult.success(true)
        }

        val pendingIntent = PendingIntent.getBroadcast(
            appContext,
            0,
            Intent(permissionAction).setPackage(appContext.packageName),
            PendingIntent.FLAG_UPDATE_CURRENT or immutableFlag(),
        )

        CameraBridgeEventBus.status(
            phase = "permissionRequested",
            message = "正在请求 USB 权限。",
        )
        usbManager.requestPermission(device, pendingIntent)
        return UsbCameraPermissionResult.success(false)
    }

    private fun immutableFlag(): Int {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            PendingIntent.FLAG_IMMUTABLE
        } else {
            0
        }
    }
}

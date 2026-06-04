package com.example.xiangji.bridge

import android.hardware.camera2.CameraCharacteristics
import android.hardware.camera2.CameraManager
import android.hardware.usb.UsbConstants
import android.hardware.usb.UsbDevice
import android.hardware.usb.UsbManager

class UsbCameraInventory(
    private val usbManager: UsbManager,
    private val cameraManager: CameraManager,
    private val hasCameraPermission: () -> Boolean,
    private val log: (String, String) -> Unit = { _, _ -> },
) {
    fun listDeviceMaps(): List<Map<String, Any?>> {
        val usbDevices = usbManager.deviceList.values.map { device ->
            mapOf(
                "deviceId" to device.deviceName,
                "deviceName" to displayName(device),
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

    fun buildInventorySummary(devices: List<Map<String, Any?>>): String {
        val usbCount = devices.size
        val cameraCount = devices.count { it["videoClass"] == true }

        return when {
            usbCount == 0 -> "未检测到 USB 设备。"
            cameraCount == 0 -> "检测到 $usbCount 个 USB 设备，但没有视频摄像头。"
            usbCount == cameraCount -> "已检测到 $cameraCount 个 USB 摄像头。"
            else -> "在 $usbCount 个 USB 设备中检测到 $cameraCount 个 USB 摄像头。"
        }
    }

    fun findUsbDevice(deviceId: String): UsbDevice? {
        return usbManager.deviceList.values.firstOrNull { device ->
            device.deviceName == deviceId
        }
    }

    fun isVideoClass(device: UsbDevice): Boolean {
        for (index in 0 until device.interfaceCount) {
            if (device.getInterface(index).interfaceClass == UsbConstants.USB_CLASS_VIDEO) {
                return true
            }
        }
        return false
    }

    fun displayName(device: UsbDevice): String {
        return device.productName ?: device.manufacturerName ?: device.deviceName
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
            log("warning", "读取 Camera2 摄像头失败：${error.message ?: error}")
            emptyList()
        }
    }

    private fun lensFacingLabel(value: Int?): String {
        return when (value) {
            CameraCharacteristics.LENS_FACING_EXTERNAL -> "外置"
            CameraCharacteristics.LENS_FACING_FRONT -> "前置"
            CameraCharacteristics.LENS_FACING_BACK -> "后置"
            else -> ""
        }
    }

    companion object {
        const val CAMERA2_DEVICE_PREFIX = "camera2:"

        fun camera2IdFromDeviceId(deviceId: String): String? {
            if (!deviceId.startsWith(CAMERA2_DEVICE_PREFIX)) {
                return null
            }
            return deviceId.removePrefix(CAMERA2_DEVICE_PREFIX)
                .takeIf { it.isNotBlank() }
        }
    }
}

package com.example.xiangji.bridge

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.hardware.usb.UsbDevice
import android.hardware.usb.UsbManager
import android.os.Build

class UsbCameraBroadcastReceiver(
    private val appContext: Context,
    private val permissionAction: String,
    private val onPermission: (UsbDevice?, Boolean) -> Unit,
    private val onUsbChange: (String, UsbDevice?) -> Unit,
) {
    private var registered = false

    private val receiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            when (intent.action) {
                permissionAction -> onPermission(
                    intent.usbDevice(),
                    intent.getBooleanExtra(
                        UsbManager.EXTRA_PERMISSION_GRANTED,
                        false,
                    ),
                )
                UsbManager.ACTION_USB_DEVICE_ATTACHED -> onUsbChange(
                    "attached",
                    intent.usbDevice(),
                )
                UsbManager.ACTION_USB_DEVICE_DETACHED -> onUsbChange(
                    "detached",
                    intent.usbDevice(),
                )
            }
        }
    }

    fun register() {
        if (registered) {
            return
        }

        val filter = IntentFilter().apply {
            addAction(permissionAction)
            addAction(UsbManager.ACTION_USB_DEVICE_ATTACHED)
            addAction(UsbManager.ACTION_USB_DEVICE_DETACHED)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            appContext.registerReceiver(
                receiver,
                filter,
                Context.RECEIVER_NOT_EXPORTED,
            )
        } else {
            @Suppress("DEPRECATION")
            appContext.registerReceiver(receiver, filter)
        }
        registered = true
    }

    fun unregister() {
        if (!registered) {
            return
        }
        runCatching {
            appContext.unregisterReceiver(receiver)
        }
        registered = false
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
}

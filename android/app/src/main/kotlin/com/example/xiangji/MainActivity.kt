package com.example.xiangji

import android.Manifest
import android.content.pm.PackageManager
import android.os.Build
import com.example.xiangji.bridge.CameraBridgeEventBus
import com.example.xiangji.bridge.UsbCameraBridge
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    private var usbCameraBridge: UsbCameraBridge? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        requestRuntimePermissions()
        usbCameraBridge = UsbCameraBridge(
            context = this,
            messenger = flutterEngine.dartExecutor.binaryMessenger,
        ).also { bridge ->
            bridge.attach()
        }
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        usbCameraBridge?.detach()
        usbCameraBridge = null
        super.cleanUpFlutterEngine(flutterEngine)
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != REQUEST_RUNTIME_PERMISSIONS) {
            return
        }

        permissions.forEachIndexed { index, permission ->
            val granted = grantResults.getOrNull(index) == PackageManager.PERMISSION_GRANTED
            when (permission) {
                Manifest.permission.CAMERA -> {
                    if (granted) {
                        CameraBridgeEventBus.log("info", "Android CAMERA permission granted.")
                    } else {
                        CameraBridgeEventBus.error(
                            message = "Android CAMERA permission denied.",
                            details = "Recording cannot start until this permission is granted.",
                        )
                    }
                }

                Manifest.permission.POST_NOTIFICATIONS -> {
                    CameraBridgeEventBus.log(
                        if (granted) "info" else "warning",
                        if (granted) {
                            "Android notification permission granted."
                        } else {
                            "Android notification permission denied; foreground service notification may be hidden."
                        },
                    )
                }
            }
        }
    }

    private fun requestRuntimePermissions() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) {
            return
        }

        val permissions = mutableListOf<String>()
        if (checkSelfPermission(Manifest.permission.CAMERA) != PackageManager.PERMISSION_GRANTED) {
            permissions.add(Manifest.permission.CAMERA)
        }
        if (
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED
        ) {
            permissions.add(Manifest.permission.POST_NOTIFICATIONS)
        }

        if (permissions.isNotEmpty()) {
            requestPermissions(permissions.toTypedArray(), REQUEST_RUNTIME_PERMISSIONS)
        }
    }

    private companion object {
        const val REQUEST_RUNTIME_PERMISSIONS = 5202
    }
}

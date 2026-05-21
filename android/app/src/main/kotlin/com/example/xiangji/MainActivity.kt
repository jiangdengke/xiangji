package com.example.xiangji

import com.example.xiangji.bridge.UsbCameraBridge
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    private var usbCameraBridge: UsbCameraBridge? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
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
}

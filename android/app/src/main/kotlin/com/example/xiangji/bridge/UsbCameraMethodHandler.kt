package com.example.xiangji.bridge

import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class UsbCameraMethodHandler(
    private val listDeviceMaps: () -> List<Map<String, Any?>>,
    private val permissionRequester: UsbCameraPermissionRequester,
) : MethodChannel.MethodCallHandler {
    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "isSupported" -> result.success(true)
            "listDevices" -> result.success(listDeviceMaps())
            "requestPermission" -> requestPermission(call, result)
            else -> result.notImplemented()
        }
    }

    private fun requestPermission(call: MethodCall, result: MethodChannel.Result) {
        val deviceId = call.stringArgument("deviceId")
        if (deviceId.isNullOrBlank()) {
            result.error("bad_args", "必须提供 deviceId。", null)
            return
        }

        val permissionResult = permissionRequester.request(deviceId)
        if (permissionResult.isError) {
            result.error(
                permissionResult.errorCode ?: "permission_error",
                permissionResult.errorMessage,
                permissionResult.errorDetails,
            )
            return
        }
        result.success(permissionResult.granted ?: false)
    }

    private fun MethodCall.stringArgument(key: String): String? {
        return (arguments as? Map<*, *>)?.get(key)?.toString()
    }
}

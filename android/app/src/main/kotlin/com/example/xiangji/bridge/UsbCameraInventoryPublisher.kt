package com.example.xiangji.bridge

class UsbCameraInventoryPublisher(
    private val inventory: UsbCameraInventory
) {
    fun listDeviceMaps(): List<Map<String, Any?>> {
        return inventory.listDeviceMaps()
    }

    fun publish(
        reason: String,
        announceStatus: Boolean,
    ) {
        val devices = listDeviceMaps()
        val summary = inventory.buildInventorySummary(devices)

        CameraBridgeEventBus.devices(devices)
        CameraBridgeEventBus.log(
            level = "debug",
            message = "$reason：$summary",
        )

        if (!announceStatus) {
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
}

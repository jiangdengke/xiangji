import 'dart:async';

import 'package:xiangji/src/bridge/camera_bridge.dart';
import 'package:xiangji/src/domain.dart';

class TestBridge implements CameraBridge {
  TestBridge({List<UsbCameraDevice>? devices})
    : _devices =
          devices ??
          const <UsbCameraDevice>[
            UsbCameraDevice(
              deviceId: 'usb-1',
              deviceName: 'Unit Test Camera 1',
              vendorId: 1,
              productId: 2,
              permissionGranted: true,
              videoClass: true,
              interfaceCount: 1,
            ),
            UsbCameraDevice(
              deviceId: 'usb-2',
              deviceName: 'Unit Test Camera 2',
              vendorId: 1,
              productId: 3,
              permissionGranted: true,
              videoClass: true,
              interfaceCount: 1,
            ),
          ];

  final StreamController<CameraBridgeEvent> _events =
      StreamController<CameraBridgeEvent>.broadcast();
  final List<UsbCameraDevice> _devices;

  @override
  Stream<CameraBridgeEvent> get events => _events.stream;

  @override
  Future<bool> isSupported() async => true;

  @override
  Future<List<UsbCameraDevice>> listDevices() async {
    return List<UsbCameraDevice>.unmodifiable(_devices);
  }

  @override
  Future<bool> requestPermission(String deviceId) async => true;

  void emitStatus(SessionPhase phase, String message) {
    _events.add(CameraStatusEvent(phase: phase, message: message));
  }

  @override
  Future<void> dispose() async {
    await _events.close();
  }
}

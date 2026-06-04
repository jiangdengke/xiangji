import 'dart:async';

import '../domain.dart';
import 'camera_bridge.dart';
import 'mock_camera_devices.dart';

class MockCameraBridge implements CameraBridge {
  MockCameraBridge()
    : _devices = createMockCameraDevices(),
      _eventController = StreamController<CameraBridgeEvent>.broadcast();

  final StreamController<CameraBridgeEvent> _eventController;
  final List<UsbCameraDevice> _devices;
  final List<Timer> _timers = <Timer>[];

  @override
  Stream<CameraBridgeEvent> get events => _eventController.stream;

  @override
  Future<bool> isSupported() async => false;

  @override
  Future<List<UsbCameraDevice>> listDevices() async {
    return List<UsbCameraDevice>.unmodifiable(_devices);
  }

  @override
  Future<bool> requestPermission(String deviceId) async {
    final index = _devices.indexWhere((UsbCameraDevice device) {
      return device.deviceId == deviceId;
    });
    if (index == -1) {
      _eventController.add(const CameraErrorEvent(message: '模拟桥接找不到请求的设备。'));
      return false;
    }

    if (_devices[index].permissionGranted) {
      _eventController.add(
        CameraPermissionEvent(deviceId: deviceId, granted: true),
      );
      return true;
    }

    _eventController.add(
      CameraLogEvent(level: LogLevel.info, message: '已为 $deviceId 排队模拟权限请求。'),
    );

    final timer = Timer(const Duration(milliseconds: 350), () {
      _devices[index] = _devices[index].copyWith(permissionGranted: true);
      _eventController.add(
        CameraPermissionEvent(deviceId: deviceId, granted: true),
      );
      _eventController.add(
        CameraDevicesUpdated(List<UsbCameraDevice>.unmodifiable(_devices)),
      );
    });
    _timers.add(timer);
    return false;
  }

  @override
  Future<void> dispose() async {
    for (final timer in _timers) {
      timer.cancel();
    }
    _timers.clear();
    await _eventController.close();
  }
}

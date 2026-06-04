import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:xiangji/src/bridge/camera_bridge.dart';
import 'package:xiangji/src/controller/camera_permission_coordinator.dart';
import 'package:xiangji/src/domain.dart';

void main() {
  test('prepares none-selected and already-granted states', () {
    final coordinator = CameraPermissionCoordinator(bridge: _PermissionBridge());

    final none = coordinator.prepare(const <UsbCameraDevice>[]);
    final granted = coordinator.prepare(<UsbCameraDevice>[
      _camera('camera-1', permissionGranted: true),
      _camera('camera-2', permissionGranted: true),
    ]);

    expect(none.shouldRequest, isFalse);
    expect(none.logLevel, LogLevel.warning);
    expect(none.message, contains('还没有选择'));
    expect(granted.shouldRequest, isFalse);
    expect(granted.logLevel, LogLevel.info);
    expect(granted.message, contains('都已授权'));
  });

  test('requests only pending camera permissions and returns log messages', () async {
    final bridge = _PermissionBridge(grantedDeviceIds: <String>{'camera-2'});
    final coordinator = CameraPermissionCoordinator(bridge: bridge);
    final preparation = coordinator.prepare(<UsbCameraDevice>[
      _camera('camera-1', permissionGranted: true),
      _camera('camera-2', permissionGranted: false),
      _camera('camera-3', permissionGranted: false),
    ]);

    final logs = await coordinator.requestPending(preparation);

    expect(preparation.shouldRequest, isTrue);
    expect(
      preparation.pendingDevices.map((UsbCameraDevice device) => device.deviceId),
      <String>['camera-2', 'camera-3'],
    );
    expect(bridge.permissionRequests, <String>['camera-2', 'camera-3']);
    expect(logs.map((CameraPermissionRequestLog log) => log.message), <String>[
      'camera-2 已授权。',
      '已发送 camera-3 的权限请求。',
    ]);
  });
}

UsbCameraDevice _camera(String deviceId, {required bool permissionGranted}) {
  return UsbCameraDevice(
    deviceId: deviceId,
    deviceName: deviceId,
    vendorId: 1,
    productId: 1,
    permissionGranted: permissionGranted,
    videoClass: true,
    interfaceCount: 1,
  );
}

class _PermissionBridge implements CameraBridge {
  _PermissionBridge({Set<String>? grantedDeviceIds})
    : _grantedDeviceIds = grantedDeviceIds ?? const <String>{};

  final Set<String> _grantedDeviceIds;
  final List<String> permissionRequests = <String>[];
  final StreamController<CameraBridgeEvent> _events =
      StreamController<CameraBridgeEvent>.broadcast();

  @override
  Stream<CameraBridgeEvent> get events => _events.stream;

  @override
  Future<bool> isSupported() async => true;

  @override
  Future<List<UsbCameraDevice>> listDevices() async => const <UsbCameraDevice>[];

  @override
  Future<bool> requestPermission(String deviceId) async {
    permissionRequests.add(deviceId);
    return _grantedDeviceIds.contains(deviceId);
  }

  @override
  Future<void> dispose() async {
    await _events.close();
  }
}

import 'package:flutter_test/flutter_test.dart';

import 'package:xiangji/src/controller/usb_device_registry.dart';
import 'package:xiangji/src/domain.dart';

void main() {
  test('registry auto-selects detected video devices once', () {
    final registry = UsbDeviceRegistry();

    registry.replaceDevices(const <UsbCameraDevice>[
      UsbCameraDevice(
        deviceId: 'hub-1',
        deviceName: 'USB Hub',
        vendorId: 1,
        productId: 1,
        permissionGranted: true,
        videoClass: false,
        interfaceCount: 1,
      ),
      UsbCameraDevice(
        deviceId: 'camera-1',
        deviceName: 'Camera 1',
        vendorId: 2,
        productId: 1,
        permissionGranted: true,
        videoClass: true,
        interfaceCount: 1,
      ),
      UsbCameraDevice(
        deviceId: 'camera-2',
        deviceName: 'Camera 2',
        vendorId: 2,
        productId: 2,
        permissionGranted: false,
        videoClass: true,
        interfaceCount: 1,
      ),
    ]);

    expect(registry.usbDeviceCount, 3);
    expect(registry.videoCameraCount, 2);
    expect(registry.selectedDeviceIds, <String>{'camera-1', 'camera-2'});
    expect(registry.selectedVideoCameraCount, 2);

    registry.clearSelectedDevices();
    registry.replaceDevices(registry.devices);

    expect(registry.selectedDeviceIds, isEmpty);
  });

  test('registry rejects stale selections after device refresh', () {
    final registry = UsbDeviceRegistry();

    registry.replaceDevices(<UsbCameraDevice>[
      _camera('camera-1'),
      _camera('camera-2'),
    ]);
    registry.setDeviceSelected('camera-2', false);

    registry.replaceDevices(<UsbCameraDevice>[_camera('camera-2')]);

    expect(registry.devices, hasLength(1));
    expect(registry.selectedDeviceIds, isEmpty);

    registry.selectAllVideoDevices();

    expect(registry.selectedDeviceIds, <String>{'camera-2'});
    expect(registry.selectedDevice?.deviceId, 'camera-2');
  });

  test('registry reports USB devices without video cameras', () {
    final registry = UsbDeviceRegistry();

    registry.replaceDevices(const <UsbCameraDevice>[
      UsbCameraDevice(
        deviceId: 'hub-1',
        deviceName: 'USB Hub',
        vendorId: 1,
        productId: 1,
        permissionGranted: true,
        videoClass: false,
        interfaceCount: 1,
      ),
    ]);

    expect(registry.hasUsbDevices, isTrue);
    expect(registry.hasVideoCamera, isFalse);
    expect(registry.selectedVideoDevices, isEmpty);
  });
}

UsbCameraDevice _camera(String deviceId) {
  return UsbCameraDevice(
    deviceId: deviceId,
    deviceName: deviceId,
    vendorId: 2,
    productId: 1,
    permissionGranted: true,
    videoClass: true,
    interfaceCount: 1,
  );
}

import 'package:flutter_test/flutter_test.dart';

import 'package:xiangji/src/controller/usb_device_inventory_presenter.dart';
import 'package:xiangji/src/domain.dart';

void main() {
  const presenter = UsbDeviceInventoryPresenter();

  test('describes an empty inventory', () {
    expect(presenter.messageFor(const <UsbCameraDevice>[]), '未检测到 USB 设备。');
  });

  test('describes USB devices without video cameras', () {
    expect(
      presenter.messageFor(<UsbCameraDevice>[_device(videoClass: false)]),
      '检测到 USB 设备，但没有视频摄像头。',
    );
  });

  test('describes a mixed inventory with multiple video cameras', () {
    expect(
      presenter.messageFor(<UsbCameraDevice>[
        _device(deviceId: 'hub-1', videoClass: false),
        _device(deviceId: 'camera-1'),
        _device(deviceId: 'camera-2'),
      ]),
      '在 3 个 USB 设备中检测到 2 个 USB 摄像头。',
    );
  });
}

UsbCameraDevice _device({
  String deviceId = 'camera-1',
  bool videoClass = true,
}) {
  return UsbCameraDevice(
    deviceId: deviceId,
    deviceName: deviceId,
    vendorId: 1,
    productId: 1,
    permissionGranted: true,
    videoClass: videoClass,
    interfaceCount: 1,
  );
}

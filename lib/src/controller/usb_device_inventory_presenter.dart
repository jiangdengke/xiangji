import '../domain.dart';

class UsbDeviceInventoryPresenter {
  const UsbDeviceInventoryPresenter();

  String messageFor(Iterable<UsbCameraDevice> devices) {
    final deviceList = devices.toList(growable: false);
    final usbDeviceCount = deviceList.length;
    final videoCameraCount = deviceList.where((UsbCameraDevice device) {
      return device.videoClass;
    }).length;

    if (usbDeviceCount == 0) {
      return '未检测到 USB 设备。';
    }
    if (videoCameraCount == 0) {
      return '检测到 USB 设备，但没有视频摄像头。';
    }
    if (usbDeviceCount == 1 && videoCameraCount == 1) {
      return '已检测到 1 个 USB 摄像头。';
    }
    if (videoCameraCount == 1) {
      return '在 $usbDeviceCount 个 USB 设备中检测到 1 个 USB 摄像头。';
    }
    return '在 $usbDeviceCount 个 USB 设备中检测到 $videoCameraCount 个 USB 摄像头。';
  }
}

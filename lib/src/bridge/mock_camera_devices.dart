import '../domain.dart';

List<UsbCameraDevice> createMockCameraDevices() {
  return <UsbCameraDevice>[
    const UsbCameraDevice(
      deviceId: 'mock-camera-0',
      deviceName: '模拟 UVC 摄像头 1',
      vendorId: 0x1A2B,
      productId: 0x1001,
      permissionGranted: true,
      videoClass: true,
      interfaceCount: 1,
    ),
    const UsbCameraDevice(
      deviceId: 'mock-camera-1',
      deviceName: '模拟 UVC 摄像头 2',
      vendorId: 0x1A2B,
      productId: 0x1002,
      permissionGranted: true,
      videoClass: true,
      interfaceCount: 1,
    ),
    const UsbCameraDevice(
      deviceId: 'mock-hub-1',
      deviceName: '模拟 USB 集线器',
      vendorId: 0x1A2B,
      productId: 0x2001,
      permissionGranted: false,
      videoClass: false,
      interfaceCount: 2,
    ),
  ];
}

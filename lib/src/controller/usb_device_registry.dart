import '../domain.dart';

class UsbDeviceRegistry {
  List<UsbCameraDevice> _devices = <UsbCameraDevice>[];
  final Set<String> _selectedDeviceIds = <String>{};
  bool _selectionInitialized = false;

  List<UsbCameraDevice> get devices =>
      List<UsbCameraDevice>.unmodifiable(_devices);

  bool get hasUsbDevices => _devices.isNotEmpty;

  int get usbDeviceCount => _devices.length;

  bool get hasVideoCamera => _devices.any((UsbCameraDevice device) {
    return device.videoClass;
  });

  int get videoCameraCount => _devices.where((UsbCameraDevice device) {
    return device.videoClass;
  }).length;

  Set<String> get selectedDeviceIds =>
      Set<String>.unmodifiable(_selectedDeviceIds);

  List<UsbCameraDevice> get selectedDevices => _devices
      .where((UsbCameraDevice device) {
        return _selectedDeviceIds.contains(device.deviceId);
      })
      .toList(growable: false);

  List<UsbCameraDevice> get selectedVideoDevices => selectedDevices
      .where((UsbCameraDevice device) => device.videoClass)
      .toList(growable: false);

  int get selectedVideoCameraCount => selectedVideoDevices.length;

  bool get hasSelectedVideoCamera => selectedVideoCameraCount > 0;

  String? get selectedDeviceId =>
      _selectedDeviceIds.isEmpty ? null : _selectedDeviceIds.first;

  UsbCameraDevice? get selectedDevice =>
      selectedVideoDevices.isEmpty ? null : selectedVideoDevices.first;

  void replaceDevices(List<UsbCameraDevice> devices) {
    _devices = List<UsbCameraDevice>.unmodifiable(devices);
    if (_devices.isEmpty) {
      _selectedDeviceIds.clear();
      return;
    }

    final selectableDeviceIds = _devices
        .where((UsbCameraDevice device) => device.videoClass)
        .map((UsbCameraDevice device) => device.deviceId)
        .toSet();
    _selectedDeviceIds.removeWhere((String deviceId) {
      return !selectableDeviceIds.contains(deviceId);
    });

    if (!_selectionInitialized) {
      final videoDeviceIds = selectableDeviceIds.toList(growable: false);
      if (videoDeviceIds.isNotEmpty) {
        _selectedDeviceIds
          ..clear()
          ..addAll(videoDeviceIds);
        _selectionInitialized = true;
      }
    }
  }

  UsbCameraDevice? deviceById(String deviceId) {
    for (final device in _devices) {
      if (device.deviceId == deviceId) {
        return device;
      }
    }
    return null;
  }

  bool isDeviceSelected(String deviceId) {
    return _selectedDeviceIds.contains(deviceId);
  }

  bool setDeviceSelected(String deviceId, bool selected) {
    _selectionInitialized = true;
    return selected
        ? _selectedDeviceIds.add(deviceId)
        : _selectedDeviceIds.remove(deviceId);
  }

  int selectAllVideoDevices() {
    final videoDeviceIds = _devices
        .where((UsbCameraDevice device) => device.videoClass)
        .map((UsbCameraDevice device) => device.deviceId)
        .toSet();
    _selectionInitialized = true;
    _selectedDeviceIds
      ..clear()
      ..addAll(videoDeviceIds);
    return videoDeviceIds.length;
  }

  bool clearSelectedDevices() {
    if (_selectedDeviceIds.isEmpty) {
      return false;
    }

    _selectionInitialized = true;
    _selectedDeviceIds.clear();
    return true;
  }
}

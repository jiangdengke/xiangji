import '../domain.dart';
import '../live/live_stream_routing.dart';
import 'session_log_sink.dart';
import 'usb_device_registry.dart';

class SessionDeviceActions {
  SessionDeviceActions({
    required UsbDeviceRegistry deviceRegistry,
    required LiveStreamRouting routing,
    required void Function() maybeStartAfterPermission,
    required void Function() notifyListeners,
    required SessionLogSink logSink,
  }) : _deviceRegistry = deviceRegistry,
       _routing = routing,
       _maybeStartAfterPermission = maybeStartAfterPermission,
       _notifyListeners = notifyListeners,
       _logSink = logSink;

  final UsbDeviceRegistry _deviceRegistry;
  final LiveStreamRouting _routing;
  final void Function() _maybeStartAfterPermission;
  final void Function() _notifyListeners;
  final SessionLogSink _logSink;

  void setDeviceSelected(String deviceId, bool selected) {
    final device = _deviceRegistry.deviceById(deviceId);
    if (device == null) {
      _logSink(
        '找不到要选择的 USB 设备：$deviceId。',
        LogLevel.warning,
        null,
        true,
        LogTopic.device,
      );
      return;
    }
    if (!device.videoClass) {
      _logSink(
        '${device.deviceName} 不是视频摄像头，不能加入推流列表。',
        LogLevel.warning,
        null,
        true,
        LogTopic.device,
      );
      return;
    }

    final changed = _deviceRegistry.setDeviceSelected(deviceId, selected);
    if (!changed) {
      return;
    }

    _logSink(
      selected ? '已选择 ${device.deviceName}。' : '已取消选择 ${device.deviceName}。',
      LogLevel.info,
      null,
      true,
      LogTopic.device,
    );
    _notifyListeners();
    _maybeStartAfterPermission();
  }

  void selectAllVideoDevices() {
    final selectedCount = _deviceRegistry.selectAllVideoDevices();
    _logSink(
      selectedCount == 0 ? '没有可选的视频摄像头。' : '已选择全部 $selectedCount 个视频摄像头。',
      selectedCount == 0 ? LogLevel.warning : LogLevel.info,
      null,
      true,
      LogTopic.device,
    );
    _notifyListeners();
    _maybeStartAfterPermission();
  }

  void clearSelectedDevices() {
    if (!_deviceRegistry.clearSelectedDevices()) {
      return;
    }
    _logSink('已清空摄像头选择。', LogLevel.info, null, true, LogTopic.device);
    _notifyListeners();
  }

  void updateEndpointText(String value) {
    _routing.updateEndpointText(value);
    _notifyListeners();
  }

  void updateStreamIdText(String value) {
    _routing.updateStreamIdPrefix(value, _deviceRegistry.devices);
    _notifyListeners();
  }

  void updateDeviceStreamIdText(String deviceId, String value) {
    if (!_routing.setCustomStreamId(deviceId, value)) {
      return;
    }

    _notifyListeners();
  }

  void resetDeviceStreamId(String deviceId) {
    if (!_routing.resetDeviceStreamId(deviceId, _deviceRegistry.devices)) {
      return;
    }

    _notifyListeners();
  }
}

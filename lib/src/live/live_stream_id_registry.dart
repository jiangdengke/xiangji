import '../domain.dart';
import 'live_stream_id_policy.dart';

class LiveStreamIdRegistry {
  LiveStreamIdRegistry({
    String streamIdPrefix = 'camera-001',
    LiveStreamIdPolicy policy = const LiveStreamIdPolicy(),
  }) : _streamIdPrefix = streamIdPrefix.trim(),
       _policy = policy;

  String _streamIdPrefix;
  final LiveStreamIdPolicy _policy;
  final Map<String, String> _streamIdsByDeviceId = <String, String>{};
  final Set<String> _customStreamIdDeviceIds = <String>{};

  String get streamIdPrefix => _streamIdPrefix;
  Map<String, String> get streamIdsByDeviceId =>
      Map<String, String>.unmodifiable(_streamIdsByDeviceId);
  Iterable<String> get streamIds => _streamIdsByDeviceId.values;
  bool get isStreamIdPrefixValid => _policy.isValid(_streamIdPrefix);

  void updateStreamIdPrefix(String value, Iterable<UsbCameraDevice> devices) {
    _streamIdPrefix = value.trim();
    syncDevices(devices);
  }

  bool setCustomStreamId(String deviceId, String value) {
    if (!_streamIdsByDeviceId.containsKey(deviceId)) {
      return false;
    }
    _streamIdsByDeviceId[deviceId] = value.trim();
    _customStreamIdDeviceIds.add(deviceId);
    return true;
  }

  bool resetDeviceStreamId(String deviceId, Iterable<UsbCameraDevice> devices) {
    if (!_streamIdsByDeviceId.containsKey(deviceId)) {
      return false;
    }
    _customStreamIdDeviceIds.remove(deviceId);
    syncDevices(devices);
    return true;
  }

  void syncDevices(Iterable<UsbCameraDevice> devices) {
    final videoDevices = devices
        .where((UsbCameraDevice device) => device.videoClass)
        .toList(growable: false);
    final selectableDeviceIds = videoDevices
        .map((UsbCameraDevice device) => device.deviceId)
        .toSet();

    _streamIdsByDeviceId.removeWhere((String deviceId, _) {
      return !selectableDeviceIds.contains(deviceId);
    });
    _customStreamIdDeviceIds.removeWhere((String deviceId) {
      return !selectableDeviceIds.contains(deviceId);
    });

    for (var index = 0; index < videoDevices.length; index += 1) {
      final device = videoDevices[index];
      if (_customStreamIdDeviceIds.contains(device.deviceId)) {
        continue;
      }
      _streamIdsByDeviceId[device.deviceId] = _policy.defaultForDevice(
        prefix: _streamIdPrefix,
        index: index,
        total: videoDevices.length,
      );
    }
  }

  String streamIdForDeviceId(String deviceId) {
    return _streamIdsByDeviceId[deviceId] ?? '';
  }

  bool isDeviceStreamIdValid(String deviceId) {
    return _policy.isValid(streamIdForDeviceId(deviceId));
  }

  bool hasValidStreamIds(Iterable<UsbCameraDevice> selectedDevices) {
    return selectedDevices.every((UsbCameraDevice device) {
      return isDeviceStreamIdValid(device.deviceId);
    });
  }

  bool hasUniqueStreamIds(Iterable<UsbCameraDevice> selectedDevices) {
    final seen = <String>{};
    for (final device in selectedDevices) {
      if (!seen.add(streamIdForDeviceId(device.deviceId))) {
        return false;
      }
    }
    return true;
  }

  bool isDeviceStreamIdDuplicate(
    String deviceId,
    Iterable<UsbCameraDevice> selectedDevices,
  ) {
    final selectedIds = selectedDevices
        .map((UsbCameraDevice device) => device.deviceId)
        .toSet();
    if (!selectedIds.contains(deviceId)) {
      return false;
    }

    final streamId = streamIdForDeviceId(deviceId);
    var count = 0;
    for (final device in selectedDevices) {
      if (streamIdForDeviceId(device.deviceId) == streamId) {
        count += 1;
      }
    }
    return count > 1;
  }

  bool isDeviceStreamIdCustom(String deviceId) {
    return _customStreamIdDeviceIds.contains(deviceId);
  }

  String defaultStreamIdForDevice({required int index, required int total}) {
    return _policy.defaultForDevice(
      prefix: _streamIdPrefix,
      index: index,
      total: total,
    );
  }

  static bool isStreamIdValueValid(String value) {
    return const LiveStreamIdPolicy().isValid(value);
  }
}

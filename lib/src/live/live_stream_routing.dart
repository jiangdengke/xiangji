import '../domain.dart';
import 'live_stream_endpoint.dart';
import 'live_stream_id_registry.dart';

class LiveStreamRouting {
  LiveStreamRouting({
    String endpointText = '',
    String streamIdPrefix = 'camera',
  }) : _endpoint = LiveStreamEndpoint(endpointText: endpointText),
       _streamIds = LiveStreamIdRegistry(streamIdPrefix: streamIdPrefix);

  final LiveStreamEndpoint _endpoint;
  final LiveStreamIdRegistry _streamIds;

  String get endpointText => _endpoint.text;
  String get streamIdPrefix => _streamIds.streamIdPrefix;
  Map<String, String> get streamIdsByDeviceId => _streamIds.streamIdsByDeviceId;

  bool get isEndpointValid => _endpoint.isValid;
  bool get isStreamIdPrefixValid => _streamIds.isStreamIdPrefixValid;
  Uri? get liveEndpoint => _endpoint.uri;

  void updateEndpointText(String value) {
    _endpoint.updateText(value);
  }

  void updateStreamIdPrefix(String value, Iterable<UsbCameraDevice> devices) {
    _streamIds.updateStreamIdPrefix(value, devices);
  }

  bool setCustomStreamId(String deviceId, String value) {
    return _streamIds.setCustomStreamId(deviceId, value);
  }

  bool resetDeviceStreamId(String deviceId, Iterable<UsbCameraDevice> devices) {
    return _streamIds.resetDeviceStreamId(deviceId, devices);
  }

  void syncDevices(Iterable<UsbCameraDevice> devices) {
    _streamIds.syncDevices(devices);
  }

  String streamIdForDeviceId(String deviceId) {
    return _streamIds.streamIdForDeviceId(deviceId);
  }

  bool isDeviceStreamIdValid(String deviceId) {
    return _streamIds.isDeviceStreamIdValid(deviceId);
  }

  bool hasValidStreamIds(Iterable<UsbCameraDevice> selectedDevices) {
    return _streamIds.hasValidStreamIds(selectedDevices);
  }

  bool hasUniqueStreamIds(Iterable<UsbCameraDevice> selectedDevices) {
    return _streamIds.hasUniqueStreamIds(selectedDevices);
  }

  bool isDeviceStreamIdDuplicate(
    String deviceId,
    Iterable<UsbCameraDevice> selectedDevices,
  ) {
    return _streamIds.isDeviceStreamIdDuplicate(deviceId, selectedDevices);
  }

  bool isDeviceStreamIdCustom(String deviceId) {
    return _streamIds.isDeviceStreamIdCustom(deviceId);
  }

  String defaultStreamIdForDevice({required int index, required int total}) {
    return _streamIds.defaultStreamIdForDevice(index: index, total: total);
  }

  Uri endpointForStreamId(Uri endpoint, String streamId) {
    return _endpoint.endpointForStreamId(
      endpoint: endpoint,
      streamId: streamId,
      streamIdPrefix: streamIdPrefix,
      knownStreamIds: _streamIds.streamIds,
    );
  }

  static bool isStreamIdValueValid(String value) {
    return LiveStreamIdRegistry.isStreamIdValueValid(value);
  }

  static Uri? parseHttpEndpoint(String value) {
    return LiveStreamEndpoint.parseHttpEndpoint(value);
  }
}

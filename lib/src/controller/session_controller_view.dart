import '../domain.dart';
import '../live/live_stream_routing.dart';
import 'session_control_guard.dart';
import 'session_runtime_state.dart';
import 'stream_log_buffer.dart';
import 'usb_device_registry.dart';

class SessionControllerView {
  const SessionControllerView({
    required SessionRuntimeState state,
    required UsbDeviceRegistry deviceRegistry,
    required LiveStreamRouting routing,
    required StreamLogBuffer logBuffer,
    SessionControlGuard controlGuard = const SessionControlGuard(),
  }) : _state = state,
       _deviceRegistry = deviceRegistry,
       _routing = routing,
       _logBuffer = logBuffer,
       _controlGuard = controlGuard;

  final SessionRuntimeState _state;
  final UsbDeviceRegistry _deviceRegistry;
  final LiveStreamRouting _routing;
  final StreamLogBuffer _logBuffer;
  final SessionControlGuard _controlGuard;

  bool get bridgeSupported => _state.bridgeSupported;
  SessionPhase get phase => _state.phase;
  String get phaseLabel => _state.phaseLabel;
  String get statusMessage => _state.statusMessage;
  String get lastError => _state.lastError;
  List<UsbCameraDevice> get devices => _deviceRegistry.devices;
  bool get hasUsbDevices => _deviceRegistry.hasUsbDevices;
  int get usbDeviceCount => _deviceRegistry.usbDeviceCount;
  bool get hasVideoCamera => _deviceRegistry.hasVideoCamera;
  int get videoCameraCount => _deviceRegistry.videoCameraCount;
  Set<String> get selectedDeviceIds => _deviceRegistry.selectedDeviceIds;
  List<UsbCameraDevice> get selectedDevices => _deviceRegistry.selectedDevices;
  List<UsbCameraDevice> get selectedVideoDevices =>
      _deviceRegistry.selectedVideoDevices;
  int get selectedVideoCameraCount => _deviceRegistry.selectedVideoCameraCount;
  bool get hasSelectedVideoCamera => _deviceRegistry.hasSelectedVideoCamera;
  String? get selectedDeviceId => _deviceRegistry.selectedDeviceId;
  UsbCameraDevice? get selectedDevice => _deviceRegistry.selectedDevice;

  bool get isLiveStreaming => _state.isLiveStreaming;
  DateTime? get lastLiveEventAt => _state.lastLiveEventAt;
  List<StreamLogEntry> get logs => _logBuffer.entries;
  List<StreamLogEntry> get recentLogs => _logBuffer.recentEntries;
  StreamLogEntry? get latestLog => _logBuffer.latest;
  String get endpointText => _routing.endpointText;
  String get streamIdText => _routing.streamIdPrefix;
  Map<String, String> get streamIdsByDeviceId => _routing.streamIdsByDeviceId;

  bool get isEndpointValid => _routing.isEndpointValid;
  bool get isStreamIdValid => _routing.isStreamIdPrefixValid;

  bool get hasValidSelectedStreamIds {
    return _routing.hasValidStreamIds(selectedVideoDevices);
  }

  bool get hasUniqueSelectedStreamIds {
    return _routing.hasUniqueStreamIds(selectedVideoDevices);
  }

  bool get canStart {
    return _controlGuard.canStart(
      sessionActive: _state.sessionActive,
      phase: _state.phase,
      readiness: SessionStartReadiness(
        hasSelectedVideoCamera: hasSelectedVideoCamera,
        isEndpointValid: isEndpointValid,
        isStreamIdValid: isStreamIdValid,
        hasValidSelectedStreamIds: hasValidSelectedStreamIds,
        hasUniqueSelectedStreamIds: hasUniqueSelectedStreamIds,
      ),
    );
  }

  bool get canStop {
    return _controlGuard.canStop(
      sessionActive: _state.sessionActive,
      phase: _state.phase,
    );
  }

  bool isDeviceSelected(String deviceId) {
    return _deviceRegistry.isDeviceSelected(deviceId);
  }

  String streamIdForDeviceId(String deviceId) {
    return _routing.streamIdForDeviceId(deviceId);
  }

  bool isDeviceStreamIdValid(String deviceId) {
    return _routing.isDeviceStreamIdValid(deviceId);
  }

  bool isDeviceStreamIdDuplicate(String deviceId) {
    return _routing.isDeviceStreamIdDuplicate(deviceId, selectedVideoDevices);
  }

  bool isDeviceStreamIdCustom(String deviceId) {
    return _routing.isDeviceStreamIdCustom(deviceId);
  }
}

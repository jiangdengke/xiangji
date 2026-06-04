import 'package:flutter/foundation.dart';

import '../bridge/camera_bridge.dart';
import '../domain.dart';
import '../live/live_stream_publisher.dart';
import 'session_controller_composition.dart';

class XiangjiSessionController extends ChangeNotifier {
  XiangjiSessionController({
    required CameraBridge bridge,
    required LiveStreamPublisher livePublisher,
    String endpointText = '',
    String streamIdText = 'camera-001',
  }) {
    _composition = SessionControllerComposition(
      bridge: bridge,
      livePublisher: livePublisher,
      notifyListeners: notifyListeners,
      endpointText: endpointText,
      streamIdText: streamIdText,
    );
  }

  late final SessionControllerComposition _composition;

  bool get bridgeSupported => _composition.view.bridgeSupported;
  SessionPhase get phase => _composition.view.phase;
  String get phaseLabel => _composition.view.phaseLabel;
  String get statusMessage => _composition.view.statusMessage;
  String get lastError => _composition.view.lastError;
  List<UsbCameraDevice> get devices => _composition.view.devices;
  bool get hasUsbDevices => _composition.view.hasUsbDevices;
  int get usbDeviceCount => _composition.view.usbDeviceCount;
  bool get hasVideoCamera => _composition.view.hasVideoCamera;
  int get videoCameraCount => _composition.view.videoCameraCount;
  Set<String> get selectedDeviceIds => _composition.view.selectedDeviceIds;
  List<UsbCameraDevice> get selectedDevices => _composition.view.selectedDevices;
  List<UsbCameraDevice> get selectedVideoDevices =>
      _composition.view.selectedVideoDevices;
  int get selectedVideoCameraCount =>
      _composition.view.selectedVideoCameraCount;
  bool get hasSelectedVideoCamera =>
      _composition.view.hasSelectedVideoCamera;
  String? get selectedDeviceId => _composition.view.selectedDeviceId;
  UsbCameraDevice? get selectedDevice => _composition.view.selectedDevice;

  bool get isLiveStreaming => _composition.view.isLiveStreaming;
  DateTime? get lastLiveEventAt => _composition.view.lastLiveEventAt;
  List<StreamLogEntry> get logs => _composition.view.logs;
  List<StreamLogEntry> get recentLogs => _composition.view.recentLogs;
  StreamLogEntry? get latestLog => _composition.view.latestLog;
  String get endpointText => _composition.view.endpointText;
  String get streamIdText => _composition.view.streamIdText;
  Map<String, String> get streamIdsByDeviceId =>
      _composition.view.streamIdsByDeviceId;

  bool get isEndpointValid => _composition.view.isEndpointValid;

  bool get isStreamIdValid => _composition.view.isStreamIdValid;

  bool get hasValidSelectedStreamIds =>
      _composition.view.hasValidSelectedStreamIds;

  bool get hasUniqueSelectedStreamIds =>
      _composition.view.hasUniqueSelectedStreamIds;

  bool get canStart => _composition.view.canStart;

  bool get canStop => _composition.view.canStop;

  Future<void> initialize() => _composition.initialize();

  Future<void> refreshDevices() => _composition.refreshDevices();

  bool isDeviceSelected(String deviceId) {
    return _composition.view.isDeviceSelected(deviceId);
  }

  void selectDevice(String deviceId) {
    _composition.selectDevice(deviceId);
  }

  void toggleDeviceSelection(String deviceId) {
    _composition.toggleDeviceSelection(deviceId);
  }

  void setDeviceSelected(String deviceId, bool selected) {
    _composition.setDeviceSelected(deviceId, selected);
  }

  void selectAllVideoDevices() {
    _composition.selectAllVideoDevices();
  }

  void clearSelectedDevices() {
    _composition.clearSelectedDevices();
  }

  void updateEndpointText(String value) {
    _composition.updateEndpointText(value);
  }

  void updateStreamIdText(String value) {
    _composition.updateStreamIdText(value);
  }

  void updateDeviceStreamIdText(String deviceId, String value) {
    _composition.updateDeviceStreamIdText(deviceId, value);
  }

  void resetDeviceStreamId(String deviceId) {
    _composition.resetDeviceStreamId(deviceId);
  }

  Future<void> requestPermission() => _composition.requestPermission();

  Future<void> start() => _composition.start();

  Future<void> stop() => _composition.stop();

  void reportUnhandledError(Object error, StackTrace? stackTrace) {
    _composition.reportUnhandledError(error, stackTrace);
  }

  String streamIdForDeviceId(String deviceId) {
    return _composition.view.streamIdForDeviceId(deviceId);
  }

  bool isDeviceStreamIdValid(String deviceId) {
    return _composition.view.isDeviceStreamIdValid(deviceId);
  }

  bool isDeviceStreamIdDuplicate(String deviceId) {
    return _composition.view.isDeviceStreamIdDuplicate(deviceId);
  }

  bool isDeviceStreamIdCustom(String deviceId) {
    return _composition.view.isDeviceStreamIdCustom(deviceId);
  }

  @override
  void dispose() {
    _composition.dispose();
    super.dispose();
  }
}

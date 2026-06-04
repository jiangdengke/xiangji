import 'dart:async';

import '../domain.dart';
import 'session_control_guard.dart';
import 'session_device_actions.dart';
import 'session_live_orchestrator.dart';
import 'session_log_sink.dart';
import 'session_permission_flow.dart';
import 'session_runtime_state.dart';
import 'usb_device_registry.dart';

class SessionControllerActions {
  SessionControllerActions({
    required SessionRuntimeState state,
    required UsbDeviceRegistry deviceRegistry,
    required SessionDeviceActions deviceActions,
    required SessionPermissionFlow permissionFlow,
    required SessionLiveOrchestrator liveOrchestrator,
    required SessionLogSink logSink,
    SessionControlGuard controlGuard = const SessionControlGuard(),
  }) : _state = state,
       _deviceRegistry = deviceRegistry,
       _deviceActions = deviceActions,
       _permissionFlow = permissionFlow,
       _liveOrchestrator = liveOrchestrator,
       _logSink = logSink,
       _controlGuard = controlGuard;

  final SessionRuntimeState _state;
  final UsbDeviceRegistry _deviceRegistry;
  final SessionDeviceActions _deviceActions;
  final SessionPermissionFlow _permissionFlow;
  final SessionLiveOrchestrator _liveOrchestrator;
  final SessionLogSink _logSink;
  final SessionControlGuard _controlGuard;

  void selectDevice(String deviceId) {
    setDeviceSelected(deviceId, true);
  }

  void toggleDeviceSelection(String deviceId) {
    setDeviceSelected(deviceId, !_deviceRegistry.isDeviceSelected(deviceId));
  }

  void setDeviceSelected(String deviceId, bool selected) {
    _deviceActions.setDeviceSelected(deviceId, selected);
  }

  void selectAllVideoDevices() {
    _deviceActions.selectAllVideoDevices();
  }

  void clearSelectedDevices() {
    _deviceActions.clearSelectedDevices();
  }

  void updateEndpointText(String value) {
    _deviceActions.updateEndpointText(value);
  }

  void updateStreamIdText(String value) {
    _deviceActions.updateStreamIdText(value);
  }

  void updateDeviceStreamIdText(String deviceId, String value) {
    _deviceActions.updateDeviceStreamIdText(deviceId, value);
  }

  void resetDeviceStreamId(String deviceId) {
    _deviceActions.resetDeviceStreamId(deviceId);
  }

  Future<void> requestPermission() => _permissionFlow.requestPermission();

  Future<void> start() => _liveOrchestrator.start();

  Future<void> stop() => _liveOrchestrator.stop();

  void reportUnhandledError(Object error, StackTrace? stackTrace) {
    if (_state.disposed) {
      return;
    }

    _state.reportUnhandledError(error);
    _logSink(
      '捕获到未处理异常：$error',
      LogLevel.error,
      stackTrace,
      true,
      LogTopic.error,
    );
  }

  void maybeStartAfterPermission() {
    final shouldStart = _controlGuard.canStartAfterPermission(
      pendingStartAfterPermission: _state.pendingStartAfterPermission,
      disposed: _state.disposed,
      phase: _state.phase,
      selectedCameras: _deviceRegistry.selectedVideoDevices,
    );
    if (!shouldStart) {
      return;
    }

    _state.pendingStartAfterPermission = false;
    unawaited(start());
  }
}

import '../bridge/camera_bridge.dart';
import '../domain.dart';
import '../live/live_stream_routing.dart';
import 'camera_bridge_event_reducer.dart';
import 'session_log_sink.dart';
import 'session_runtime_state.dart';
import 'usb_device_inventory_presenter.dart';
import 'usb_device_registry.dart';

class SessionBridgeEventHandler {
  SessionBridgeEventHandler({
    required SessionRuntimeState state,
    required UsbDeviceRegistry deviceRegistry,
    required LiveStreamRouting routing,
    required UsbDeviceInventoryPresenter inventoryPresenter,
    required Future<void> Function() refreshDevices,
    required void Function() maybeStartAfterPermission,
    required bool Function(String deviceId) isDeviceSelected,
    required void Function() notifyListeners,
    required SessionLogSink logSink,
  }) : _state = state,
       _deviceRegistry = deviceRegistry,
       _routing = routing,
       _inventoryPresenter = inventoryPresenter,
       _refreshDevices = refreshDevices,
       _maybeStartAfterPermission = maybeStartAfterPermission,
       _isDeviceSelected = isDeviceSelected,
       _notifyListeners = notifyListeners,
       _logSink = logSink;

  final SessionRuntimeState _state;
  final UsbDeviceRegistry _deviceRegistry;
  final LiveStreamRouting _routing;
  final UsbDeviceInventoryPresenter _inventoryPresenter;
  final Future<void> Function() _refreshDevices;
  final void Function() _maybeStartAfterPermission;
  final bool Function(String deviceId) _isDeviceSelected;
  final void Function() _notifyListeners;
  final SessionLogSink _logSink;

  Future<void> handle(CameraBridgeEvent event) async {
    switch (event) {
      case CameraDevicesUpdated(:final devices):
        _replaceDevices(devices);
        _logSink(
          _inventoryPresenter.messageFor(_deviceRegistry.devices),
          LogLevel.info,
          null,
          true,
          LogTopic.device,
        );
        _notifyListeners();
        break;
      case CameraStatusEvent(:final phase, :final message):
        _handleCameraStatus(phase: phase, message: message);
        break;
      case CameraPermissionEvent(:final deviceId, :final granted):
        await _handlePermissionEvent(deviceId: deviceId, granted: granted);
        break;
      case CameraLogEvent(:final level, :final message):
        _logSink(message, level, null, true, LogTopic.system);
        break;
      case CameraErrorEvent(:final message, :final details):
        final nextState = reduceCameraErrorEvent(
          message: message,
          details: details,
        );
        _state.applyBridgeSessionState(nextState);
        _logSink(
          nextState.logMessage,
          nextState.logLevel,
          details,
          true,
          nextState.logTopic,
        );
        _notifyListeners();
        break;
    }
  }

  void _handleCameraStatus({
    required SessionPhase phase,
    required String message,
  }) {
    if (isBridgeDeviceRefreshWhileLive(
      liveActive: _state.liveActive,
      phase: phase,
    )) {
      _logSink(
        message.isEmpty ? '设备状态已刷新。' : message,
        LogLevel.info,
        null,
        true,
        LogTopic.device,
      );
      _notifyListeners();
      return;
    }

    final nextState = reduceCameraStatusEvent(
      phase: phase,
      message: message,
    );
    _state.applyBridgeSessionState(nextState);
    _logSink(
      nextState.logMessage,
      nextState.logLevel,
      null,
      true,
      nextState.logTopic,
    );
    _notifyListeners();
  }

  Future<void> _handlePermissionEvent({
    required String deviceId,
    required bool granted,
  }) async {
    if (!granted && _isDeviceSelected(deviceId)) {
      _state.pendingStartAfterPermission = false;
    }
    _logSink(
      granted ? '$deviceId 已授权。' : '$deviceId 权限被拒绝。',
      granted ? LogLevel.info : LogLevel.warning,
      null,
      true,
      LogTopic.permission,
    );
    await _refreshDevices();
    _maybeStartAfterPermission();
  }

  void _replaceDevices(List<UsbCameraDevice> devices) {
    _deviceRegistry.replaceDevices(devices);
    _routing.syncDevices(_deviceRegistry.devices);
  }
}

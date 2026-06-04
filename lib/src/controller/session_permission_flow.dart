import '../domain.dart';
import 'camera_permission_coordinator.dart';
import 'session_log_sink.dart';
import 'session_runtime_state.dart';

class SessionPermissionFlow {
  SessionPermissionFlow({
    required SessionRuntimeState state,
    required CameraPermissionCoordinator permissionCoordinator,
    required List<UsbCameraDevice> Function() selectedVideoDevices,
    required Future<void> Function() refreshDevices,
    required void Function() maybeStartAfterPermission,
    required void Function() notifyListeners,
    required SessionLogSink logSink,
  }) : _state = state,
       _permissionCoordinator = permissionCoordinator,
       _selectedVideoDevices = selectedVideoDevices,
       _refreshDevices = refreshDevices,
       _maybeStartAfterPermission = maybeStartAfterPermission,
       _notifyListeners = notifyListeners,
       _logSink = logSink;

  final SessionRuntimeState _state;
  final CameraPermissionCoordinator _permissionCoordinator;
  final List<UsbCameraDevice> Function() _selectedVideoDevices;
  final Future<void> Function() _refreshDevices;
  final void Function() _maybeStartAfterPermission;
  final void Function() _notifyListeners;
  final SessionLogSink _logSink;

  Future<void> requestPermission() async {
    final preparation = _permissionCoordinator.prepare(_selectedVideoDevices());
    if (!preparation.shouldRequest) {
      _logSink(
        preparation.message,
        preparation.logLevel,
        null,
        true,
        LogTopic.permission,
      );
      return;
    }

    _state.beginPermissionRequest(preparation.message);
    _notifyListeners();

    final logs = await _permissionCoordinator.requestPending(preparation);
    for (final log in logs) {
      _logSink(log.message, log.level, null, true, LogTopic.permission);
    }

    await _refreshDevices();
    _maybeStartAfterPermission();
    _notifyListeners();
  }
}

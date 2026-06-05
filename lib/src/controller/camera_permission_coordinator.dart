import '../bridge/camera_bridge.dart';
import '../domain.dart';

enum CameraPermissionPreparationKind {
  noneSelected,
  alreadyGranted,
  needsRequest,
}

class CameraPermissionPreparation {
  CameraPermissionPreparation._({
    required this.kind,
    required Iterable<UsbCameraDevice> selectedCameras,
    required Iterable<UsbCameraDevice> pendingDevices,
    required this.message,
    required this.logLevel,
  }) : selectedCameras = List<UsbCameraDevice>.unmodifiable(selectedCameras),
       pendingDevices = List<UsbCameraDevice>.unmodifiable(pendingDevices);

  factory CameraPermissionPreparation.noneSelected() {
    return CameraPermissionPreparation._(
      kind: CameraPermissionPreparationKind.noneSelected,
      selectedCameras: const <UsbCameraDevice>[],
      pendingDevices: const <UsbCameraDevice>[],
      message: '还没有选择要推流的 USB 摄像头。',
      logLevel: LogLevel.warning,
    );
  }

  factory CameraPermissionPreparation.alreadyGranted({
    required Iterable<UsbCameraDevice> selectedCameras,
  }) {
    final cameras = selectedCameras.toList(growable: false);
    return CameraPermissionPreparation._(
      kind: CameraPermissionPreparationKind.alreadyGranted,
      selectedCameras: cameras,
      pendingDevices: const <UsbCameraDevice>[],
      message: '当前选中的 ${cameras.length} 路摄像头都已授权。',
      logLevel: LogLevel.info,
    );
  }

  factory CameraPermissionPreparation.needsRequest({
    required Iterable<UsbCameraDevice> selectedCameras,
    required Iterable<UsbCameraDevice> pendingDevices,
  }) {
    final pending = pendingDevices.toList(growable: false);
    return CameraPermissionPreparation._(
      kind: CameraPermissionPreparationKind.needsRequest,
      selectedCameras: selectedCameras,
      pendingDevices: pending,
      message: '正在请求 ${pending.length} 路摄像头的 USB 权限。',
      logLevel: LogLevel.info,
    );
  }

  final CameraPermissionPreparationKind kind;
  final List<UsbCameraDevice> selectedCameras;
  final List<UsbCameraDevice> pendingDevices;
  final String message;
  final LogLevel logLevel;

  bool get shouldRequest =>
      kind == CameraPermissionPreparationKind.needsRequest;
}

class CameraPermissionRequestLog {
  const CameraPermissionRequestLog({
    required this.message,
    required this.level,
  });

  final String message;
  final LogLevel level;
}

class CameraPermissionCoordinator {
  CameraPermissionCoordinator({required CameraBridge bridge})
    : _bridge = bridge;

  final CameraBridge _bridge;

  CameraPermissionPreparation prepare(
    Iterable<UsbCameraDevice> selectedCameras,
  ) {
    final cameras = selectedCameras.toList(growable: false);
    if (cameras.isEmpty) {
      return CameraPermissionPreparation.noneSelected();
    }

    final pending = cameras
        .where((UsbCameraDevice device) => !device.permissionGranted)
        .toList(growable: false);
    if (pending.isEmpty) {
      return CameraPermissionPreparation.alreadyGranted(
        selectedCameras: cameras,
      );
    }

    return CameraPermissionPreparation.needsRequest(
      selectedCameras: cameras,
      pendingDevices: pending,
    );
  }

  Future<List<CameraPermissionRequestLog>> requestPending(
    CameraPermissionPreparation preparation,
  ) async {
    final logs = <CameraPermissionRequestLog>[];
    for (final device in preparation.pendingDevices) {
      final granted = await _bridge.requestPermission(device.deviceId);
      logs.add(
        CameraPermissionRequestLog(
          message: granted
              ? '${device.deviceName} 已授权。'
              : '已发送 ${device.deviceName} 的权限请求。',
          level: LogLevel.info,
        ),
      );
    }
    return logs;
  }
}

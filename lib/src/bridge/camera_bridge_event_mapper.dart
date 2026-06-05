import '../domain.dart';
import 'camera_bridge.dart';

class CameraBridgeEventMapper {
  const CameraBridgeEventMapper();

  CameraBridgeEvent? map(dynamic raw) {
    if (raw is! Map) {
      return null;
    }

    final map = Map<Object?, Object?>.from(raw);
    final type = map['type']?.toString();

    return switch (type) {
      'devices' => CameraDevicesUpdated(_parseDevices(map['devices'])),
      'status' => CameraStatusEvent(
        phase: _parsePhase(map['phase']?.toString()),
        message: map['message']?.toString() ?? '',
      ),
      'permission' => CameraPermissionEvent(
        deviceId: map['deviceId']?.toString() ?? '',
        granted: map['granted']?.toString() == 'true',
      ),
      'log' => CameraLogEvent(
        level: _parseLevel(map['level']?.toString()),
        message: map['message']?.toString() ?? '',
      ),
      'error' => CameraErrorEvent(
        message: map['message']?.toString() ?? 'Unknown native error.',
        details: map['details'],
      ),
      _ => null,
    };
  }

  List<UsbCameraDevice> _parseDevices(Object? value) {
    return (value as List? ?? const <Object?>[])
        .whereType<Map>()
        .map(
          (Map map) => UsbCameraDevice.fromMap(Map<Object?, Object?>.from(map)),
        )
        .toList(growable: false);
  }

  SessionPhase _parsePhase(String? value) {
    return switch (value) {
      'discovering' => SessionPhase.discovering,
      'ready' => SessionPhase.ready,
      'permissionRequested' => SessionPhase.permissionRequested,
      'starting' => SessionPhase.starting,
      'streaming' => SessionPhase.streaming,
      'stopping' => SessionPhase.stopping,
      'error' => SessionPhase.error,
      _ => SessionPhase.idle,
    };
  }

  LogLevel _parseLevel(String? value) {
    return switch (value) {
      'debug' => LogLevel.debug,
      'warning' => LogLevel.warning,
      'error' => LogLevel.error,
      _ => LogLevel.info,
    };
  }
}

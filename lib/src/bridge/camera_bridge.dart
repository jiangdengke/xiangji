import '../domain.dart';

abstract class CameraBridge {
  Stream<CameraBridgeEvent> get events;

  Future<bool> isSupported();

  Future<List<UsbCameraDevice>> listDevices();

  Future<bool> requestPermission(String deviceId);

  Future<void> dispose();
}

sealed class CameraBridgeEvent {
  const CameraBridgeEvent();
}

final class CameraDevicesUpdated extends CameraBridgeEvent {
  const CameraDevicesUpdated(this.devices);

  final List<UsbCameraDevice> devices;
}

final class CameraStatusEvent extends CameraBridgeEvent {
  const CameraStatusEvent({required this.phase, required this.message});

  final SessionPhase phase;
  final String message;
}

final class CameraPermissionEvent extends CameraBridgeEvent {
  const CameraPermissionEvent({required this.deviceId, required this.granted});

  final String deviceId;
  final bool granted;
}

final class CameraLogEvent extends CameraBridgeEvent {
  const CameraLogEvent({required this.level, required this.message});

  final LogLevel level;
  final String message;
}

final class CameraErrorEvent extends CameraBridgeEvent {
  const CameraErrorEvent({required this.message, this.details});

  final String message;
  final Object? details;
}

import '../domain.dart';
import 'session_phase_presenter.dart';

class SessionStartReadiness {
  const SessionStartReadiness({
    required this.hasSelectedVideoCamera,
    required this.isEndpointValid,
    required this.isStreamIdValid,
    required this.hasValidSelectedStreamIds,
    required this.hasUniqueSelectedStreamIds,
  });

  final bool hasSelectedVideoCamera;
  final bool isEndpointValid;
  final bool isStreamIdValid;
  final bool hasValidSelectedStreamIds;
  final bool hasUniqueSelectedStreamIds;
}

class SessionControlGuard {
  const SessionControlGuard();

  bool canStart({
    required bool sessionActive,
    required SessionPhase phase,
    required SessionStartReadiness readiness,
  }) {
    return readiness.hasSelectedVideoCamera &&
        !sessionActive &&
        phase != SessionPhase.starting &&
        phase != SessionPhase.streaming &&
        phase != SessionPhase.stopping &&
        readiness.isEndpointValid &&
        readiness.isStreamIdValid &&
        readiness.hasValidSelectedStreamIds &&
        readiness.hasUniqueSelectedStreamIds;
  }

  bool canStop({required bool sessionActive, required SessionPhase phase}) {
    return sessionActive ||
        phase == SessionPhase.streaming ||
        phase == SessionPhase.starting;
  }

  bool canStartAfterPermission({
    required bool pendingStartAfterPermission,
    required bool disposed,
    required SessionPhase phase,
    required Iterable<UsbCameraDevice> selectedCameras,
  }) {
    if (!pendingStartAfterPermission ||
        disposed ||
        isActiveSessionPhase(phase)) {
      return false;
    }
    final cameras = selectedCameras.toList(growable: false);
    if (cameras.isEmpty) {
      return false;
    }
    return cameras.every((UsbCameraDevice device) {
      return device.permissionGranted;
    });
  }
}

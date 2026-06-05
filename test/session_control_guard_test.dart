import 'package:flutter_test/flutter_test.dart';

import 'package:xiangji/src/controller/session_control_guard.dart';
import 'package:xiangji/src/domain.dart';

void main() {
  const guard = SessionControlGuard();
  const readyToStart = SessionStartReadiness(
    hasSelectedVideoCamera: true,
    isEndpointValid: true,
    isStreamIdValid: true,
    hasValidSelectedStreamIds: true,
    hasUniqueSelectedStreamIds: true,
  );

  test('allows start only when selection and routing are valid', () {
    expect(
      guard.canStart(
        sessionActive: false,
        phase: SessionPhase.ready,
        readiness: readyToStart,
      ),
      isTrue,
    );

    expect(
      guard.canStart(
        sessionActive: false,
        phase: SessionPhase.ready,
        readiness: const SessionStartReadiness(
          hasSelectedVideoCamera: true,
          isEndpointValid: true,
          isStreamIdValid: true,
          hasValidSelectedStreamIds: true,
          hasUniqueSelectedStreamIds: false,
        ),
      ),
      isFalse,
    );
  });

  test('blocks start while session is active or transitioning', () {
    for (final phase in <SessionPhase>[
      SessionPhase.starting,
      SessionPhase.streaming,
      SessionPhase.stopping,
    ]) {
      expect(
        guard.canStart(
          sessionActive: false,
          phase: phase,
          readiness: readyToStart,
        ),
        isFalse,
      );
    }

    expect(
      guard.canStart(
        sessionActive: true,
        phase: SessionPhase.ready,
        readiness: readyToStart,
      ),
      isFalse,
    );
  });

  test('keeps stop available during active live phases', () {
    expect(
      guard.canStop(sessionActive: false, phase: SessionPhase.starting),
      isTrue,
    );
    expect(
      guard.canStop(sessionActive: false, phase: SessionPhase.streaming),
      isTrue,
    );
    expect(
      guard.canStop(sessionActive: true, phase: SessionPhase.ready),
      isTrue,
    );
    expect(
      guard.canStop(sessionActive: false, phase: SessionPhase.ready),
      isFalse,
    );
  });

  test(
    'allows permission continuation only after all selected cameras grant',
    () {
      expect(
        guard.canStartAfterPermission(
          pendingStartAfterPermission: true,
          disposed: false,
          phase: SessionPhase.ready,
          selectedCameras: <UsbCameraDevice>[
            _camera('camera-1', permissionGranted: true),
            _camera('camera-2', permissionGranted: true),
          ],
        ),
        isTrue,
      );

      expect(
        guard.canStartAfterPermission(
          pendingStartAfterPermission: true,
          disposed: false,
          phase: SessionPhase.ready,
          selectedCameras: <UsbCameraDevice>[
            _camera('camera-1', permissionGranted: true),
            _camera('camera-2', permissionGranted: false),
          ],
        ),
        isFalse,
      );
    },
  );
}

UsbCameraDevice _camera(String deviceId, {required bool permissionGranted}) {
  return UsbCameraDevice(
    deviceId: deviceId,
    deviceName: deviceId,
    vendorId: 1,
    productId: 1,
    permissionGranted: permissionGranted,
    videoClass: true,
    interfaceCount: 1,
  );
}

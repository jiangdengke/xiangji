import 'package:flutter_test/flutter_test.dart';

import 'package:xiangji/src/domain.dart';
import 'package:xiangji/src/live/live_stream_routing.dart';
import 'package:xiangji/src/live/live_stream_start_preparer.dart';

void main() {
  test('rejects when no cameras are selected', () {
    final preparation = _preparer().prepare(const <UsbCameraDevice>[]);

    expect(preparation.isRejected, isTrue);
    expect(preparation.topic, LogTopic.device);
  });

  test('rejects duplicate stream ids before endpoint startup', () {
    final routing = _routing()..syncDevices(_cameras);
    routing.setCustomStreamId('camera-2', 'camera-001-01');

    final preparation = LiveStreamStartPreparer(
      routing: routing,
    ).prepare(_cameras);

    expect(preparation.isRejected, isTrue);
    expect(preparation.message, contains('流 ID 不能重复'));
  });

  test('requires permission for unauthorized selected cameras', () {
    final unauthorizedCamera = _camera(
      'camera-1',
      'Camera 1',
      permissionGranted: false,
    );
    final routing = _routing()
      ..syncDevices(<UsbCameraDevice>[unauthorizedCamera]);

    final preparation = LiveStreamStartPreparer(
      routing: routing,
    ).prepare(<UsbCameraDevice>[unauthorizedCamera]);

    expect(preparation.requiresPermission, isTrue);
    expect(preparation.pendingPermissionDevices, <UsbCameraDevice>[
      unauthorizedCamera,
    ]);
  });

  test('returns ready preparation with selected cameras and endpoint', () {
    final routing = _routing()..syncDevices(_cameras);

    final preparation = LiveStreamStartPreparer(
      routing: routing,
    ).prepare(_cameras);

    expect(preparation.isReady, isTrue);
    expect(preparation.selectedCameras, _cameras);
    expect(preparation.baseEndpoint, isNotNull);
  });
}

LiveStreamStartPreparer _preparer() {
  return LiveStreamStartPreparer(routing: _routing());
}

LiveStreamRouting _routing() {
  return LiveStreamRouting(
    endpointText: 'http://127.0.0.1:8080/whip/camera-001',
    streamIdPrefix: 'camera-001',
  );
}

final _cameras = <UsbCameraDevice>[
  _camera('camera-1', 'Camera 1'),
  _camera('camera-2', 'Camera 2'),
];

UsbCameraDevice _camera(
  String deviceId,
  String deviceName, {
  bool permissionGranted = true,
}) {
  return UsbCameraDevice(
    deviceId: deviceId,
    deviceName: deviceName,
    vendorId: 1,
    productId: 1,
    permissionGranted: permissionGranted,
    videoClass: true,
    interfaceCount: 1,
  );
}

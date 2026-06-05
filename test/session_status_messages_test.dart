import 'package:flutter_test/flutter_test.dart';

import 'package:xiangji/src/controller/session_status_messages.dart';
import 'package:xiangji/src/domain.dart';
import 'package:xiangji/src/live/live_stream_start_models.dart';

void main() {
  const messages = SessionStatusMessages();

  test('formats live start messages for one or many cameras', () {
    expect(
      messages.liveStarting(
        LiveStreamStartPreparation.ready(
          selectedCameras: <UsbCameraDevice>[_camera('camera-1', 'Camera 1')],
          baseEndpoint: Uri.parse('http://127.0.0.1:9090/offer/camera1'),
        ),
      ),
      '正在从 Camera 1 启动 WebRTC 实时推流。',
    );

    expect(
      messages.liveStarting(
        LiveStreamStartPreparation.ready(
          selectedCameras: <UsbCameraDevice>[
            _camera('camera-1', 'Camera 1'),
            _camera('camera-2', 'Camera 2'),
          ],
          baseEndpoint: Uri.parse('http://127.0.0.1:9090/offer/camera1'),
        ),
      ),
      '正在启动 2 路 WebRTC 实时推流。',
    );
  });

  test('formats live started messages for one or many streams', () {
    expect(
      messages.liveStarted(
        LiveStreamStartResult(
          streams: <LiveStreamStartedStream>[_stream('camera1')],
        ),
      ),
      'WebRTC 实时推流已启动，流 ID：camera1。',
    );

    expect(
      messages.liveStarted(
        LiveStreamStartResult(
          streams: <LiveStreamStartedStream>[
            _stream('camera1'),
            _stream('camera2'),
          ],
        ),
      ),
      '已启动 2 路 WebRTC 实时推流：camera1, camera2。',
    );
  });
}

LiveStreamStartedStream _stream(String streamId) {
  final camera = _camera(streamId, streamId);
  return LiveStreamStartedStream(
    camera: camera,
    streamId: streamId,
    endpoint: Uri.parse('http://127.0.0.1:9090/offer/$streamId'),
  );
}

UsbCameraDevice _camera(String deviceId, String deviceName) {
  return UsbCameraDevice(
    deviceId: deviceId,
    deviceName: deviceName,
    vendorId: 1,
    productId: 1,
    permissionGranted: true,
    videoClass: true,
    interfaceCount: 1,
  );
}

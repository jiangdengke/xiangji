import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:xiangji/src/bridge/camera_bridge.dart';
import 'package:xiangji/src/controller/xiangji_session_controller.dart';
import 'package:xiangji/src/domain.dart';
import 'package:xiangji/src/upload/segment_uploader.dart';

void main() {
  test('controller uploads segments emitted by the bridge', () async {
    final bridge = _TestBridge();
    final uploader = _RecordingUploader();
    final controller = XiangjiSessionController(
      bridge: bridge,
      uploader: uploader,
      endpointText: 'http://127.0.0.1:8080/api/camera/segments',
      streamIdText: 'unit-stream',
      fragmentDurationText: '2000',
    );

    await controller.initialize();
    await controller.start();

    await Future<void>.delayed(const Duration(milliseconds: 200));

    expect(controller.phase, SessionPhase.streaming);
    expect(controller.uploadedSegments, 1);
    expect(uploader.uploads, hasLength(1));
    expect(uploader.uploads.single.segment.streamId, 'unit-stream');

    controller.dispose();
  });
}

class _TestBridge implements CameraBridge {
  final StreamController<CameraBridgeEvent> _events =
      StreamController<CameraBridgeEvent>.broadcast();

  @override
  Stream<CameraBridgeEvent> get events => _events.stream;

  @override
  Future<bool> isSupported() async => true;

  @override
  Future<List<UsbCameraDevice>> listDevices() async {
    return <UsbCameraDevice>[
      const UsbCameraDevice(
        deviceId: 'usb-1',
        deviceName: 'Unit Test Camera',
        vendorId: 1,
        productId: 2,
        permissionGranted: true,
        videoClass: true,
        interfaceCount: 1,
      ),
    ];
  }

  @override
  Future<bool> requestPermission(String deviceId) async => true;

  @override
  Future<void> startSession(CameraSessionRequest request) async {
    final file = File(
      '${Directory.systemTemp.path}/xiangji_test_${DateTime.now().microsecondsSinceEpoch}.mp4',
    );
    final payload = List<int>.generate(1024, (int index) => index % 255);
    await file.writeAsBytes(payload, flush: true);

    _events.add(
      CameraStatusEvent(phase: SessionPhase.starting, message: 'starting'),
    );
    _events.add(
      CameraSegmentReadyEvent(
        CameraSegment(
          segmentId: 'segment-1',
          deviceId: request.deviceId,
          streamId: request.streamId,
          filePath: file.path,
          sequence: 1,
          durationMs: request.fragmentDurationMs,
          byteLength: payload.length,
          capturedAt: DateTime.now(),
        ),
      ),
    );
    _events.add(
      CameraStatusEvent(phase: SessionPhase.streaming, message: 'streaming'),
    );
  }

  @override
  Future<void> stopSession() async {}

  @override
  Future<void> dispose() async {
    await _events.close();
  }
}

class _RecordingUploader implements SegmentUploader {
  final List<_UploadCall> uploads = <_UploadCall>[];

  @override
  Future<UploadReceipt> uploadSegment({
    required CameraSegment segment,
    required UploadTarget target,
  }) async {
    uploads.add(_UploadCall(segment: segment, target: target));
    return UploadReceipt(
      endpoint: target.endpoint,
      statusCode: 200,
      bytesSent: segment.byteLength,
      responseBody: 'ok',
    );
  }

  @override
  Future<void> dispose() async {}
}

class _UploadCall {
  const _UploadCall({required this.segment, required this.target});

  final CameraSegment segment;
  final UploadTarget target;
}

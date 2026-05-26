import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:xiangji/src/bridge/camera_bridge.dart';
import 'package:xiangji/src/controller/xiangji_session_controller.dart';
import 'package:xiangji/src/domain.dart';
import 'package:xiangji/src/upload/segment_uploader.dart';

void main() {
  test(
    'controller uploads segments emitted by multiple camera sessions',
    () async {
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
      expect(controller.selectedVideoCameraCount, 2);

      await controller.start();

      await Future<void>.delayed(const Duration(milliseconds: 200));

      expect(controller.phase, SessionPhase.streaming);
      expect(bridge.startRequests, hasLength(2));
      expect(controller.uploadedSegments, 2);
      expect(uploader.uploads, hasLength(2));
      expect(
        uploader.uploads.map((_UploadCall upload) => upload.segment.deviceId),
        containsAll(<String>['usb-1', 'usb-2']),
      );
      expect(
        uploader.uploads.map((_UploadCall upload) => upload.segment.streamId),
        containsAll(<String>['unit-stream-01', 'unit-stream-02']),
      );

      controller.dispose();
    },
  );

  test('controller distinguishes USB devices from video cameras', () async {
    final bridge = _TestBridge(
      devices: const <UsbCameraDevice>[
        UsbCameraDevice(
          deviceId: 'usb-hub-1',
          deviceName: 'Unit Test Hub',
          vendorId: 3,
          productId: 4,
          permissionGranted: true,
          videoClass: false,
          interfaceCount: 1,
        ),
      ],
    );
    final controller = XiangjiSessionController(
      bridge: bridge,
      uploader: _RecordingUploader(),
    );

    await controller.initialize();

    expect(controller.hasUsbDevices, isTrue);
    expect(controller.hasVideoCamera, isFalse);
    expect(controller.canStart, isFalse);
    expect(controller.statusMessage, '检测到 USB 设备，但没有视频摄像头。');

    controller.dispose();
  });

  test('controller keeps stop available after a stale ready status', () async {
    final bridge = _TestBridge();
    final controller = XiangjiSessionController(
      bridge: bridge,
      uploader: _RecordingUploader(),
      endpointText: 'http://127.0.0.1:8080/api/camera/segments',
    );

    await controller.initialize();
    await controller.start();
    await Future<void>.delayed(const Duration(milliseconds: 200));

    expect(controller.canStop, isTrue);

    bridge.emitStatus(SessionPhase.ready, '设备列表已刷新。');
    await Future<void>.delayed(Duration.zero);

    expect(controller.phase, SessionPhase.ready);
    expect(controller.canStop, isTrue);

    await controller.stop();

    expect(bridge.stopRequests, 1);
    expect(controller.canStop, isFalse);

    controller.dispose();
  });
}

class _TestBridge implements CameraBridge {
  _TestBridge({List<UsbCameraDevice>? devices})
    : _devices =
          devices ??
          const <UsbCameraDevice>[
            UsbCameraDevice(
              deviceId: 'usb-1',
              deviceName: 'Unit Test Camera 1',
              vendorId: 1,
              productId: 2,
              permissionGranted: true,
              videoClass: true,
              interfaceCount: 1,
            ),
            UsbCameraDevice(
              deviceId: 'usb-2',
              deviceName: 'Unit Test Camera 2',
              vendorId: 1,
              productId: 3,
              permissionGranted: true,
              videoClass: true,
              interfaceCount: 1,
            ),
          ];

  final StreamController<CameraBridgeEvent> _events =
      StreamController<CameraBridgeEvent>.broadcast();
  final List<UsbCameraDevice> _devices;
  final List<CameraSessionRequest> startRequests = <CameraSessionRequest>[];
  int stopRequests = 0;

  @override
  Stream<CameraBridgeEvent> get events => _events.stream;

  @override
  Future<bool> isSupported() async => true;

  @override
  Future<List<UsbCameraDevice>> listDevices() async {
    return List<UsbCameraDevice>.unmodifiable(_devices);
  }

  @override
  Future<bool> requestPermission(String deviceId) async => true;

  @override
  Future<void> startSession(CameraSessionRequest request) async {
    startRequests.add(request);
    final sequence = startRequests.length;
    final file = File(
      '${Directory.systemTemp.path}/xiangji_test_${DateTime.now().microsecondsSinceEpoch}.mp4',
    );
    final payload = List<int>.generate(1024, (int index) => index % 255);
    await file.writeAsBytes(payload, flush: true);

    _events.add(
      CameraStatusEvent(phase: SessionPhase.starting, message: '开始中'),
    );
    _events.add(
      CameraSegmentReadyEvent(
        CameraSegment(
          segmentId: 'segment-$sequence',
          deviceId: request.deviceId,
          cameraId: 'test-camera-${request.deviceId}',
          streamId: request.streamId,
          filePath: file.path,
          sequence: sequence,
          durationMs: request.fragmentDurationMs,
          byteLength: payload.length,
          capturedAt: DateTime.now(),
        ),
      ),
    );
    _events.add(
      CameraStatusEvent(phase: SessionPhase.streaming, message: '录制中'),
    );
  }

  @override
  Future<void> stopSession() async {
    stopRequests += 1;
  }

  void emitStatus(SessionPhase phase, String message) {
    _events.add(CameraStatusEvent(phase: phase, message: message));
  }

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

import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:xiangji/src/bridge/camera_bridge.dart';
import 'package:xiangji/src/controller/xiangji_session_controller.dart';
import 'package:xiangji/src/domain.dart';
import 'package:xiangji/src/live/live_stream_publisher.dart';
import 'package:xiangji/src/upload/segment_uploader.dart';

void main() {
  test('controller starts WebRTC with the selected camera stream ID', () async {
    final bridge = _TestBridge();
    final livePublisher = _RecordingLivePublisher();
    final controller = XiangjiSessionController(
      bridge: bridge,
      uploader: _RecordingUploader(),
      livePublisher: livePublisher,
      endpointText: 'http://127.0.0.1:8080/whip/unit-stream',
      streamIdText: 'unit-stream',
    );

    await controller.initialize();
    expect(controller.selectedVideoCameraCount, 2);
    expect(controller.streamIdForDeviceId('usb-1'), 'unit-stream-01');
    expect(controller.streamIdForDeviceId('usb-2'), 'unit-stream-02');

    await controller.start();
    await Future<void>.delayed(Duration.zero);

    expect(controller.phase, SessionPhase.streaming);
    expect(controller.isLiveStreaming, isTrue);
    expect(livePublisher.startConfigs, hasLength(1));
    expect(
      livePublisher.startConfigs.single.endpoint.path,
      '/whip/unit-stream-01',
    );
    expect(livePublisher.startConfigs.single.streamId, 'unit-stream-01');
    expect(
      livePublisher.startConfigs.single.cameraName,
      'Unit Test Camera 1',
    );
    expect(bridge.startRequests, isEmpty);

    controller.dispose();
  });

  test('controller allows a custom stream ID per detected camera', () async {
    final bridge = _TestBridge();
    final livePublisher = _RecordingLivePublisher();
    final controller = XiangjiSessionController(
      bridge: bridge,
      uploader: _RecordingUploader(),
      livePublisher: livePublisher,
      endpointText: 'http://127.0.0.1:8080/whip/camera-001',
      streamIdText: 'camera-001',
    );

    await controller.initialize();
    controller
      ..setDeviceSelected('usb-1', false)
      ..updateDeviceStreamIdText('usb-2', 'loading-bay');

    expect(controller.streamIdForDeviceId('usb-1'), 'camera-001-01');
    expect(controller.streamIdForDeviceId('usb-2'), 'loading-bay');
    expect(controller.isDeviceStreamIdCustom('usb-2'), isTrue);
    expect(controller.canStart, isTrue);

    await controller.start();
    await Future<void>.delayed(Duration.zero);

    expect(livePublisher.startConfigs, hasLength(1));
    expect(livePublisher.startConfigs.single.streamId, 'loading-bay');
    expect(
      livePublisher.startConfigs.single.endpoint.path,
      '/whip/loading-bay',
    );
    expect(
      livePublisher.startConfigs.single.cameraName,
      'Unit Test Camera 2',
    );

    controller.dispose();
  });

  test('controller blocks duplicate selected camera stream IDs', () async {
    final bridge = _TestBridge();
    final livePublisher = _RecordingLivePublisher();
    final controller = XiangjiSessionController(
      bridge: bridge,
      uploader: _RecordingUploader(),
      livePublisher: livePublisher,
      endpointText: 'http://127.0.0.1:8080/whip/camera-001',
      streamIdText: 'camera-001',
    );

    await controller.initialize();
    controller.updateDeviceStreamIdText('usb-2', 'camera-001-01');

    expect(controller.hasValidSelectedStreamIds, isTrue);
    expect(controller.hasUniqueSelectedStreamIds, isFalse);
    expect(controller.isDeviceStreamIdDuplicate('usb-1'), isTrue);
    expect(controller.isDeviceStreamIdDuplicate('usb-2'), isTrue);
    expect(controller.canStart, isFalse);

    await controller.start();

    expect(livePublisher.startConfigs, isEmpty);
    expect(
      controller.latestLog?.message,
      contains('选中摄像头的流 ID 不能重复'),
    );

    controller.dispose();
  });

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
      livePublisher: _RecordingLivePublisher(),
    );

    await controller.initialize();

    expect(controller.hasUsbDevices, isTrue);
    expect(controller.hasVideoCamera, isFalse);
    expect(controller.canStart, isFalse);
    expect(controller.statusMessage, '检测到 USB 设备，但没有视频摄像头。');

    controller.dispose();
  });

  test('controller does not start when WHIP endpoint is not configured', () async {
    final bridge = _TestBridge();
    final livePublisher = _RecordingLivePublisher();
    final controller = XiangjiSessionController(
      bridge: bridge,
      uploader: _RecordingUploader(),
      livePublisher: livePublisher,
    );

    await controller.initialize();
    expect(controller.hasSelectedVideoCamera, isTrue);
    expect(controller.isEndpointValid, isFalse);
    expect(controller.canStart, isFalse);

    await controller.start();

    expect(livePublisher.startConfigs, isEmpty);
    expect(controller.phase, SessionPhase.ready);
    expect(controller.lastError, isEmpty);
    expect(
      controller.latestLog?.message,
      contains('请输入有效的 HTTP 或 HTTPS WebRTC 推流地址'),
    );

    controller.dispose();
  });

  test('controller keeps app state after live publisher start failure', () async {
    final bridge = _TestBridge();
    final livePublisher = _FailingLivePublisher();
    final controller = XiangjiSessionController(
      bridge: bridge,
      uploader: _RecordingUploader(),
      livePublisher: livePublisher,
      endpointText: 'http://127.0.0.1:8080/whip/camera-001',
    );

    await controller.initialize();
    await controller.start();

    expect(livePublisher.startRequests, 1);
    expect(controller.phase, SessionPhase.error);
    expect(controller.isLiveStreaming, isFalse);
    expect(controller.lastError, contains('测试推流失败'));
    expect(controller.latestLog?.message, contains('启动失败'));

    controller.dispose();
  });

  test('controller keeps stop available after a stale ready status', () async {
    final bridge = _TestBridge();
    final livePublisher = _RecordingLivePublisher();
    final controller = XiangjiSessionController(
      bridge: bridge,
      uploader: _RecordingUploader(),
      livePublisher: livePublisher,
      endpointText: 'http://127.0.0.1:8080/whip/camera-001',
    );

    await controller.initialize();
    await controller.start();
    await Future<void>.delayed(const Duration(milliseconds: 200));

    expect(controller.canStop, isTrue);

    bridge.emitStatus(SessionPhase.ready, '设备列表已刷新。');
    await Future<void>.delayed(Duration.zero);

    expect(controller.phase, SessionPhase.streaming);
    expect(controller.canStop, isTrue);

    await controller.stop();

    expect(bridge.stopRequests, 0);
    expect(livePublisher.stopRequests, 1);
    expect(controller.canStop, isFalse);

    controller.dispose();
  });
}

class _RecordingLivePublisher implements LiveStreamPublisher {
  final StreamController<LivePublisherStatus> _statuses =
      StreamController<LivePublisherStatus>.broadcast();
  final List<LiveStreamConfig> startConfigs = <LiveStreamConfig>[];
  int stopRequests = 0;

  @override
  Stream<LivePublisherStatus> get statuses => _statuses.stream;

  @override
  Future<void> start(LiveStreamConfig config) async {
    startConfigs.add(config);
    _statuses.add(
      const LivePublisherStatus(
        phase: LivePublisherPhase.streaming,
        message: '测试推流中',
      ),
    );
  }

  @override
  Future<void> stop() async {
    stopRequests += 1;
    _statuses.add(
      const LivePublisherStatus(
        phase: LivePublisherPhase.stopped,
        message: '测试推流已停止',
      ),
    );
  }

  @override
  Future<void> dispose() async {
    await _statuses.close();
  }
}

class _FailingLivePublisher implements LiveStreamPublisher {
  final StreamController<LivePublisherStatus> _statuses =
      StreamController<LivePublisherStatus>.broadcast();
  int startRequests = 0;

  @override
  Stream<LivePublisherStatus> get statuses => _statuses.stream;

  @override
  Future<void> start(LiveStreamConfig config) async {
    startRequests += 1;
    throw StateError('测试推流失败');
  }

  @override
  Future<void> stop() async {}

  @override
  Future<void> dispose() async {
    await _statuses.close();
  }
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
      CameraStatusEvent(phase: SessionPhase.streaming, message: '进行中'),
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
  @override
  Future<UploadReceipt> uploadSegment({
    required CameraSegment segment,
    required UploadTarget target,
  }) async {
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

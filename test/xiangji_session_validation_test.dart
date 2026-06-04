import 'package:flutter_test/flutter_test.dart';

import 'package:xiangji/src/controller/xiangji_session_controller.dart';
import 'package:xiangji/src/domain.dart';

import 'support/xiangji_session_test_doubles.dart';

void main() {
  test('controller blocks duplicate selected camera stream IDs', () async {
    final bridge = TestBridge();
    final livePublisher = RecordingLivePublisher();
    final controller = XiangjiSessionController(
      bridge: bridge,
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
    final bridge = TestBridge(
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
      livePublisher: RecordingLivePublisher(),
    );

    await controller.initialize();

    expect(controller.hasUsbDevices, isTrue);
    expect(controller.hasVideoCamera, isFalse);
    expect(controller.canStart, isFalse);
    expect(controller.statusMessage, '检测到 USB 设备，但没有视频摄像头。');

    controller.dispose();
  });

  test('controller does not start when WHIP endpoint is not configured', () async {
    final bridge = TestBridge();
    final livePublisher = RecordingLivePublisher();
    final controller = XiangjiSessionController(
      bridge: bridge,
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

  test('controller rejects WHIP endpoint without a host', () async {
    final bridge = TestBridge();
    final livePublisher = RecordingLivePublisher();
    final controller = XiangjiSessionController(
      bridge: bridge,
      livePublisher: livePublisher,
      endpointText: 'http://',
    );

    await controller.initialize();

    expect(controller.isEndpointValid, isFalse);
    expect(controller.canStart, isFalse);

    await controller.start();

    expect(livePublisher.startConfigs, isEmpty);
    expect(
      controller.latestLog?.message,
      contains('请输入有效的 HTTP 或 HTTPS WebRTC 推流地址'),
    );

    controller.dispose();
  });

  test('controller keeps stop available after a stale ready status', () async {
    final bridge = TestBridge();
    final livePublisher = RecordingLivePublisher();
    final controller = XiangjiSessionController(
      bridge: bridge,
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

    expect(livePublisher.stopRequests, 1);
    expect(controller.canStop, isFalse);

    controller.dispose();
  });
}

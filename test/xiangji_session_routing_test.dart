import 'package:flutter_test/flutter_test.dart';

import 'package:xiangji/src/controller/xiangji_session_controller.dart';
import 'package:xiangji/src/domain.dart';

import 'support/xiangji_session_test_doubles.dart';

void main() {
  test(
    'controller starts WebRTC for every selected camera stream ID',
    () async {
      final bridge = TestBridge();
      final livePublisher = RecordingLivePublisher();
      final controller = XiangjiSessionController(
        bridge: bridge,
        livePublisher: livePublisher,
        endpointText: 'http://127.0.0.1:9090/offer/camera1',
        streamIdText: 'camera',
      );

      await controller.initialize();
      expect(controller.selectedVideoCameraCount, 2);
      expect(controller.streamIdForDeviceId('usb-1'), 'camera1');
      expect(controller.streamIdForDeviceId('usb-2'), 'camera2');

      await controller.start();
      await Future<void>.delayed(Duration.zero);

      expect(controller.phase, SessionPhase.streaming);
      expect(controller.isLiveStreaming, isTrue);
      expect(livePublisher.startConfigs, hasLength(2));
      expect(livePublisher.startConfigs[0].endpoint.path, '/offer/camera1');
      expect(livePublisher.startConfigs[0].streamId, 'camera1');
      expect(livePublisher.startConfigs[0].deviceId, 'usb-1');
      expect(livePublisher.startConfigs[0].cameraName, 'Unit Test Camera 1');
      expect(livePublisher.startConfigs[1].endpoint.path, '/offer/camera2');
      expect(livePublisher.startConfigs[1].streamId, 'camera2');
      expect(livePublisher.startConfigs[1].deviceId, 'usb-2');
      expect(livePublisher.startConfigs[1].cameraName, 'Unit Test Camera 2');
      controller.dispose();
    },
  );

  test('controller appends stream IDs to an offer endpoint', () async {
    final bridge = TestBridge();
    final livePublisher = RecordingLivePublisher();
    final controller = XiangjiSessionController(
      bridge: bridge,
      livePublisher: livePublisher,
      endpointText: 'http://127.0.0.1:9090/offer',
      streamIdText: 'camera',
    );

    await controller.initialize();
    await controller.start();
    await Future<void>.delayed(Duration.zero);

    expect(livePublisher.startConfigs, hasLength(2));
    expect(
      livePublisher.startConfigs.map((config) => config.endpoint.path),
      containsAll(<String>['/offer/camera1', '/offer/camera2']),
    );
    expect(
      livePublisher.startConfigs.map((config) => config.streamId),
      containsAll(<String>['camera1', 'camera2']),
    );

    controller.dispose();
  });

  test('controller allows a custom stream ID per detected camera', () async {
    final bridge = TestBridge();
    final livePublisher = RecordingLivePublisher();
    final controller = XiangjiSessionController(
      bridge: bridge,
      livePublisher: livePublisher,
      endpointText: 'http://127.0.0.1:9090/offer/camera1',
      streamIdText: 'camera',
    );

    await controller.initialize();
    controller
      ..setDeviceSelected('usb-1', false)
      ..updateDeviceStreamIdText('usb-2', 'camera4');

    expect(controller.streamIdForDeviceId('usb-1'), 'camera1');
    expect(controller.streamIdForDeviceId('usb-2'), 'camera4');
    expect(controller.isDeviceStreamIdCustom('usb-2'), isTrue);
    expect(controller.canStart, isTrue);

    await controller.start();
    await Future<void>.delayed(Duration.zero);

    expect(livePublisher.startConfigs, hasLength(1));
    expect(livePublisher.startConfigs.single.streamId, 'camera4');
    expect(livePublisher.startConfigs.single.endpoint.path, '/offer/camera4');
    expect(livePublisher.startConfigs.single.cameraName, 'Unit Test Camera 2');

    controller.dispose();
  });
}

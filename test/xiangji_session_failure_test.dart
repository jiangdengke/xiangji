import 'package:flutter_test/flutter_test.dart';

import 'package:xiangji/src/controller/xiangji_session_controller.dart';
import 'package:xiangji/src/domain.dart';

import 'support/xiangji_session_test_doubles.dart';

void main() {
  test(
    'controller keeps app state after live publisher start failure',
    () async {
      final bridge = TestBridge();
      final livePublisher = FailingLivePublisher();
      final controller = XiangjiSessionController(
        bridge: bridge,
        livePublisher: livePublisher,
        endpointText: 'http://127.0.0.1:9090/offer/camera1',
      );

      await controller.initialize();
      await controller.start();

      expect(livePublisher.startRequests, 1);
      expect(controller.phase, SessionPhase.error);
      expect(controller.isLiveStreaming, isFalse);
      expect(controller.lastError, contains('测试推流失败'));
      expect(controller.latestLog?.message, contains('启动失败'));

      controller.dispose();
    },
  );

  test('controller stops started streams when a later stream fails', () async {
    final bridge = TestBridge();
    final livePublisher = FailingAfterFirstLivePublisher();
    final controller = XiangjiSessionController(
      bridge: bridge,
      livePublisher: livePublisher,
      endpointText: 'http://127.0.0.1:9090/offer/camera1',
    );

    await controller.initialize();
    await controller.start();
    await Future<void>.delayed(Duration.zero);

    expect(livePublisher.startConfigs, hasLength(2));
    expect(livePublisher.startConfigs[0].streamId, 'camera1');
    expect(livePublisher.startConfigs[1].streamId, 'camera2');
    expect(livePublisher.stopRequests, 1);
    expect(controller.phase, SessionPhase.error);
    expect(controller.isLiveStreaming, isFalse);
    expect(controller.lastError, contains('第二路推流失败'));

    controller.dispose();
  });

  test(
    'controller logs receiver connection failure without crashing',
    () async {
      final bridge = TestBridge();
      final livePublisher = ConnectionFailingLivePublisher();
      final controller = XiangjiSessionController(
        bridge: bridge,
        livePublisher: livePublisher,
        endpointText: 'http://127.0.0.1:9090/offer/camera1',
      );

      await controller.initialize();
      await controller.start();

      expect(livePublisher.startRequests, 1);
      expect(controller.phase, SessionPhase.error);
      expect(controller.isLiveStreaming, isFalse);
      expect(controller.lastError, contains('无法连接 WebRTC 接收端'));
      expect(
        controller.logs.map((entry) => entry.message),
        contains(contains('启动失败')),
      );

      controller.dispose();
    },
  );
}

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:xiangji/src/domain.dart';
import 'package:xiangji/src/live/live_stream_publisher.dart';
import 'package:xiangji/src/live/live_stream_routing.dart';
import 'package:xiangji/src/live/live_stream_session_coordinator.dart';

void main() {
  test('prepares selected camera streams and starts each publisher config', () async {
    final routing = LiveStreamRouting(
      endpointText: 'http://127.0.0.1:8080/whip/camera-001',
      streamIdPrefix: 'camera-001',
    )..syncDevices(_cameras);
    final publisher = _RecordingLivePublisher();
    final coordinator = LiveStreamSessionCoordinator(
      publisher: publisher,
      routing: routing,
    );

    final preparation = coordinator.prepare(_cameras);
    final started = <LiveStreamStartedStream>[];
    final result = await coordinator.start(
      preparation,
      onStreamStarted: started.add,
    );

    expect(preparation.isReady, isTrue);
    expect(result.streamIds, <String>['camera-001-01', 'camera-001-02']);
    expect(started, hasLength(2));
    expect(
      publisher.startConfigs.map((LiveStreamConfig config) => config.endpoint.path),
      <String>['/whip/camera-001-01', '/whip/camera-001-02'],
    );
  });

  test('rejects duplicate stream IDs before starting publisher', () {
    final routing = LiveStreamRouting(
      endpointText: 'http://127.0.0.1:8080/whip/camera-001',
      streamIdPrefix: 'camera-001',
    )..syncDevices(_cameras);
    routing.setCustomStreamId('camera-2', 'camera-001-01');
    final publisher = _RecordingLivePublisher();
    final coordinator = LiveStreamSessionCoordinator(
      publisher: publisher,
      routing: routing,
    );

    final preparation = coordinator.prepare(_cameras);

    expect(preparation.isRejected, isTrue);
    expect(preparation.message, contains('流 ID 不能重复'));
    expect(publisher.startConfigs, isEmpty);
  });

  test('stops already started streams when a later stream fails', () async {
    final routing = LiveStreamRouting(
      endpointText: 'http://127.0.0.1:8080/whip/camera-001',
      streamIdPrefix: 'camera-001',
    )..syncDevices(_cameras);
    final publisher = _FailingAfterFirstLivePublisher();
    final coordinator = LiveStreamSessionCoordinator(
      publisher: publisher,
      routing: routing,
    );

    await expectLater(
      coordinator.start(coordinator.prepare(_cameras)),
      throwsA(isA<StateError>()),
    );

    expect(publisher.startConfigs, hasLength(2));
    expect(publisher.stopRequests, 1);
  });
}

final _cameras = <UsbCameraDevice>[
  _camera('camera-1', 'Camera 1'),
  _camera('camera-2', 'Camera 2'),
];

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

class _RecordingLivePublisher implements LiveStreamPublisher {
  final StreamController<LivePublisherStatus> _statuses =
      StreamController<LivePublisherStatus>.broadcast();
  final List<LiveStreamConfig> startConfigs = <LiveStreamConfig>[];

  @override
  Stream<LivePublisherStatus> get statuses => _statuses.stream;

  @override
  Future<void> start(LiveStreamConfig config) async {
    startConfigs.add(config);
  }

  @override
  Future<void> stop() async {}

  @override
  Future<void> dispose() async {
    await _statuses.close();
  }
}

class _FailingAfterFirstLivePublisher extends _RecordingLivePublisher {
  int stopRequests = 0;

  @override
  Future<void> start(LiveStreamConfig config) async {
    await super.start(config);
    if (startConfigs.length > 1) {
      throw StateError('second stream failed');
    }
  }

  @override
  Future<void> stop() async {
    stopRequests += 1;
  }
}

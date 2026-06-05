import 'dart:async';

import 'package:xiangji/src/live/live_stream_publisher.dart';
import 'package:xiangji/src/live/whip_web_rtc_publisher.dart';

class RecordingLivePublisher implements LiveStreamPublisher {
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

class FailingLivePublisher implements LiveStreamPublisher {
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

class FailingAfterFirstLivePublisher implements LiveStreamPublisher {
  final StreamController<LivePublisherStatus> _statuses =
      StreamController<LivePublisherStatus>.broadcast();
  final List<LiveStreamConfig> startConfigs = <LiveStreamConfig>[];
  int stopRequests = 0;

  @override
  Stream<LivePublisherStatus> get statuses => _statuses.stream;

  @override
  Future<void> start(LiveStreamConfig config) async {
    startConfigs.add(config);
    if (startConfigs.length > 1) {
      throw StateError('第二路推流失败');
    }
    _statuses.add(
      const LivePublisherStatus(
        phase: LivePublisherPhase.streaming,
        message: '第一路推流中',
      ),
    );
  }

  @override
  Future<void> stop() async {
    stopRequests += 1;
    _statuses.add(
      const LivePublisherStatus(
        phase: LivePublisherPhase.stopped,
        message: '已停止已启动的推流',
      ),
    );
  }

  @override
  Future<void> dispose() async {
    await _statuses.close();
  }
}

class ConnectionFailingLivePublisher implements LiveStreamPublisher {
  final StreamController<LivePublisherStatus> _statuses =
      StreamController<LivePublisherStatus>.broadcast();
  int startRequests = 0;

  @override
  Stream<LivePublisherStatus> get statuses => _statuses.stream;

  @override
  Future<void> start(LiveStreamConfig config) async {
    startRequests += 1;
    const error = WhipSignalingException('无法连接 WebRTC 接收端，请检查 IP、端口和服务是否已启动。');
    _statuses.add(
      const LivePublisherStatus(
        phase: LivePublisherPhase.error,
        message: 'WebRTC 实时推流启动失败。',
        details: error,
      ),
    );
    throw error;
  }

  @override
  Future<void> stop() async {}

  @override
  Future<void> dispose() async {
    await _statuses.close();
  }
}

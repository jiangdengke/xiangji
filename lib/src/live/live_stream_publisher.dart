import 'dart:async';

enum LivePublisherPhase { idle, connecting, streaming, stopping, stopped, error }

class LiveStreamConfig {
  const LiveStreamConfig({
    required this.endpoint,
    required this.streamId,
    this.cameraName = '',
    this.audioEnabled = false,
    this.width = 1280,
    this.height = 720,
    this.frameRate = 25,
    this.bearerToken,
  });

  final Uri endpoint;
  final String streamId;
  final String cameraName;
  final bool audioEnabled;
  final int width;
  final int height;
  final int frameRate;
  final String? bearerToken;
}

class LivePublisherStatus {
  const LivePublisherStatus({
    required this.phase,
    required this.message,
    this.details,
  });

  final LivePublisherPhase phase;
  final String message;
  final Object? details;
}

abstract class LiveStreamPublisher {
  Stream<LivePublisherStatus> get statuses;

  Future<void> start(LiveStreamConfig config);

  Future<void> stop();

  Future<void> dispose();
}

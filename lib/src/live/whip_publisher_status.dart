import 'live_stream_publisher.dart';

typedef WhipPublisherStatusSink =
    void Function(LivePublisherPhase phase, String message, [Object? details]);

String whipStreamLabel(LiveStreamConfig config) {
  if (config.cameraName.trim().isNotEmpty) {
    return '${config.cameraName}（${config.streamId}）';
  }
  return config.streamId;
}

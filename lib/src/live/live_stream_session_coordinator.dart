import '../domain.dart';
import 'live_stream_publisher.dart';
import 'live_stream_routing.dart';
import 'live_stream_start_models.dart';
import 'live_stream_start_preparer.dart';

export 'live_stream_start_models.dart';
export 'live_stream_start_preparer.dart';

class LiveStreamSessionCoordinator {
  LiveStreamSessionCoordinator({
    required LiveStreamPublisher publisher,
    required LiveStreamRouting routing,
    LiveStreamStartPreparer? preparer,
  }) : _publisher = publisher,
       _routing = routing,
       _preparer = preparer ?? LiveStreamStartPreparer(routing: routing);

  final LiveStreamPublisher _publisher;
  final LiveStreamRouting _routing;
  final LiveStreamStartPreparer _preparer;

  LiveStreamStartPreparation prepare(
    Iterable<UsbCameraDevice> selectedCameras,
  ) => _preparer.prepare(selectedCameras);

  Future<LiveStreamStartResult> start(
    LiveStreamStartPreparation preparation, {
    void Function(LiveStreamStartedStream stream)? onStreamStarted,
  }) async {
    if (!preparation.isReady || preparation.baseEndpoint == null) {
      throw StateError('Live stream preparation is not ready.');
    }

    final startedStreams = <LiveStreamStartedStream>[];
    try {
      for (final camera in preparation.selectedCameras) {
        final streamId = _routing.streamIdForDeviceId(camera.deviceId);
        final endpoint = _routing.endpointForStreamId(
          preparation.baseEndpoint!,
          streamId,
        );
        await _publisher.start(
          LiveStreamConfig(
            endpoint: endpoint,
            streamId: streamId,
            deviceId: camera.deviceId,
            cameraName: camera.deviceName,
          ),
        );
        final stream = LiveStreamStartedStream(
          camera: camera,
          streamId: streamId,
          endpoint: endpoint,
        );
        startedStreams.add(stream);
        onStreamStarted?.call(stream);
      }
    } catch (_) {
      if (startedStreams.isNotEmpty) {
        await _publisher.stop();
      }
      rethrow;
    }

    return LiveStreamStartResult(streams: startedStreams);
  }
}

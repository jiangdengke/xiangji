import 'live_stream_publisher.dart';
import 'whip_publisher_status.dart';

String whipPublisherConnectingMessage(LiveStreamConfig config) {
  if (config.cameraName.isEmpty) {
    return '正在启动 WebRTC 实时推流。';
  }
  return '正在从 ${config.cameraName} 启动 WebRTC 实时推流。';
}

String whipPublisherStreamingMessage({
  required LiveStreamConfig config,
  required Uri? resourceUri,
}) {
  final label = whipStreamLabel(config);
  if (resourceUri == null) {
    return '$label WebRTC 实时推流已建立。';
  }
  return '$label WebRTC 实时推流已建立。';
}

String whipPublisherStartFailedMessage(LiveStreamConfig config) {
  return '${whipStreamLabel(config)} WebRTC 实时推流启动失败。';
}

String whipPublisherStoppingMessage(int sessionCount) {
  if (sessionCount == 1) {
    return '正在停止 WebRTC 实时推流。';
  }
  return '正在停止 $sessionCount 路 WebRTC 实时推流。';
}

String whipPublisherStoppedMessage() {
  return 'WebRTC 实时推流已停止。';
}

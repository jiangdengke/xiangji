import '../live/live_stream_start_models.dart';

String sessionLiveStoppedLogMessage() {
  return 'WebRTC 实时推流已停止。';
}

String sessionLiveStopFailedLogMessage(Object error) {
  return '停止失败：$error';
}

String sessionLiveOfferSentLogMessage(LiveStreamStartedStream stream) {
  return '已向 WHIP 服务端推送 ${stream.camera.deviceName} 的 WebRTC offer，流 ID：${stream.streamId}。';
}

String sessionLiveStartedLogMessage(LiveStreamStartResult result) {
  final startedStreamIds = result.streamIds;
  if (startedStreamIds.length == 1) {
    return '已启动 1 路 WebRTC 实时推流，流 ID：${startedStreamIds.single}。';
  }
  return '已启动 ${startedStreamIds.length} 路 WebRTC 实时推流：${startedStreamIds.join(', ')}。';
}

String sessionLiveStartFailedLogMessage(Object error) {
  return '启动失败：$error';
}

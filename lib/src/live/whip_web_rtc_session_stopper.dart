import 'live_stream_publisher.dart';
import 'whip_publisher_status.dart';
import 'whip_signaling_client.dart';
import 'whip_web_rtc_session.dart';

class WhipWebRtcSessionStopper {
  const WhipWebRtcSessionStopper({
    required WhipSignalingClient signalingClient,
    required WhipPublisherStatusSink statusSink,
  }) : _signalingClient = signalingClient,
       _statusSink = statusSink;

  final WhipSignalingClient _signalingClient;
  final WhipPublisherStatusSink _statusSink;

  Future<void> stop(
    WhipWebRtcSession session, {
    required bool emitStopped,
  }) async {
    session.closing = true;
    if (emitStopped) {
      _statusSink(
        LivePublisherPhase.stopping,
        '正在停止 ${whipStreamLabel(session.config)} WebRTC 实时推流。',
      );
    }

    try {
      final resourceUri = session.resourceUri;
      if (resourceUri != null) {
        await _signalingClient.deleteResource(
          resourceUri,
          session.config.bearerToken,
        );
      }
    } catch (error) {
      _statusSink(
        LivePublisherPhase.stopping,
        '释放 ${whipStreamLabel(session.config)} WHIP 会话失败，继续关闭本地推流。',
        error,
      );
    } finally {
      await session.disposeLocalResources();
      if (emitStopped) {
        _statusSink(
          LivePublisherPhase.stopped,
          '${whipStreamLabel(session.config)} WebRTC 实时推流已停止。',
        );
      }
    }
  }
}

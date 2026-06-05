import 'live_stream_publisher.dart';
import 'whip_publisher_status.dart';
import 'whip_web_rtc_session.dart';

class WhipWebRtcSessionStopper {
  const WhipWebRtcSessionStopper({required WhipPublisherStatusSink statusSink})
    : _statusSink = statusSink;

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

    await session.disposeLocalResources();
    if (emitStopped) {
      _statusSink(
        LivePublisherPhase.stopped,
        '${whipStreamLabel(session.config)} WebRTC 实时推流已停止。',
      );
    }
  }
}

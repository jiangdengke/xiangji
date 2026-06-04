import 'package:flutter_webrtc/flutter_webrtc.dart';

import 'live_stream_publisher.dart';
import 'whip_publisher_status.dart';
import 'whip_web_rtc_session.dart';

class WhipPeerConnectionMonitor {
  const WhipPeerConnectionMonitor({required this.statusSink});

  final WhipPublisherStatusSink statusSink;

  void bind(WhipWebRtcSession session) {
    final peerConnection = session.peerConnection;
    peerConnection.onConnectionState = (RTCPeerConnectionState state) {
      if (session.closing) {
        return;
      }
      switch (state) {
        case RTCPeerConnectionState.RTCPeerConnectionStateConnected:
          statusSink(
            LivePublisherPhase.streaming,
            '${whipStreamLabel(session.config)} WebRTC 连接已连通。',
          );
          break;
        case RTCPeerConnectionState.RTCPeerConnectionStateFailed:
          statusSink(
            LivePublisherPhase.error,
            '${whipStreamLabel(session.config)} WebRTC 连接失败。',
          );
          break;
        case RTCPeerConnectionState.RTCPeerConnectionStateDisconnected:
          statusSink(
            LivePublisherPhase.error,
            '${whipStreamLabel(session.config)} WebRTC 连接已断开。',
          );
          break;
        case RTCPeerConnectionState.RTCPeerConnectionStateClosed:
        case RTCPeerConnectionState.RTCPeerConnectionStateNew:
        case RTCPeerConnectionState.RTCPeerConnectionStateConnecting:
          break;
      }
    };
  }
}

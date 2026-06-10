import 'package:flutter_webrtc/flutter_webrtc.dart';

import 'live_stream_publisher.dart';
import 'whip_ice_gathering.dart';
import 'whip_peer_connection_monitor.dart';
import 'whip_publisher_status.dart';
import 'whip_signaling_client.dart';
import 'whip_web_rtc_session.dart';

typedef WhipMediaStreamFactory =
    Future<MediaStream> Function(Map<String, dynamic> constraints);
typedef WhipPeerConnectionFactory =
    Future<RTCPeerConnection> Function(Map<String, dynamic> configuration);

class WhipWebRtcSessionStarter {
  WhipWebRtcSessionStarter({
    required WhipSignalingClient signalingClient,
    required WhipIceGatheringWaiter iceGatheringWaiter,
    required WhipPeerConnectionMonitor peerConnectionMonitor,
    required WhipPublisherStatusSink statusSink,
    WhipMediaStreamFactory? mediaStreamFactory,
    WhipPeerConnectionFactory? peerConnectionFactory,
  }) : _signalingClient = signalingClient,
       _iceGatheringWaiter = iceGatheringWaiter,
       _peerConnectionMonitor = peerConnectionMonitor,
       _statusSink = statusSink,
       _mediaStreamFactory =
           mediaStreamFactory ??
           ((Map<String, dynamic> constraints) {
             return navigator.mediaDevices.getUserMedia(constraints);
           }),
       _peerConnectionFactory = peerConnectionFactory ?? createPeerConnection;

  final WhipSignalingClient _signalingClient;
  final WhipIceGatheringWaiter _iceGatheringWaiter;
  final WhipPeerConnectionMonitor _peerConnectionMonitor;
  final WhipPublisherStatusSink _statusSink;
  final WhipMediaStreamFactory _mediaStreamFactory;
  final WhipPeerConnectionFactory _peerConnectionFactory;

  Future<WhipWebRtcSession> start(
    LiveStreamConfig config, {
    void Function(WhipWebRtcSession session)? onSessionCreated,
  }) async {
    MediaStream? stream;
    RTCPeerConnection? peerConnection;
    WhipWebRtcSession? session;

    try {
      await _signalingClient.preflight(config.endpoint);
      stream = await _mediaStreamFactory(buildWhipMediaConstraints(config));

      peerConnection = await _peerConnectionFactory(
        buildWhipPeerConfiguration(),
      );
      session = WhipWebRtcSession(
        config: config,
        peerConnection: peerConnection,
        localStream: stream,
      );
      onSessionCreated?.call(session);
      _peerConnectionMonitor.bind(session);

      for (final track in stream.getTracks()) {
        await peerConnection.addTrack(track, stream);
      }

      final offer = await peerConnection.createOffer(
        buildWhipOfferConstraints(),
      );
      await peerConnection.setLocalDescription(offer);
      await _iceGatheringWaiter.wait(peerConnection);

      final localDescription =
          await peerConnection.getLocalDescription() ?? offer;
      final offerSdp = localDescription.sdp ?? '';
      final offerResult = await _signalingClient.publishOffer(
        config: config,
        sdp: offerSdp,
      );
      session.resourceUri = offerResult.resourceUri;
      try {
        await peerConnection.setRemoteDescription(
          RTCSessionDescription(offerResult.answerSdp, offerResult.answerType),
        );
      } catch (error, stackTrace) {
        Error.throwWithStackTrace(
          WhipSignalingException(
            'WebRTC 接收端返回的 SDP answer 无法设置为远端描述。',
            offerResult.diagnostics.describe(
              config: config,
              cause: error,
              offerSdp: offerSdp,
            ),
          ),
          stackTrace,
        );
      }
      return session;
    } catch (error, stackTrace) {
      try {
        if (session != null) {
          await session.disposeLocalResources();
        } else {
          await disposeWhipLocalResources(
            stream: stream,
            peerConnection: peerConnection,
          );
        }
      } catch (cleanupError) {
        _statusSink(LivePublisherPhase.error, 'WebRTC 推流清理失败。', cleanupError);
      }
      Error.throwWithStackTrace(error, stackTrace);
    }
  }
}

import 'dart:async';

import 'package:flutter_webrtc/flutter_webrtc.dart';

import 'live_stream_publisher.dart';
import 'whip_publisher_status.dart';

class WhipIceGatheringWaiter {
  const WhipIceGatheringWaiter({
    required this.timeout,
    required this.statusSink,
  });

  final Duration timeout;
  final WhipPublisherStatusSink statusSink;

  Future<void> wait(RTCPeerConnection peerConnection) async {
    final current = await peerConnection.getIceGatheringState();
    if (current == RTCIceGatheringState.RTCIceGatheringStateComplete) {
      return;
    }

    final completer = Completer<void>();
    final previous = peerConnection.onIceGatheringState;
    peerConnection.onIceGatheringState = (RTCIceGatheringState state) {
      previous?.call(state);
      if (state == RTCIceGatheringState.RTCIceGatheringStateComplete &&
          !completer.isCompleted) {
        completer.complete();
      }
    };

    try {
      await completer.future.timeout(timeout);
    } on TimeoutException catch (error) {
      statusSink(
        LivePublisherPhase.connecting,
        'ICE 候选收集超时，继续尝试 WebRTC 推流。',
        error,
      );
    } finally {
      peerConnection.onIceGatheringState = previous;
    }
  }
}

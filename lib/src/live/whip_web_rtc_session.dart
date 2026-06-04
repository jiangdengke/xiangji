import 'package:flutter_webrtc/flutter_webrtc.dart';

import 'live_stream_publisher.dart';

class WhipWebRtcSession {
  WhipWebRtcSession({
    required this.config,
    required this.peerConnection,
    required this.localStream,
  });

  final LiveStreamConfig config;
  final RTCPeerConnection peerConnection;
  final MediaStream localStream;
  Uri? resourceUri;
  bool closing = false;

  Future<void> disposeLocalResources() async {
    resourceUri = null;
    await disposeWhipLocalResources(
      stream: localStream,
      peerConnection: peerConnection,
    );
  }
}

Map<String, dynamic> buildWhipMediaConstraints(LiveStreamConfig config) {
  final videoConstraints = <String, dynamic>{
    'facingMode': 'environment',
    'width': <String, dynamic>{'ideal': config.width},
    'height': <String, dynamic>{'ideal': config.height},
    'frameRate': <String, dynamic>{'ideal': config.frameRate},
  };
  final deviceId = _webrtcDeviceId(config.deviceId);
  if (deviceId.isNotEmpty) {
    videoConstraints['deviceId'] = <String, dynamic>{'exact': deviceId};
  }
  return <String, dynamic>{
    'audio': config.audioEnabled,
    'video': videoConstraints,
  };
}

Map<String, dynamic> buildWhipPeerConfiguration() {
  return <String, dynamic>{
    'sdpSemantics': 'unified-plan',
    'iceServers': <Map<String, dynamic>>[
      <String, dynamic>{
        'urls': <String>['stun:stun.l.google.com:19302'],
      },
    ],
  };
}

Map<String, dynamic> buildWhipOfferConstraints() {
  return <String, dynamic>{
    'mandatory': <String, dynamic>{
      'OfferToReceiveAudio': false,
      'OfferToReceiveVideo': false,
    },
    'optional': <dynamic>[],
  };
}

Future<void> disposeWhipLocalResources({
  required MediaStream? stream,
  required RTCPeerConnection? peerConnection,
}) async {
  if (stream != null) {
    for (final track in stream.getTracks()) {
      await track.stop();
    }
    await stream.dispose();
  }
  if (peerConnection != null) {
    await peerConnection.close();
    await peerConnection.dispose();
  }
}

String _webrtcDeviceId(String deviceId) {
  const camera2Prefix = 'camera2:';
  if (deviceId.startsWith(camera2Prefix)) {
    return deviceId.substring(camera2Prefix.length);
  }
  return deviceId;
}

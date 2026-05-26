import 'dart:async';

import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:http/http.dart' as http;

import 'live_stream_publisher.dart';

class WhipWebRtcPublisher implements LiveStreamPublisher {
  WhipWebRtcPublisher({
    http.Client? client,
    this.signalingTimeout = const Duration(seconds: 15),
    this.iceGatheringTimeout = const Duration(seconds: 5),
  }) : _client = client ?? http.Client();

  final http.Client _client;
  final Duration signalingTimeout;
  final Duration iceGatheringTimeout;
  final StreamController<LivePublisherStatus> _statuses =
      StreamController<LivePublisherStatus>.broadcast();

  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  Uri? _resourceUri;
  String? _bearerToken;
  bool _closing = false;
  bool _disposed = false;

  @override
  Stream<LivePublisherStatus> get statuses => _statuses.stream;

  @override
  Future<void> start(LiveStreamConfig config) async {
    if (_disposed) {
      throw StateError('WebRTC publisher has been disposed.');
    }
    if (_peerConnection != null || _localStream != null) {
      await stop();
    }

    _closing = false;
    _bearerToken = config.bearerToken;
    _emit(
      LivePublisherPhase.connecting,
      config.cameraName.isEmpty
          ? '正在启动 WebRTC 实时推流。'
          : '正在从 ${config.cameraName} 启动 WebRTC 实时推流。',
    );

    try {
      final stream = await navigator.mediaDevices.getUserMedia(
        _mediaConstraints(config),
      );
      _localStream = stream;

      final peerConnection = await createPeerConnection(_peerConfiguration());
      _peerConnection = peerConnection;
      _bindPeerConnectionEvents(peerConnection);

      for (final track in stream.getTracks()) {
        await peerConnection.addTrack(track, stream);
      }

      final offer = await peerConnection.createOffer(_offerConstraints());
      await peerConnection.setLocalDescription(offer);
      await _waitForIceGatheringComplete(peerConnection);

      final localDescription =
          await peerConnection.getLocalDescription() ?? offer;
      final response = await _postOffer(
        config: config,
        sdp: localDescription.sdp ?? '',
      );
      final answerSdp = response.body.trim();
      if (answerSdp.isEmpty) {
        throw const WhipSignalingException('WHIP 服务端没有返回 SDP answer。');
      }

      _resourceUri = _resolveLocation(
        config.endpoint,
        response.headers['location'],
      );
      await peerConnection.setRemoteDescription(
        RTCSessionDescription(answerSdp, 'answer'),
      );
      _emit(
        LivePublisherPhase.streaming,
        _resourceUri == null
            ? 'WebRTC 实时推流已建立。'
            : 'WebRTC 实时推流已建立，停止时会释放 WHIP 会话。',
      );
    } catch (error, stackTrace) {
      await _cleanup();
      _emit(LivePublisherPhase.error, 'WebRTC 实时推流启动失败。', error);
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  @override
  Future<void> stop() async {
    if (_peerConnection == null && _localStream == null && _resourceUri == null) {
      return;
    }

    _closing = true;
    _emit(LivePublisherPhase.stopping, '正在停止 WebRTC 实时推流。');
    final resourceUri = _resourceUri;
    try {
      if (resourceUri != null) {
        await _client
            .delete(resourceUri, headers: _signalingHeaders())
            .timeout(signalingTimeout);
      }
    } catch (error) {
      _emit(LivePublisherPhase.stopping, '释放 WHIP 会话失败，继续关闭本地推流。', error);
    } finally {
      await _cleanup();
      _emit(LivePublisherPhase.stopped, 'WebRTC 实时推流已停止。');
      _closing = false;
    }
  }

  Map<String, dynamic> _mediaConstraints(LiveStreamConfig config) {
    return <String, dynamic>{
      'audio': config.audioEnabled,
      'video': <String, dynamic>{
        'facingMode': 'environment',
        'width': <String, dynamic>{'ideal': config.width},
        'height': <String, dynamic>{'ideal': config.height},
        'frameRate': <String, dynamic>{'ideal': config.frameRate},
      },
    };
  }

  Map<String, dynamic> _peerConfiguration() {
    return <String, dynamic>{
      'sdpSemantics': 'unified-plan',
      'iceServers': <Map<String, dynamic>>[
        <String, dynamic>{
          'urls': <String>['stun:stun.l.google.com:19302'],
        },
      ],
    };
  }

  Map<String, dynamic> _offerConstraints() {
    return <String, dynamic>{
      'mandatory': <String, dynamic>{
        'OfferToReceiveAudio': false,
        'OfferToReceiveVideo': false,
      },
      'optional': <dynamic>[],
    };
  }

  void _bindPeerConnectionEvents(RTCPeerConnection peerConnection) {
    peerConnection.onConnectionState = (RTCPeerConnectionState state) {
      if (_closing) {
        return;
      }
      switch (state) {
        case RTCPeerConnectionState.RTCPeerConnectionStateConnected:
          _emit(LivePublisherPhase.streaming, 'WebRTC 连接已连通。');
          break;
        case RTCPeerConnectionState.RTCPeerConnectionStateFailed:
          _emit(LivePublisherPhase.error, 'WebRTC 连接失败。');
          break;
        case RTCPeerConnectionState.RTCPeerConnectionStateDisconnected:
          _emit(LivePublisherPhase.error, 'WebRTC 连接已断开。');
          break;
        case RTCPeerConnectionState.RTCPeerConnectionStateClosed:
        case RTCPeerConnectionState.RTCPeerConnectionStateNew:
        case RTCPeerConnectionState.RTCPeerConnectionStateConnecting:
          break;
      }
    };
  }

  Future<void> _waitForIceGatheringComplete(
    RTCPeerConnection peerConnection,
  ) async {
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
      await completer.future.timeout(iceGatheringTimeout);
    } on TimeoutException catch (error) {
      _emit(LivePublisherPhase.connecting, 'ICE 候选收集超时，继续尝试 WHIP 推流。', error);
    } finally {
      peerConnection.onIceGatheringState = previous;
    }
  }

  Future<http.Response> _postOffer({
    required LiveStreamConfig config,
    required String sdp,
  }) async {
    final response = await _client
        .post(
          config.endpoint,
          headers: <String, String>{
            ..._signalingHeaders(),
            'Accept': 'application/sdp',
            'Content-Type': 'application/sdp',
            'X-Stream-Id': config.streamId,
          },
          body: sdp,
        )
        .timeout(signalingTimeout);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw WhipSignalingException(
        'WHIP 服务端返回 HTTP ${response.statusCode}。',
        response.body,
      );
    }
    return response;
  }

  Map<String, String> _signalingHeaders() {
    final token = _bearerToken;
    if (token == null || token.trim().isEmpty) {
      return const <String, String>{};
    }
    return <String, String>{'Authorization': 'Bearer ${token.trim()}'};
  }

  Uri? _resolveLocation(Uri endpoint, String? location) {
    if (location == null || location.trim().isEmpty) {
      return null;
    }
    final parsed = Uri.tryParse(location.trim());
    if (parsed == null) {
      return null;
    }
    if (parsed.hasScheme) {
      return parsed;
    }
    return endpoint.resolveUri(parsed);
  }

  Future<void> _cleanup() async {
    final stream = _localStream;
    final peerConnection = _peerConnection;
    _localStream = null;
    _peerConnection = null;
    _resourceUri = null;

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

  void _emit(LivePublisherPhase phase, String message, [Object? details]) {
    if (_disposed || _statuses.isClosed) {
      return;
    }
    _statuses.add(
      LivePublisherStatus(phase: phase, message: message, details: details),
    );
  }

  @override
  Future<void> dispose() async {
    if (_disposed) {
      return;
    }
    _disposed = true;
    await _cleanup();
    _client.close();
    await _statuses.close();
  }
}

class WhipSignalingException implements Exception {
  const WhipSignalingException(this.message, [this.details]);

  final String message;
  final Object? details;

  @override
  String toString() {
    if (details == null || details.toString().isEmpty) {
      return message;
    }
    return '$message $details';
  }
}

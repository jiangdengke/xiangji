import 'dart:async';

import 'package:http/http.dart' as http;

import 'whip_ice_gathering.dart';
import 'whip_peer_connection_monitor.dart';
import 'whip_publisher_status_controller.dart';
import 'live_stream_publisher.dart';
import 'whip_signaling_client.dart';
import 'whip_web_rtc_session.dart';
import 'whip_web_rtc_session_registry.dart';
import 'whip_web_rtc_session_starter.dart';
import 'whip_web_rtc_session_stopper.dart';
import 'whip_web_rtc_publisher_messages.dart';

export 'whip_signaling_client.dart' show WhipSignalingException;

class WhipWebRtcPublisher implements LiveStreamPublisher {
  WhipWebRtcPublisher({
    http.Client? client,
    this.signalingTimeout = const Duration(seconds: 15),
    this.preflightTimeout = const Duration(seconds: 3),
    this.iceGatheringTimeout = const Duration(seconds: 5),
    Future<void> Function(Uri endpoint, Duration timeout)? endpointProbe,
  }) {
    _signalingClient = WhipSignalingClient(
      client: client,
      signalingTimeout: signalingTimeout,
      preflightTimeout: preflightTimeout,
      endpointProbe: endpointProbe,
    );
    _sessionStarter = WhipWebRtcSessionStarter(
      signalingClient: _signalingClient,
      iceGatheringWaiter: WhipIceGatheringWaiter(
        timeout: iceGatheringTimeout,
        statusSink: _statusController.sink,
      ),
      peerConnectionMonitor: WhipPeerConnectionMonitor(
        statusSink: _statusController.sink,
      ),
      statusSink: _statusController.sink,
    );
    _sessionStopper = WhipWebRtcSessionStopper(
      statusSink: _statusController.sink,
    );
  }

  final Duration signalingTimeout;
  final Duration preflightTimeout;
  final Duration iceGatheringTimeout;
  late final WhipSignalingClient _signalingClient;
  late final WhipWebRtcSessionStarter _sessionStarter;
  late final WhipWebRtcSessionStopper _sessionStopper;
  final WhipPublisherStatusController _statusController =
      WhipPublisherStatusController();
  final WhipWebRtcSessionRegistry _sessions = WhipWebRtcSessionRegistry();
  bool _disposed = false;

  @override
  Stream<LivePublisherStatus> get statuses => _statusController.stream;

  @override
  Future<void> start(LiveStreamConfig config) async {
    if (_disposed) {
      throw StateError('WebRTC publisher has been disposed.');
    }
    final existingSession = _sessions.byStreamId(config.streamId);
    if (existingSession != null) {
      await _stopTrackedSession(existingSession, emitStopped: false);
    }

    _statusController.emit(
      LivePublisherPhase.connecting,
      whipPublisherConnectingMessage(config),
    );

    try {
      final session = await _sessionStarter.start(
        config,
        onSessionCreated: (WhipWebRtcSession session) {
          _sessions.track(session);
        },
      );
      _sessions.track(session);
      _statusController.emit(
        LivePublisherPhase.streaming,
        whipPublisherStreamingMessage(
          config: config,
          resourceUri: session.resourceUri,
        ),
      );
    } catch (error, stackTrace) {
      _sessions.remove(config.streamId);
      _statusController.emit(
        LivePublisherPhase.error,
        whipPublisherStartFailedMessage(config),
        error,
      );
      Error.throwWithStackTrace(_reportedPublisherError(error), stackTrace);
    }
  }

  Object _reportedPublisherError(Object error) {
    if (error is WhipSignalingException) {
      return error.asReportedByPublisher();
    }
    if (error is LivePublisherReportedError && error.reportedByPublisher) {
      return error;
    }
    return LivePublisherReportedException(error);
  }

  @override
  Future<void> stop() async {
    if (_sessions.isEmpty) {
      return;
    }

    final sessions = _sessions.sessions;
    _statusController.emit(
      LivePublisherPhase.stopping,
      whipPublisherStoppingMessage(sessions.length),
    );
    for (final session in sessions) {
      await _stopTrackedSession(session, emitStopped: false);
    }
    _statusController.emit(
      LivePublisherPhase.stopped,
      whipPublisherStoppedMessage(),
    );
  }

  Future<void> _stopTrackedSession(
    WhipWebRtcSession session, {
    required bool emitStopped,
  }) async {
    if (_sessions.remove(session.config.streamId) == null) {
      return;
    }

    await _sessionStopper.stop(session, emitStopped: emitStopped);
  }

  @override
  Future<void> dispose() async {
    if (_disposed) {
      return;
    }
    _disposed = true;
    final sessions = _sessions.drain();
    for (final session in sessions) {
      await session.disposeLocalResources();
    }
    _signalingClient.close();
    await _statusController.close();
  }
}

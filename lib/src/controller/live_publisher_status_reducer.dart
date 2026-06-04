import '../domain.dart';
import '../live/live_stream_publisher.dart';
import 'session_phase_presenter.dart';

class LivePublisherSessionState {
  const LivePublisherSessionState({
    this.liveActive,
    this.sessionActive,
    this.phase,
    this.lastError,
  });

  final bool? liveActive;
  final bool? sessionActive;
  final SessionPhase? phase;
  final String? lastError;
}

LivePublisherSessionState reduceLivePublisherStatus(
  LivePublisherStatus status, {
  required bool hasUsbDevices,
}) {
  switch (status.phase) {
    case LivePublisherPhase.idle:
      return LivePublisherSessionState(
        liveActive: false,
        sessionActive: false,
        phase: readyOrIdlePhase(hasUsbDevices: hasUsbDevices),
      );
    case LivePublisherPhase.connecting:
      return const LivePublisherSessionState(phase: SessionPhase.starting);
    case LivePublisherPhase.streaming:
      return const LivePublisherSessionState(
        liveActive: true,
        sessionActive: true,
        phase: SessionPhase.streaming,
        lastError: '',
      );
    case LivePublisherPhase.stopping:
      return const LivePublisherSessionState(phase: SessionPhase.stopping);
    case LivePublisherPhase.stopped:
      return LivePublisherSessionState(
        liveActive: false,
        sessionActive: false,
        phase: readyOrIdlePhase(hasUsbDevices: hasUsbDevices),
      );
    case LivePublisherPhase.error:
      return LivePublisherSessionState(
        liveActive: false,
        sessionActive: false,
        phase: SessionPhase.error,
        lastError: status.details?.toString() ?? status.message,
      );
  }
}

LogLevel logLevelForLivePublisherStatus(LivePublisherStatus status) {
  return status.phase == LivePublisherPhase.error
      ? LogLevel.error
      : LogLevel.info;
}

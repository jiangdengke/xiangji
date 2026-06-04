import '../domain.dart';
import 'session_phase_presenter.dart';

class CameraBridgeSessionState {
  const CameraBridgeSessionState({
    this.sessionActive,
    required this.phase,
    required this.statusMessage,
    this.lastError,
    required this.logMessage,
    required this.logLevel,
    required this.logTopic,
  });

  final bool? sessionActive;
  final SessionPhase phase;
  final String statusMessage;
  final String? lastError;
  final String logMessage;
  final LogLevel logLevel;
  final LogTopic logTopic;
}

bool isBridgeDeviceRefreshWhileLive({
  required bool liveActive,
  required SessionPhase phase,
}) {
  return liveActive &&
      (phase == SessionPhase.ready || phase == SessionPhase.idle);
}

CameraBridgeSessionState reduceCameraStatusEvent({
  required SessionPhase phase,
  required String message,
}) {
  return CameraBridgeSessionState(
    sessionActive: switch (phase) {
      SessionPhase.starting || SessionPhase.streaming => true,
      SessionPhase.idle => false,
      _ => null,
    },
    phase: phase,
    statusMessage: message,
    lastError: phase == SessionPhase.error ? null : '',
    logMessage: message.isEmpty
        ? '会话阶段已切换到 ${sessionPhaseLabel(phase)}。'
        : message,
    logLevel: phase == SessionPhase.error ? LogLevel.error : LogLevel.info,
    logTopic: phase == SessionPhase.error ? LogTopic.error : LogTopic.session,
  );
}

CameraBridgeSessionState reduceCameraErrorEvent({
  required String message,
  Object? details,
}) {
  return CameraBridgeSessionState(
    phase: SessionPhase.error,
    statusMessage: message,
    lastError: details?.toString() ?? message,
    logMessage: message,
    logLevel: LogLevel.error,
    logTopic: LogTopic.error,
  );
}

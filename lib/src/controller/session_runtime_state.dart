import '../domain.dart';
import '../live/live_stream_publisher.dart';
import '../live/live_stream_start_models.dart';
import 'camera_bridge_event_reducer.dart';
import 'live_publisher_status_reducer.dart';
import 'session_phase_presenter.dart';
import 'session_status_messages.dart';

class SessionRuntimeState {
  SessionRuntimeState({
    SessionStatusMessages messages = const SessionStatusMessages(),
  }) : statusMessage = messages.initial,
       _messages = messages;

  final SessionStatusMessages _messages;
  bool bridgeSupported = false;
  bool pendingStartAfterPermission = false;
  bool sessionActive = false;
  bool liveActive = false;
  bool disposed = false;
  SessionPhase phase = SessionPhase.idle;
  String statusMessage;
  String lastError = '';
  DateTime? lastLiveEventAt;

  String get phaseLabel => sessionPhaseLabel(phase);

  bool get isLiveStreaming => liveActive && phase == SessionPhase.streaming;

  void beginDiscovery() {
    phase = SessionPhase.discovering;
    statusMessage = _messages.discovering;
  }

  void completeDiscovery({
    required bool hasUsbDevices,
    required String inventoryMessage,
  }) {
    if (phase == SessionPhase.discovering) {
      phase = readyOrIdlePhase(hasUsbDevices: hasUsbDevices);
      statusMessage = inventoryMessage;
    }
    if (phase == SessionPhase.permissionRequested && hasUsbDevices) {
      phase = SessionPhase.ready;
      statusMessage = _messages.permissionReady;
    }
    lastError = '';
  }

  void failDiscovery(Object error) {
    phase = SessionPhase.error;
    lastError = error.toString();
    statusMessage = _messages.discoveryFailed;
  }

  void beginPermissionRequest(String message) {
    phase = SessionPhase.permissionRequested;
    statusMessage = message;
  }

  void beginLiveStart(LiveStreamStartPreparation preparation) {
    pendingStartAfterPermission = false;
    phase = SessionPhase.starting;
    statusMessage = _messages.liveStarting(preparation);
  }

  void completeLiveStart(LiveStreamStartResult result) {
    sessionActive = true;
    liveActive = true;
    lastLiveEventAt = DateTime.now();
    phase = SessionPhase.streaming;
    statusMessage = _messages.liveStarted(result);
  }

  void beginStop() {
    pendingStartAfterPermission = false;
    phase = SessionPhase.stopping;
    statusMessage = _messages.stoppingLive;
  }

  void completeStop({required bool hasUsbDevices}) {
    liveActive = false;
    sessionActive = false;
    phase = readyOrIdlePhase(hasUsbDevices: hasUsbDevices);
    statusMessage = _messages.stoppedLive;
  }

  void failStop(Object error) {
    phase = SessionPhase.error;
    statusMessage = _messages.stopFailed;
    lastError = error.toString();
  }

  void failStart(Object error) {
    phase = SessionPhase.error;
    liveActive = false;
    sessionActive = false;
    statusMessage = _messages.startFailed;
    lastError = error.toString();
  }

  void reportUnhandledError(Object error) {
    phase = SessionPhase.error;
    sessionActive = false;
    liveActive = false;
    statusMessage = _messages.unhandledError;
    lastError = error.toString();
  }

  bool shouldTreatLiveStatusAsStaleStopped(LivePublisherStatus status) {
    return status.phase == LivePublisherPhase.stopped &&
        phase == SessionPhase.error &&
        !sessionActive &&
        !liveActive;
  }

  void applyBridgeSessionState(CameraBridgeSessionState state) {
    sessionActive = state.sessionActive ?? sessionActive;
    phase = state.phase;
    statusMessage = state.statusMessage;
    lastError = state.lastError ?? lastError;
  }

  void applyLivePublisherStatus(
    LivePublisherStatus status, {
    required bool hasUsbDevices,
  }) {
    lastLiveEventAt = DateTime.now();
    final nextState = reduceLivePublisherStatus(
      status,
      hasUsbDevices: hasUsbDevices,
    );
    liveActive = nextState.liveActive ?? liveActive;
    sessionActive = nextState.sessionActive ?? sessionActive;
    phase = nextState.phase ?? phase;
    lastError = nextState.lastError ?? lastError;
    statusMessage = status.message;
  }
}

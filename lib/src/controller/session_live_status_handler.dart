import '../domain.dart';
import '../live/live_stream_publisher.dart';
import 'live_publisher_status_reducer.dart';
import 'session_log_sink.dart';
import 'session_runtime_state.dart';

class SessionLiveStatusHandler {
  SessionLiveStatusHandler({
    required SessionRuntimeState state,
    required bool Function() hasUsbDevices,
    required void Function() notifyListeners,
    required SessionLogSink logSink,
  }) : _state = state,
       _hasUsbDevices = hasUsbDevices,
       _notifyListeners = notifyListeners,
       _logSink = logSink;

  final SessionRuntimeState _state;
  final bool Function() _hasUsbDevices;
  final void Function() _notifyListeners;
  final SessionLogSink _logSink;

  void handle(LivePublisherStatus status) {
    if (_state.disposed) {
      return;
    }

    _state.lastLiveEventAt = DateTime.now();
    if (_state.shouldTreatLiveStatusAsStaleStopped(status)) {
      _logSink(
        status.message,
        LogLevel.info,
        status.details,
        true,
        LogTopic.session,
      );
      return;
    }

    _state.applyLivePublisherStatus(
      status,
      hasUsbDevices: _hasUsbDevices(),
    );
    _logSink(
      status.message,
      logLevelForLivePublisherStatus(status),
      status.details,
      true,
      LogTopic.session,
    );
    _notifyListeners();
  }
}

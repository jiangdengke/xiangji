import '../domain.dart';
import '../live/live_stream_publisher.dart';
import '../live/live_stream_session_coordinator.dart';
import 'session_live_orchestrator_messages.dart';
import 'session_log_sink.dart';
import 'session_runtime_state.dart';

class SessionLiveOrchestrator {
  SessionLiveOrchestrator({
    required SessionRuntimeState state,
    required LiveStreamSessionCoordinator liveSessionCoordinator,
    required LiveStreamPublisher livePublisher,
    required List<UsbCameraDevice> Function() selectedVideoDevices,
    required bool Function() hasUsbDevices,
    required Future<void> Function() requestPermission,
    required void Function() notifyListeners,
    required SessionLogSink logSink,
  }) : _state = state,
       _liveSessionCoordinator = liveSessionCoordinator,
       _livePublisher = livePublisher,
       _selectedVideoDevices = selectedVideoDevices,
       _hasUsbDevices = hasUsbDevices,
       _requestPermission = requestPermission,
       _notifyListeners = notifyListeners,
       _logSink = logSink;

  final SessionRuntimeState _state;
  final LiveStreamSessionCoordinator _liveSessionCoordinator;
  final LiveStreamPublisher _livePublisher;
  final List<UsbCameraDevice> Function() _selectedVideoDevices;
  final bool Function() _hasUsbDevices;
  final Future<void> Function() _requestPermission;
  final void Function() _notifyListeners;
  final SessionLogSink _logSink;

  Future<void> start() async {
    if (_state.disposed) {
      return;
    }

    try {
      await _startLive();
    } catch (error, stackTrace) {
      _handleStartFailure(error, stackTrace);
    }
  }

  Future<void> stop() async {
    _state.beginStop();
    _notifyListeners();

    try {
      await _livePublisher.stop();
      _state.completeStop(hasUsbDevices: _hasUsbDevices());
      _logSink(
        sessionLiveStoppedLogMessage(),
        LogLevel.info,
        null,
        true,
        LogTopic.session,
      );
      _notifyListeners();
    } catch (error, stackTrace) {
      _state.failStop(error);
      _logSink(
        sessionLiveStopFailedLogMessage(error),
        LogLevel.error,
        stackTrace,
        true,
        LogTopic.session,
      );
      _notifyListeners();
    }
  }

  Future<void> _startLive() async {
    final preparation = _liveSessionCoordinator.prepare(
      _selectedVideoDevices(),
    );
    if (preparation.isRejected) {
      _logSink(
        preparation.message,
        LogLevel.warning,
        null,
        true,
        preparation.topic,
      );
      return;
    }

    if (preparation.requiresPermission) {
      _state.pendingStartAfterPermission = true;
      _logSink(
        preparation.message,
        LogLevel.warning,
        null,
        true,
        LogTopic.permission,
      );
      await _requestPermission();
      return;
    }

    _state.beginLiveStart(preparation);
    _notifyListeners();

    final startResult = await _liveSessionCoordinator.start(
      preparation,
      onStreamStarted: (LiveStreamStartedStream stream) {
        _logSink(
          sessionLiveOfferSentLogMessage(stream),
          LogLevel.info,
          null,
          false,
          LogTopic.session,
        );
      },
    );

    _state.completeLiveStart(startResult);
    _logSink(
      sessionLiveStartedLogMessage(startResult),
      LogLevel.info,
      null,
      true,
      LogTopic.session,
    );
    _notifyListeners();
  }

  void _handleStartFailure(Object error, StackTrace stackTrace) {
    _state.failStart(error);
    if (_isReportedByPublisher(error)) {
      _notifyListeners();
      return;
    }
    _logSink(
      sessionLiveStartFailedLogMessage(error),
      LogLevel.error,
      stackTrace,
      true,
      LogTopic.session,
    );
  }

  bool _isReportedByPublisher(Object error) {
    return error is LivePublisherReportedError && error.reportedByPublisher;
  }
}

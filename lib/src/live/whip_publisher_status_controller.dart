import 'dart:async';

import 'live_stream_publisher.dart';
import 'whip_publisher_status.dart';

class WhipPublisherStatusController {
  final StreamController<LivePublisherStatus> _statuses =
      StreamController<LivePublisherStatus>.broadcast();
  bool _closed = false;

  Stream<LivePublisherStatus> get stream => _statuses.stream;

  WhipPublisherStatusSink get sink => emit;

  void emit(LivePublisherPhase phase, String message, [Object? details]) {
    if (_closed || _statuses.isClosed) {
      return;
    }
    _statuses.add(
      LivePublisherStatus(phase: phase, message: message, details: details),
    );
  }

  Future<void> close() async {
    if (_closed) {
      return;
    }
    _closed = true;
    await _statuses.close();
  }
}

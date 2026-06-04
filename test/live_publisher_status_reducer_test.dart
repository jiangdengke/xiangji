import 'package:flutter_test/flutter_test.dart';

import 'package:xiangji/src/controller/live_publisher_status_reducer.dart';
import 'package:xiangji/src/domain.dart';
import 'package:xiangji/src/live/live_stream_publisher.dart';

void main() {
  test('maps streaming status to an active session state', () {
    final state = reduceLivePublisherStatus(
      const LivePublisherStatus(
        phase: LivePublisherPhase.streaming,
        message: 'streaming',
      ),
      hasUsbDevices: true,
    );

    expect(state.liveActive, isTrue);
    expect(state.sessionActive, isTrue);
    expect(state.phase, SessionPhase.streaming);
    expect(state.lastError, isEmpty);
  });

  test('maps stopped status back to ready when USB devices exist', () {
    final state = reduceLivePublisherStatus(
      const LivePublisherStatus(
        phase: LivePublisherPhase.stopped,
        message: 'stopped',
      ),
      hasUsbDevices: true,
    );

    expect(state.liveActive, isFalse);
    expect(state.sessionActive, isFalse);
    expect(state.phase, SessionPhase.ready);
  });

  test('maps error status to error phase and error log level', () {
    final status = LivePublisherStatus(
      phase: LivePublisherPhase.error,
      message: 'failed',
      details: StateError('boom'),
    );
    final state = reduceLivePublisherStatus(status, hasUsbDevices: false);

    expect(state.liveActive, isFalse);
    expect(state.sessionActive, isFalse);
    expect(state.phase, SessionPhase.error);
    expect(state.lastError, contains('boom'));
    expect(logLevelForLivePublisherStatus(status), LogLevel.error);
  });
}

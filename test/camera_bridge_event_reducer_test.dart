import 'package:flutter_test/flutter_test.dart';

import 'package:xiangji/src/controller/camera_bridge_event_reducer.dart';
import 'package:xiangji/src/domain.dart';

void main() {
  test('maps streaming bridge status to active session state', () {
    final state = reduceCameraStatusEvent(
      phase: SessionPhase.streaming,
      message: 'streaming',
    );

    expect(state.sessionActive, isTrue);
    expect(state.phase, SessionPhase.streaming);
    expect(state.statusMessage, 'streaming');
    expect(state.lastError, isEmpty);
    expect(state.logLevel, LogLevel.info);
    expect(state.logTopic, LogTopic.session);
  });

  test('maps empty status messages to phase labels', () {
    final state = reduceCameraStatusEvent(
      phase: SessionPhase.ready,
      message: '',
    );

    expect(state.logMessage, contains('就绪'));
    expect(state.lastError, isEmpty);
  });

  test('maps bridge errors to error state', () {
    final state = reduceCameraErrorEvent(
      message: 'camera failed',
      details: 'native details',
    );

    expect(state.phase, SessionPhase.error);
    expect(state.statusMessage, 'camera failed');
    expect(state.lastError, 'native details');
    expect(state.logLevel, LogLevel.error);
    expect(state.logTopic, LogTopic.error);
  });

  test('detects stale ready or idle bridge status while live', () {
    expect(
      isBridgeDeviceRefreshWhileLive(
        liveActive: true,
        phase: SessionPhase.ready,
      ),
      isTrue,
    );
    expect(
      isBridgeDeviceRefreshWhileLive(
        liveActive: true,
        phase: SessionPhase.streaming,
      ),
      isFalse,
    );
  });
}

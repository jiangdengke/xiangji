import 'dart:async';

import '../bridge/camera_bridge.dart';
import '../live/live_stream_publisher.dart';
import 'session_event_handlers.dart';
import 'session_runtime_state.dart';

class SessionControllerLifecycle {
  SessionControllerLifecycle({
    required CameraBridge bridge,
    required LiveStreamPublisher livePublisher,
    required SessionRuntimeState state,
    required SessionEventHandlers eventHandlers,
  }) : _bridge = bridge,
       _livePublisher = livePublisher,
       _state = state {
    _bridgeSubscription = _bridge.events.listen(
      eventHandlers.handleBridgeEvent,
    );
    _liveSubscription = _livePublisher.statuses.listen(
      eventHandlers.handleLiveStatus,
    );
  }

  final CameraBridge _bridge;
  final LiveStreamPublisher _livePublisher;
  final SessionRuntimeState _state;

  late final StreamSubscription<CameraBridgeEvent> _bridgeSubscription;
  late final StreamSubscription<LivePublisherStatus> _liveSubscription;

  void dispose() {
    _state.disposed = true;
    unawaited(_bridgeSubscription.cancel());
    unawaited(_liveSubscription.cancel());
    unawaited(_livePublisher.dispose());
    unawaited(_bridge.dispose());
  }
}

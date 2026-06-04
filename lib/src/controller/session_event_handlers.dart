import '../bridge/camera_bridge.dart';
import '../live/live_stream_publisher.dart';
import 'session_bridge_event_handler.dart';
import 'session_live_status_handler.dart';

class SessionEventHandlers {
  SessionEventHandlers({
    required SessionBridgeEventHandler bridgeHandler,
    required SessionLiveStatusHandler liveStatusHandler,
  }) : _bridgeHandler = bridgeHandler,
       _liveStatusHandler = liveStatusHandler;

  final SessionBridgeEventHandler _bridgeHandler;
  final SessionLiveStatusHandler _liveStatusHandler;

  Future<void> handleBridgeEvent(CameraBridgeEvent event) async {
    await _bridgeHandler.handle(event);
  }

  void handleLiveStatus(LivePublisherStatus status) {
    _liveStatusHandler.handle(status);
  }
}

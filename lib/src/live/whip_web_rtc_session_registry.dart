import 'whip_web_rtc_session.dart';

class WhipWebRtcSessionRegistry {
  final Map<String, WhipWebRtcSession> _sessions =
      <String, WhipWebRtcSession>{};

  bool get isEmpty => _sessions.isEmpty;

  List<WhipWebRtcSession> get sessions =>
      _sessions.values.toList(growable: false);

  WhipWebRtcSession? byStreamId(String streamId) {
    return _sessions[streamId];
  }

  void track(WhipWebRtcSession session) {
    _sessions[session.config.streamId] = session;
  }

  WhipWebRtcSession? remove(String streamId) {
    return _sessions.remove(streamId);
  }

  List<WhipWebRtcSession> drain() {
    final current = sessions;
    _sessions.clear();
    return current;
  }
}

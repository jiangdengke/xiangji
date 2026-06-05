import 'package:flutter/foundation.dart';

import '../domain.dart';
import 'stream_log_buffer.dart';

class SessionControllerLogger {
  SessionControllerLogger({required VoidCallback notifyListeners})
    : _notifyListeners = notifyListeners;

  final VoidCallback _notifyListeners;
  final StreamLogBuffer buffer = StreamLogBuffer();

  void logSessionEvent(
    String message,
    LogLevel level,
    Object? details,
    bool notify,
    LogTopic topic,
  ) {
    appendLog(message, level, topic: topic, details: details, notify: notify);
  }

  void appendLog(
    String message,
    LogLevel level, {
    LogTopic topic = LogTopic.system,
    Object? details,
    StackTrace? stackTrace,
    bool notify = true,
  }) {
    buffer.append(message, level, topic: topic, details: details);
    if (notify) {
      _notifyListeners();
    }
    if (stackTrace != null) {
      debugPrint(stackTrace.toString());
    }
  }
}

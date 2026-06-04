import 'session_enums.dart';

class StreamLogEntry {
  const StreamLogEntry({
    required this.timestamp,
    required this.level,
    required this.topic,
    required this.message,
  });

  final DateTime timestamp;
  final LogLevel level;
  final LogTopic topic;
  final String message;
}

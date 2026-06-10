import 'session_enums.dart';

class StreamLogEntry {
  const StreamLogEntry({
    required this.timestamp,
    required this.level,
    required this.topic,
    required this.message,
    this.fullMessage,
  });

  final DateTime timestamp;
  final LogLevel level;
  final LogTopic topic;
  final String message;
  final String? fullMessage;

  String get fullText => fullMessage ?? message;

  bool get hasFullText => fullText != message;
}

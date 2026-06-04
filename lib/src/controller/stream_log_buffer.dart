import '../domain.dart';

class StreamLogBuffer {
  StreamLogBuffer({this.maxEntries = 200});

  final int maxEntries;
  final List<StreamLogEntry> _entries = <StreamLogEntry>[];

  List<StreamLogEntry> get entries =>
      List<StreamLogEntry>.unmodifiable(_entries);

  List<StreamLogEntry> get recentEntries =>
      List<StreamLogEntry>.unmodifiable(_entries.reversed);

  StreamLogEntry? get latest => _entries.isEmpty ? null : _entries.last;

  void append(
    String message,
    LogLevel level, {
    LogTopic topic = LogTopic.system,
    Object? details,
  }) {
    final detailText = _compactDetails(details);
    final composed = detailText == null ? message : '$message $detailText';
    _entries.add(
      StreamLogEntry(
        timestamp: DateTime.now(),
        level: level,
        topic: topic,
        message: composed,
      ),
    );
    while (_entries.length > maxEntries) {
      _entries.removeAt(0);
    }
  }

  String? _compactDetails(Object? details) {
    if (details == null) {
      return null;
    }

    final raw = details.toString();
    final firstLine = raw.split('\n').first.trim();
    if (firstLine.isEmpty) {
      return null;
    }
    if (firstLine.length <= 180) {
      return firstLine;
    }
    return '${firstLine.substring(0, 180)}...';
  }
}

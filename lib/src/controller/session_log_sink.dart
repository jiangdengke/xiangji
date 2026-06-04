import '../domain.dart';

typedef SessionLogSink =
    void Function(
      String message,
      LogLevel level,
      Object? details,
      bool notify,
      LogTopic topic,
    );

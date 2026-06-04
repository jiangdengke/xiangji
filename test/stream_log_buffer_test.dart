import 'package:flutter_test/flutter_test.dart';

import 'package:xiangji/src/controller/stream_log_buffer.dart';
import 'package:xiangji/src/domain.dart';

void main() {
  test('log buffer keeps the newest entries and compacts details', () {
    final buffer = StreamLogBuffer(maxEntries: 2);

    buffer.append('first', LogLevel.info);
    buffer.append('second', LogLevel.warning, topic: LogTopic.device);
    buffer.append(
      'third',
      LogLevel.error,
      topic: LogTopic.error,
      details: 'detail line\nstack line',
    );

    expect(buffer.entries, hasLength(2));
    expect(buffer.entries.first.message, 'second');
    expect(buffer.latest?.message, 'third detail line');
    expect(buffer.latest?.topic, LogTopic.error);
    expect(
      buffer.recentEntries.map((StreamLogEntry entry) => entry.message),
      <String>['third detail line', 'second'],
    );
  });

  test('log buffer truncates long detail lines', () {
    final buffer = StreamLogBuffer();
    final details = List<String>.filled(220, 'x').join();

    buffer.append('message', LogLevel.error, details: details);

    expect(buffer.latest?.message.length, lessThan(details.length));
    expect(buffer.latest?.message, endsWith('...'));
  });
}

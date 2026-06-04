import 'package:flutter_test/flutter_test.dart';

import 'package:xiangji/src/domain.dart';
import 'package:xiangji/src/ui/stream_dashboard_log_presenter.dart';

void main() {
  const presenter = StreamDashboardLogPresenter();

  test('formats log timestamps as clock text', () {
    final entry = StreamLogEntry(
      timestamp: DateTime(2026, 1, 2, 3, 4, 5),
      level: LogLevel.info,
      topic: LogTopic.system,
      message: 'ready',
    );

    expect(presenter.timeText(entry), '03:04:05');
  });

  test('maps log topics and levels to display labels', () {
    expect(presenter.topicLabel(LogTopic.system), '系统');
    expect(presenter.topicLabel(LogTopic.device), '设备');
    expect(presenter.topicLabel(LogTopic.permission), '权限');
    expect(presenter.topicLabel(LogTopic.session), '推流');
    expect(presenter.topicLabel(LogTopic.error), '错误');

    expect(presenter.levelLabel(LogLevel.warning), 'WARNING');
  });
}

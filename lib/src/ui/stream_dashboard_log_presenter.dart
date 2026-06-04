import '../domain.dart';

class StreamDashboardLogPresenter {
  const StreamDashboardLogPresenter();

  String timeText(StreamLogEntry entry) {
    return '${entry.timestamp.hour.toString().padLeft(2, '0')}:'
        '${entry.timestamp.minute.toString().padLeft(2, '0')}:'
        '${entry.timestamp.second.toString().padLeft(2, '0')}';
  }

  String levelLabel(LogLevel level) {
    return level.name.toUpperCase();
  }

  String topicLabel(LogTopic topic) {
    return switch (topic) {
      LogTopic.system => '系统',
      LogTopic.device => '设备',
      LogTopic.permission => '权限',
      LogTopic.session => '推流',
      LogTopic.error => '错误',
    };
  }
}

import 'package:flutter/material.dart';

import '../controller/xiangji_session_controller.dart';
import '../domain.dart';
import 'stream_dashboard_common.dart';
import 'stream_dashboard_log_presenter.dart';

class StreamDashboardLogOverview extends StatelessWidget {
  const StreamDashboardLogOverview({super.key, required this.controller});

  final XiangjiSessionController controller;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: <Widget>[
        StreamDashboardMiniStatus(
          icon: Icons.sensors,
          label: '实时',
          value: controller.isLiveStreaming ? '在线' : '空闲',
        ),
        StreamDashboardMiniStatus(
          icon: Icons.http,
          label: '地址',
          value: controller.isEndpointValid ? '有效' : '无效',
        ),
        StreamDashboardMiniStatus(
          icon: Icons.schedule,
          label: '最近推流',
          value: formatDashboardClock(controller.lastLiveEventAt),
        ),
      ],
    );
  }
}

class StreamDashboardLogRow extends StatelessWidget {
  const StreamDashboardLogRow({super.key, required this.entry});

  final StreamLogEntry entry;
  static const StreamDashboardLogPresenter _presenter =
      StreamDashboardLogPresenter();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final levelColor = _levelColor(context, entry.level);
    final topicColor = _topicColor(context, entry.topic);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: levelColor.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: levelColor.withValues(alpha: 0.16)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            SizedBox(
              width: 56,
              child: Text(
                _presenter.timeText(entry),
                style: TextStyle(color: levelColor, fontSize: 11),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: <Widget>[
                      _LogPill(
                        color: topicColor,
                        label: _presenter.topicLabel(entry.topic),
                      ),
                      _LogPill(
                        color: levelColor,
                        label: _presenter.levelLabel(entry.level),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    entry.message,
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: colorScheme.onSurface,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _levelColor(BuildContext context, LogLevel level) {
    final colorScheme = Theme.of(context).colorScheme;
    return switch (level) {
      LogLevel.debug => colorScheme.outline,
      LogLevel.info => colorScheme.primary,
      LogLevel.warning => Colors.orange.shade800,
      LogLevel.error => colorScheme.error,
    };
  }

  Color _topicColor(BuildContext context, LogTopic topic) {
    final scheme = Theme.of(context).colorScheme;
    return switch (topic) {
      LogTopic.system => Colors.blueGrey.shade700,
      LogTopic.device => Colors.indigo.shade700,
      LogTopic.permission => Colors.deepPurple.shade700,
      LogTopic.session => scheme.primary,
      LogTopic.error => scheme.error,
    };
  }
}

class _LogPill extends StatelessWidget {
  const _LogPill({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

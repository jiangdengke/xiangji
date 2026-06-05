import 'package:flutter/material.dart';

import '../controller/xiangji_session_controller.dart';
import '../domain.dart';
import 'stream_dashboard_common.dart';
import 'stream_dashboard_logs.dart';

class StreamDashboardLogsSection extends StatefulWidget {
  const StreamDashboardLogsSection({super.key, required this.controller});

  final XiangjiSessionController controller;

  @override
  State<StreamDashboardLogsSection> createState() =>
      _StreamDashboardLogsSectionState();
}

class _StreamDashboardLogsSectionState
    extends State<StreamDashboardLogsSection> {
  final ScrollController _scrollController = ScrollController();
  _StreamDashboardLogFilter _selectedFilter = _StreamDashboardLogFilter.all;

  XiangjiSessionController get controller => widget.controller;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final logs = controller.recentLogs.where(_matchesLogFilter).toList();
    final latestLog = controller.latestLog;
    return StreamDashboardSection(
      title: '日志',
      subtitle: latestLog == null
          ? '这里会显示摄像头、推流和系统事件。'
          : '最新：${latestLog.message}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          StreamDashboardLogOverview(controller: controller),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _StreamDashboardLogFilter.values
                .map((filter) {
                  return ChoiceChip(
                    label: Text(_filterLabel(filter)),
                    selected: _selectedFilter == filter,
                    onSelected: (_) {
                      setState(() {
                        _selectedFilter = filter;
                      });
                    },
                  );
                })
                .toList(growable: false),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 460,
            child: logs.isEmpty
                ? const Center(child: Text('没有匹配的日志。'))
                : Scrollbar(
                    controller: _scrollController,
                    thumbVisibility: true,
                    child: ListView.separated(
                      controller: _scrollController,
                      primary: false,
                      itemCount: logs.length,
                      separatorBuilder: (BuildContext context, int index) {
                        return const SizedBox(height: 8);
                      },
                      itemBuilder: (BuildContext context, int index) {
                        return StreamDashboardLogRow(entry: logs[index]);
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  bool _matchesLogFilter(StreamLogEntry entry) {
    return switch (_selectedFilter) {
      _StreamDashboardLogFilter.all => true,
      _StreamDashboardLogFilter.device => entry.topic == LogTopic.device,
      _StreamDashboardLogFilter.permission =>
        entry.topic == LogTopic.permission,
      _StreamDashboardLogFilter.session => entry.topic == LogTopic.session,
      _StreamDashboardLogFilter.errors =>
        entry.level == LogLevel.error || entry.topic == LogTopic.error,
    };
  }

  String _filterLabel(_StreamDashboardLogFilter filter) {
    return switch (filter) {
      _StreamDashboardLogFilter.all => '全部',
      _StreamDashboardLogFilter.device => '设备',
      _StreamDashboardLogFilter.permission => '权限',
      _StreamDashboardLogFilter.session => '推流',
      _StreamDashboardLogFilter.errors => '错误',
    };
  }
}

enum _StreamDashboardLogFilter { all, device, permission, session, errors }

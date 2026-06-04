import 'package:flutter/material.dart';

import '../controller/xiangji_session_controller.dart';
import 'stream_dashboard_config_section.dart';
import 'stream_dashboard_controls_section.dart';
import 'stream_dashboard_devices_section.dart';
import 'stream_dashboard_logs_section.dart';
import 'stream_dashboard_status_section.dart';

class StreamDashboardPage extends StatelessWidget {
  const StreamDashboardPage({super.key, required this.controller});

  final XiangjiSessionController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (BuildContext context, Widget? child) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('巡摄'),
            actions: <Widget>[
              IconButton(
                tooltip: '刷新设备',
                onPressed: controller.refreshDevices,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          body: SafeArea(
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                final wideLayout = constraints.maxWidth >= 1080;
                if (wideLayout) {
                  return Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Expanded(
                          child: SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: <Widget>[
                                StreamDashboardStatusSection(
                                  controller: controller,
                                ),
                                const SizedBox(height: 12),
                                StreamDashboardControlsSection(
                                  controller: controller,
                                ),
                                const SizedBox(height: 12),
                                StreamDashboardConfigSection(
                                  controller: controller,
                                ),
                                const SizedBox(height: 12),
                                StreamDashboardDevicesSection(
                                  controller: controller,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        SizedBox(
                          width: 380,
                          child: StreamDashboardLogsSection(
                            controller: controller,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView(
                  key: const Key('dashboard_scroll'),
                  padding: const EdgeInsets.all(16),
                  children: <Widget>[
                    StreamDashboardStatusSection(controller: controller),
                    const SizedBox(height: 12),
                    StreamDashboardControlsSection(controller: controller),
                    const SizedBox(height: 12),
                    StreamDashboardConfigSection(controller: controller),
                    const SizedBox(height: 12),
                    StreamDashboardDevicesSection(controller: controller),
                    const SizedBox(height: 12),
                    StreamDashboardLogsSection(controller: controller),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }
}

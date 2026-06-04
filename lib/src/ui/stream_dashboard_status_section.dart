import 'package:flutter/material.dart';

import '../controller/xiangji_session_controller.dart';
import '../domain.dart';
import 'stream_dashboard_common.dart';
import 'stream_dashboard_flow.dart';

class StreamDashboardStatusSection extends StatelessWidget {
  const StreamDashboardStatusSection({super.key, required this.controller});

  final XiangjiSessionController controller;

  @override
  Widget build(BuildContext context) {
    return StreamDashboardSection(
      title: '会话',
      subtitle: controller.statusMessage,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: <Widget>[
              StreamDashboardStatTile(
                icon: controller.bridgeSupported ? Icons.usb : Icons.usb_off,
                label: '桥接',
                value: controller.bridgeSupported ? '原生' : '回退',
              ),
              StreamDashboardStatTile(
                icon: _phaseIcon(controller.phase),
                label: '阶段',
                value: controller.phaseLabel,
              ),
              StreamDashboardStatTile(
                icon: controller.hasUsbDevices ? Icons.usb : Icons.usb_off,
                label: 'USB 设备',
                value: controller.hasUsbDevices
                    ? controller.usbDeviceCount.toString()
                    : '0',
              ),
              StreamDashboardStatTile(
                icon: controller.hasVideoCamera
                    ? Icons.videocam
                    : Icons.videocam_off,
                label: '摄像头',
                value: controller.hasVideoCamera
                    ? controller.selectedVideoCameraCount ==
                              controller.videoCameraCount
                          ? controller.videoCameraCount.toString()
                          : '${controller.selectedVideoCameraCount}/${controller.videoCameraCount}'
                    : '无',
              ),
              StreamDashboardStatTile(
                icon: controller.isLiveStreaming
                    ? Icons.sensors
                    : Icons.sensors_off,
                label: '实时',
                value: controller.isLiveStreaming ? '在线' : '离线',
              ),
              StreamDashboardStatTile(
                icon: Icons.badge_outlined,
                label: 'ID 前缀',
                value: controller.streamIdText,
              ),
              StreamDashboardStatTile(
                icon: Icons.schedule,
                label: '最近推流',
                value: formatDashboardClock(controller.lastLiveEventAt),
              ),
            ],
          ),
          const SizedBox(height: 16),
          StreamDashboardProcessFlow(controller: controller),
        ],
      ),
    );
  }
}

IconData _phaseIcon(SessionPhase phase) {
  switch (phase) {
    case SessionPhase.idle:
      return Icons.pause_circle_outline;
    case SessionPhase.discovering:
      return Icons.search;
    case SessionPhase.ready:
      return Icons.check_circle_outline;
    case SessionPhase.permissionRequested:
      return Icons.lock_clock;
    case SessionPhase.starting:
      return Icons.play_circle_outline;
    case SessionPhase.streaming:
      return Icons.radar;
    case SessionPhase.stopping:
      return Icons.stop_circle_outlined;
    case SessionPhase.error:
      return Icons.error_outline;
  }
}

import 'package:flutter/material.dart';

import '../controller/xiangji_session_controller.dart';
import '../domain.dart';
import 'stream_dashboard_common.dart';
import 'stream_dashboard_device_card.dart';

class StreamDashboardDevicesSection extends StatelessWidget {
  const StreamDashboardDevicesSection({super.key, required this.controller});

  final XiangjiSessionController controller;

  @override
  Widget build(BuildContext context) {
    final devices = controller.devices;
    return StreamDashboardSection(
      title: 'USB 设备',
      subtitle: devices.isEmpty
          ? '桥接层当前没有看到 USB 设备。'
          : controller.hasVideoCamera
          ? '检测到 ${controller.videoCameraCount} 个摄像头，已选 ${controller.selectedVideoCameraCount} 个。'
          : '检测到 USB 设备，但没有视频摄像头。',
      child: devices.isEmpty
          ? const Text('未检测到可用摄像头。')
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: devices
                  .map((UsbCameraDevice device) {
                    return StreamDashboardDeviceCard(
                      key: ValueKey<String>(device.deviceId),
                      controller: controller,
                      device: device,
                    );
                  })
                  .toList(growable: false),
            ),
    );
  }
}

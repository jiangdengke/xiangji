import 'package:flutter/material.dart';

import '../controller/xiangji_session_controller.dart';
import 'stream_dashboard_common.dart';

class StreamDashboardControlsSection extends StatelessWidget {
  const StreamDashboardControlsSection({super.key, required this.controller});

  final XiangjiSessionController controller;

  @override
  Widget build(BuildContext context) {
    return StreamDashboardSection(
      title: '控制',
      subtitle: _subtitle(),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: <Widget>[
          FilledButton.icon(
            onPressed: controller.canStart ? controller.start : null,
            icon: const Icon(Icons.play_arrow),
            label: const Text('开始'),
          ),
          FilledButton.tonalIcon(
            onPressed: controller.canStop ? controller.stop : null,
            icon: const Icon(Icons.stop),
            label: const Text('停止'),
          ),
          OutlinedButton.icon(
            onPressed: controller.hasSelectedVideoCamera
                ? controller.requestPermission
                : null,
            icon: const Icon(Icons.lock_open),
            label: const Text('权限'),
          ),
          OutlinedButton.icon(
            onPressed: controller.hasVideoCamera
                ? controller.selectAllVideoDevices
                : null,
            icon: const Icon(Icons.select_all),
            label: const Text('全选'),
          ),
          OutlinedButton.icon(
            onPressed: controller.hasSelectedVideoCamera
                ? controller.clearSelectedDevices
                : null,
            icon: const Icon(Icons.clear),
            label: const Text('清空'),
          ),
          OutlinedButton.icon(
            onPressed: controller.refreshDevices,
            icon: const Icon(Icons.refresh),
            label: const Text('重新扫描'),
          ),
        ],
      ),
    );
  }

  String _subtitle() {
    if (controller.lastError.isNotEmpty) {
      return controller.lastError;
    }
    if (!controller.bridgeSupported) {
      return '当前使用模拟桥接，真机需 Android 原生桥接。';
    }
    if (controller.hasSelectedVideoCamera) {
      return '当前已选中 ${controller.selectedVideoCameraCount} 路摄像头。';
    }
    return '请先在下方勾选至少一路视频摄像头。';
  }
}

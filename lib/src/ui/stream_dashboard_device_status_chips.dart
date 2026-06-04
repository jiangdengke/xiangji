import 'package:flutter/material.dart';

import '../domain.dart';

class StreamDashboardDeviceStatusChips extends StatelessWidget {
  const StreamDashboardDeviceStatusChips({
    super.key,
    required this.device,
    required this.selected,
  });

  final UsbCameraDevice device;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: <Widget>[
        Chip(
          label: Text(device.videoClass ? '摄像头' : '非摄像头'),
          visualDensity: VisualDensity.compact,
        ),
        const SizedBox(height: 4),
        Chip(
          label: Text(_selectionLabel),
          visualDensity: VisualDensity.compact,
        ),
        const SizedBox(height: 4),
        Chip(
          label: Text(device.permissionGranted ? '已授权' : '待授权'),
          visualDensity: VisualDensity.compact,
        ),
      ],
    );
  }

  String get _selectionLabel {
    if (!device.videoClass) {
      return '跳过';
    }
    return selected ? '已选' : '未选';
  }
}

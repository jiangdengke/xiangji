import 'package:flutter/material.dart';

import '../controller/xiangji_session_controller.dart';
import '../domain.dart';

class StreamDashboardDeviceStreamIdField extends StatelessWidget {
  const StreamDashboardDeviceStreamIdField({
    super.key,
    required this.controller,
    required this.device,
    required this.selected,
    required this.textController,
  });

  final XiangjiSessionController controller;
  final UsbCameraDevice device;
  final bool selected;
  final TextEditingController textController;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: textController,
      onChanged: (String value) {
        controller.updateDeviceStreamIdText(device.deviceId, value);
      },
      decoration: InputDecoration(
        labelText: '该路 camera_name',
        helperText: selected
            ? '启动时会作为 /offer/{camera_name} 的 camera_name。'
            : '未选中时不会启动这一路。',
        errorText: _errorText,
        suffixIcon: controller.isDeviceStreamIdCustom(device.deviceId)
            ? IconButton(
                tooltip: '恢复默认 ID',
                onPressed: () {
                  controller.resetDeviceStreamId(device.deviceId);
                },
                icon: const Icon(Icons.restart_alt),
              )
            : null,
        border: const OutlineInputBorder(),
      ),
      textInputAction: TextInputAction.done,
    );
  }

  String? get _errorText {
    if (!controller.isDeviceStreamIdValid(device.deviceId)) {
      return 'camera_name 必须是 camera1、camera2、camera3 或 camera4';
    }
    if (controller.isDeviceStreamIdDuplicate(device.deviceId)) {
      return '选中摄像头的流 ID 不能重复';
    }
    return null;
  }
}

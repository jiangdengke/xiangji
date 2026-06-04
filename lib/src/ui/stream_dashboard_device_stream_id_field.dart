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
        labelText: '该摄像头流 ID',
        helperText: selected
            ? '启动时会追加到 /offer 或 /whip 后，并通过 X-Stream-Id 区分这一路。'
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
      return '流 ID 不能为空，也不能包含空白字符';
    }
    if (controller.isDeviceStreamIdDuplicate(device.deviceId)) {
      return '选中摄像头的流 ID 不能重复';
    }
    return null;
  }
}

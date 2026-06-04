import 'package:flutter/material.dart';

import '../controller/xiangji_session_controller.dart';
import 'stream_dashboard_common.dart';

class StreamDashboardConfigSection extends StatefulWidget {
  const StreamDashboardConfigSection({super.key, required this.controller});

  final XiangjiSessionController controller;

  @override
  State<StreamDashboardConfigSection> createState() =>
      _StreamDashboardConfigSectionState();
}

class _StreamDashboardConfigSectionState
    extends State<StreamDashboardConfigSection> {
  late final TextEditingController _endpointController;
  late final TextEditingController _streamIdController;

  XiangjiSessionController get controller => widget.controller;

  @override
  void initState() {
    super.initState();
    _endpointController = TextEditingController(text: controller.endpointText);
    _streamIdController = TextEditingController(text: controller.streamIdText);
  }

  @override
  void didUpdateWidget(covariant StreamDashboardConfigSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncText(_endpointController, controller.endpointText);
    _syncText(_streamIdController, controller.streamIdText);
  }

  @override
  void dispose() {
    _endpointController.dispose();
    _streamIdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamDashboardSection(
      title: 'WebRTC 地址',
      subtitle: _configSubtitle(),
      child: Column(
        children: <Widget>[
          TextField(
            controller: _endpointController,
            onChanged: controller.updateEndpointText,
            decoration: InputDecoration(
              labelText: 'WHIP 地址',
              hintText: 'http://server:8080/whip/camera-001',
              helperText: 'Android 真机请填写接收端机器的局域网 IP，不要填 127.0.0.1。',
              errorText:
                  controller.endpointText.isNotEmpty &&
                      !controller.isEndpointValid
                  ? '请输入 HTTP 或 HTTPS 地址'
                  : null,
              border: const OutlineInputBorder(),
            ),
            keyboardType: TextInputType.url,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _streamIdController,
            onChanged: controller.updateStreamIdText,
            decoration: InputDecoration(
              labelText: '默认流 ID 前缀',
              helperText: '检测到多路摄像头时会生成 camera-001-01、camera-001-02，可在设备卡片里单独修改。',
              errorText: controller.isStreamIdValid
                  ? null
                  : '默认流 ID 前缀不能为空，也不能包含空白字符',
              border: const OutlineInputBorder(),
            ),
            textInputAction: TextInputAction.done,
          ),
        ],
      ),
    );
  }

  String _configSubtitle() {
    if (controller.endpointText.isEmpty) {
      return '开始前请填写 WHIP 接收端地址，例如 http://192.168.1.10:8080/whip/camera-001。';
    }
    if (!controller.isEndpointValid) {
      return '地址无效，请使用 HTTP 或 HTTPS WHIP 地址。';
    }
    if (!controller.isStreamIdValid) {
      return '默认流 ID 前缀不能为空，也不能包含空白字符。';
    }
    if (!controller.hasValidSelectedStreamIds) {
      return '选中摄像头里有无效流 ID，请在设备卡片里修正。';
    }
    if (!controller.hasUniqueSelectedStreamIds) {
      return '选中摄像头的流 ID 不能重复。';
    }
    return '每路摄像头可配置独立流 ID；启动后会为选中的每路摄像头分别创建 WebRTC 推流。';
  }
}

void _syncText(TextEditingController textController, String value) {
  if (textController.text == value) {
    return;
  }
  textController.value = TextEditingValue(
    text: value,
    selection: TextSelection.collapsed(offset: value.length),
  );
}

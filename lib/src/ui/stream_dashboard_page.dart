import 'package:flutter/material.dart';

import '../controller/xiangji_session_controller.dart';
import '../domain.dart';

class StreamDashboardPage extends StatefulWidget {
  const StreamDashboardPage({super.key, required this.controller});

  final XiangjiSessionController controller;

  @override
  State<StreamDashboardPage> createState() => _StreamDashboardPageState();
}

class _StreamDashboardPageState extends State<StreamDashboardPage> {
  late final TextEditingController _endpointController;
  late final TextEditingController _streamIdController;
  late final ScrollController _logScrollController;
  _LogFilter _selectedLogFilter = _LogFilter.all;

  XiangjiSessionController get controller => widget.controller;

  @override
  void initState() {
    super.initState();
    _endpointController = TextEditingController(text: controller.endpointText);
    _streamIdController = TextEditingController(text: controller.streamIdText);
    _logScrollController = ScrollController();
  }

  @override
  void dispose() {
    _endpointController.dispose();
    _streamIdController.dispose();
    _logScrollController.dispose();
    super.dispose();
  }

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
                                _statusSection(context),
                                const SizedBox(height: 12),
                                _controlsSection(context),
                                const SizedBox(height: 12),
                                _configSection(context),
                                const SizedBox(height: 12),
                                _devicesSection(context),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        SizedBox(width: 380, child: _logsSection(context)),
                      ],
                    ),
                  );
                }

                return ListView(
                  key: const Key('dashboard_scroll'),
                  padding: const EdgeInsets.all(16),
                  children: <Widget>[
                    _statusSection(context),
                    const SizedBox(height: 12),
                    _controlsSection(context),
                    const SizedBox(height: 12),
                    _configSection(context),
                    const SizedBox(height: 12),
                    _devicesSection(context),
                    const SizedBox(height: 12),
                    _logsSection(context),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _statusSection(BuildContext context) {
    return _Section(
      title: '会话',
      subtitle: controller.statusMessage,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: <Widget>[
              _StatTile(
                icon: controller.bridgeSupported ? Icons.usb : Icons.usb_off,
                label: '桥接',
                value: controller.bridgeSupported ? '原生' : '回退',
              ),
              _StatTile(
                icon: _phaseIcon(controller.phase),
                label: '阶段',
                value: controller.phaseLabel,
              ),
              _StatTile(
                icon: controller.hasUsbDevices ? Icons.usb : Icons.usb_off,
                label: 'USB 设备',
                value: controller.hasUsbDevices
                    ? controller.usbDeviceCount.toString()
                    : '0',
              ),
              _StatTile(
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
              _StatTile(
                icon: controller.isLiveStreaming
                    ? Icons.sensors
                    : Icons.sensors_off,
                label: '实时',
                value: controller.isLiveStreaming ? '在线' : '离线',
              ),
              _StatTile(
                icon: Icons.badge_outlined,
                label: 'ID 前缀',
                value: controller.streamIdText,
              ),
              _StatTile(
                icon: Icons.schedule,
                label: '最近推流',
                value: _formatClock(controller.lastLiveEventAt),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _ProcessFlow(controller: controller),
        ],
      ),
    );
  }

  Widget _controlsSection(BuildContext context) {
    return _Section(
      title: '控制',
      subtitle: controller.lastError.isEmpty
          ? !controller.bridgeSupported
                ? '当前使用模拟桥接，真机需 Android 原生桥接。'
                : controller.hasSelectedVideoCamera
                ? '当前已选中 ${controller.selectedVideoCameraCount} 路摄像头。'
                : '请先在下方勾选至少一路视频摄像头。'
          : controller.lastError,
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

  Widget _configSection(BuildContext context) {
    return _Section(
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
    return '每路摄像头可配置独立流 ID；当前实时 WebRTC 启动流程先推选中的第一路。';
  }

  Widget _devicesSection(BuildContext context) {
    final devices = controller.devices;
    return _Section(
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
                    return _DeviceCard(
                      key: ValueKey<String>(device.deviceId),
                      controller: controller,
                      device: device,
                    );
                  })
                  .toList(growable: false),
            ),
    );
  }

  Widget _logsSection(BuildContext context) {
    final logs = controller.recentLogs.where(_matchesLogFilter).toList();
    final latestLog = controller.latestLog;
    return _Section(
      title: '日志',
      subtitle: latestLog == null
          ? '这里会显示摄像头、推流和系统事件。'
          : '最新：${latestLog.message}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _LogOverview(controller: controller),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _LogFilter.values
                .map((filter) {
                  return ChoiceChip(
                    label: Text(_filterLabel(filter)),
                    selected: _selectedLogFilter == filter,
                    onSelected: (_) {
                      setState(() {
                        _selectedLogFilter = filter;
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
                    controller: _logScrollController,
                    thumbVisibility: true,
                    child: ListView.separated(
                      controller: _logScrollController,
                      primary: false,
                      itemCount: logs.length,
                      separatorBuilder: (BuildContext context, int index) {
                        return const SizedBox(height: 8);
                      },
                      itemBuilder: (BuildContext context, int index) {
                        return _LogRow(entry: logs[index]);
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  bool _matchesLogFilter(StreamLogEntry entry) {
    return switch (_selectedLogFilter) {
      _LogFilter.all => true,
      _LogFilter.device => entry.topic == LogTopic.device,
      _LogFilter.permission => entry.topic == LogTopic.permission,
      _LogFilter.session => entry.topic == LogTopic.session,
      _LogFilter.upload => entry.topic == LogTopic.upload,
      _LogFilter.errors =>
        entry.level == LogLevel.error || entry.topic == LogTopic.error,
    };
  }

  String _filterLabel(_LogFilter filter) {
    return switch (filter) {
      _LogFilter.all => '全部',
      _LogFilter.device => '设备',
      _LogFilter.permission => '权限',
      _LogFilter.session => '推流',
      _LogFilter.upload => '上传',
      _LogFilter.errors => '错误',
    };
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
}

class _ProcessFlow extends StatelessWidget {
  const _ProcessFlow({required this.controller});

  final XiangjiSessionController controller;

  @override
  Widget build(BuildContext context) {
    final selectedDevices = controller.selectedVideoDevices;
    final steps = <_FlowStep>[
      _FlowStep(
        icon: Icons.usb,
        label: 'USB 摄像头',
        value: _usbValue(),
        state: _usbState(),
      ),
      _FlowStep(
        icon: Icons.lock_open,
        label: '权限',
        value: _permissionValue(selectedDevices),
        state: _permissionState(selectedDevices),
      ),
      _FlowStep(
        icon: Icons.videocam,
        label: '视频',
        value: _videoValue(),
        state: _videoState(selectedDevices),
      ),
      _FlowStep(
        icon: Icons.sensors,
        label: 'WebRTC',
        value: _liveValue(),
        state: _liveState(),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('当前流程', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: steps
              .map((step) => _FlowStepTile(step: step))
              .toList(growable: false),
        ),
      ],
    );
  }

  String _usbValue() {
    if (controller.phase == SessionPhase.discovering) {
      return '扫描中';
    }
    if (!controller.hasUsbDevices) {
      return '未连接';
    }
    if (controller.hasVideoCamera) {
      return '${controller.selectedVideoCameraCount}/${controller.videoCameraCount} 已选';
    }
    return '无摄像头';
  }

  _FlowState _usbState() {
    if (controller.phase == SessionPhase.error && controller.devices.isEmpty) {
      return _FlowState.error;
    }
    if (controller.phase == SessionPhase.discovering) {
      return _FlowState.active;
    }
    if (controller.hasSelectedVideoCamera) {
      return _FlowState.done;
    }
    if (controller.hasVideoCamera) {
      return _FlowState.idle;
    }
    if (controller.hasUsbDevices) {
      return _FlowState.idle;
    }
    return _FlowState.blocked;
  }

  String _permissionValue(List<UsbCameraDevice> selectedDevices) {
    if (selectedDevices.isEmpty) {
      return '未选择';
    }
    if (controller.phase == SessionPhase.permissionRequested) {
      return '请求中';
    }
    final pendingCount = selectedDevices.where((UsbCameraDevice device) {
      return !device.permissionGranted;
    }).length;
    if (pendingCount == 0) {
      return '全部已授权';
    }
    return '$pendingCount 个待授权';
  }

  _FlowState _permissionState(List<UsbCameraDevice> selectedDevices) {
    if (controller.phase == SessionPhase.permissionRequested) {
      return _FlowState.active;
    }
    if (selectedDevices.isEmpty) {
      return _FlowState.blocked;
    }
    final allGranted = selectedDevices.every((UsbCameraDevice device) {
      return device.permissionGranted;
    });
    if (allGranted) {
      return _FlowState.done;
    }
    return _FlowState.idle;
  }

  String _videoValue() {
    if (!controller.hasVideoCamera) {
      return '无摄像头';
    }
    if (!controller.hasSelectedVideoCamera) {
      return '未选择';
    }
    return switch (controller.phase) {
      SessionPhase.starting => '启动中',
      SessionPhase.streaming => '推流中',
      SessionPhase.stopping => '停止中',
      SessionPhase.error => '错误',
      _ => '${controller.selectedVideoCameraCount} 路待启动',
    };
  }

  _FlowState _videoState(List<UsbCameraDevice> selectedDevices) {
    if (controller.phase == SessionPhase.error) {
      return _FlowState.error;
    }
    if (controller.phase == SessionPhase.starting ||
        controller.phase == SessionPhase.streaming) {
      return _FlowState.active;
    }
    if (!controller.hasVideoCamera) {
      return _FlowState.idle;
    }
    if (selectedDevices.isEmpty) {
      return _FlowState.blocked;
    }
    if (selectedDevices.every((UsbCameraDevice device) {
      return device.permissionGranted;
    })) {
      return _FlowState.idle;
    }
    return _FlowState.blocked;
  }

  String _liveValue() {
    if (!controller.isEndpointValid) {
      return '地址无效';
    }
    if (controller.phase == SessionPhase.starting) {
      return '连接中';
    }
    if (controller.phase == SessionPhase.streaming) {
      return '在线';
    }
    if (controller.phase == SessionPhase.stopping) {
      return '停止中';
    }
    return '等待中';
  }

  _FlowState _liveState() {
    if (!controller.isEndpointValid || controller.phase == SessionPhase.error) {
      return _FlowState.error;
    }
    if (controller.phase == SessionPhase.starting ||
        controller.phase == SessionPhase.streaming ||
        controller.phase == SessionPhase.stopping) {
      return _FlowState.active;
    }
    if (controller.hasSelectedVideoCamera) {
      return _FlowState.idle;
    }
    return _FlowState.blocked;
  }
}

class _FlowStep {
  const _FlowStep({
    required this.icon,
    required this.label,
    required this.value,
    required this.state,
  });

  final IconData icon;
  final String label;
  final String value;
  final _FlowState state;
}

enum _FlowState { idle, active, done, blocked, error }

enum _LogFilter { all, device, permission, session, upload, errors }

class _DeviceCard extends StatefulWidget {
  const _DeviceCard({super.key, required this.controller, required this.device});

  final XiangjiSessionController controller;
  final UsbCameraDevice device;

  @override
  State<_DeviceCard> createState() => _DeviceCardState();
}

class _DeviceCardState extends State<_DeviceCard> {
  late final TextEditingController _streamIdController;

  XiangjiSessionController get controller => widget.controller;
  UsbCameraDevice get device => widget.device;

  @override
  void initState() {
    super.initState();
    _streamIdController = TextEditingController(
      text: controller.streamIdForDeviceId(device.deviceId),
    );
  }

  @override
  void didUpdateWidget(covariant _DeviceCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncStreamIdText();
  }

  @override
  void dispose() {
    _streamIdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selected = controller.isDeviceSelected(device.deviceId);
    final selectable = device.videoClass;
    final scheme = Theme.of(context).colorScheme;
    final streamId = controller.streamIdForDeviceId(device.deviceId);
    final validStreamId = !selectable || controller.isDeviceStreamIdValid(
      device.deviceId,
    );
    final duplicateStreamId =
        selectable && controller.isDeviceStreamIdDuplicate(device.deviceId);
    final showStreamIdField = selectable;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        decoration: BoxDecoration(
          color: selected
              ? scheme.primary.withValues(alpha: 0.06)
              : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? scheme.primary : scheme.outlineVariant,
          ),
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            InkWell(
              onTap: selectable
                  ? () => controller.toggleDeviceSelection(device.deviceId)
                  : null,
              borderRadius: BorderRadius.circular(8),
              child: Row(
                children: <Widget>[
                  Checkbox(
                    value: selected,
                    onChanged: selectable
                        ? (bool? value) {
                            controller.setDeviceSelected(
                              device.deviceId,
                              value ?? false,
                            );
                          }
                        : null,
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    device.videoClass ? Icons.videocam : Icons.usb,
                    color: selected ? scheme.primary : scheme.outline,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          device.deviceName,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'VID ${device.vendorId.toRadixString(16).padLeft(4, '0')} '
                          'PID ${device.productId.toRadixString(16).padLeft(4, '0')} '
                          'IF ${device.interfaceCount}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: <Widget>[
                      Chip(
                        label: Text(device.videoClass ? '摄像头' : '非摄像头'),
                        visualDensity: VisualDensity.compact,
                      ),
                      const SizedBox(height: 4),
                      Chip(
                        label: Text(
                          device.videoClass
                              ? selected
                                    ? '已选'
                                    : '未选'
                              : '跳过',
                        ),
                        visualDensity: VisualDensity.compact,
                      ),
                      const SizedBox(height: 4),
                      Chip(
                        label: Text(
                          device.permissionGranted ? '已授权' : '待授权',
                        ),
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (showStreamIdField) ...<Widget>[
              const SizedBox(height: 12),
              TextField(
                controller: _streamIdController,
                onChanged: (String value) {
                  controller.updateDeviceStreamIdText(
                    device.deviceId,
                    value,
                  );
                },
                decoration: InputDecoration(
                  labelText: '该摄像头流 ID',
                  helperText: selected
                      ? '启动时会使用 /whip/$streamId 和 X-Stream-Id: $streamId。'
                      : '未选中时不会启动这一路。',
                  errorText: !validStreamId
                      ? '流 ID 不能为空，也不能包含空白字符'
                      : duplicateStreamId
                      ? '选中摄像头的流 ID 不能重复'
                      : null,
                  suffixIcon:
                      controller.isDeviceStreamIdCustom(device.deviceId)
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
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _syncStreamIdText() {
    final value = controller.streamIdForDeviceId(device.deviceId);
    if (_streamIdController.text == value) {
      return;
    }
    _streamIdController.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
  }
}

class _FlowStepTile extends StatelessWidget {
  const _FlowStepTile({required this.step});

  final _FlowStep step;

  @override
  Widget build(BuildContext context) {
    final color = _flowColor(context, step.state);
    final labelStyle = Theme.of(context).textTheme.bodySmall;
    return Container(
      width: 164,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Row(
        children: <Widget>[
          Icon(step.icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(step.label, style: labelStyle),
                const SizedBox(height: 2),
                Text(
                  step.value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _flowColor(BuildContext context, _FlowState state) {
    final scheme = Theme.of(context).colorScheme;
    return switch (state) {
      _FlowState.done => Colors.green.shade700,
      _FlowState.active => scheme.primary,
      _FlowState.idle => Colors.blueGrey.shade600,
      _FlowState.blocked => scheme.outline,
      _FlowState.error => scheme.error,
    };
  }
}

class _LogOverview extends StatelessWidget {
  const _LogOverview({required this.controller});

  final XiangjiSessionController controller;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: <Widget>[
        _MiniStatus(
          icon: Icons.sensors,
          label: '实时',
          value: controller.isLiveStreaming ? '在线' : '空闲',
        ),
        _MiniStatus(
          icon: Icons.http,
          label: '地址',
          value: controller.isEndpointValid ? '有效' : '无效',
        ),
        _MiniStatus(
          icon: Icons.schedule,
          label: '最近推流',
          value: _formatClock(controller.lastLiveEventAt),
        ),
      ],
    );
  }
}

class _MiniStatus extends StatelessWidget {
  const _MiniStatus({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 16, color: scheme.primary),
          const SizedBox(width: 6),
          Text('$label: ', style: Theme.of(context).textTheme.bodySmall),
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.dividerColor),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(title, style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            subtitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: 148,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.dividerColor),
        color: const Color(0xFFFDFEFE),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, size: 18),
          const SizedBox(height: 8),
          Text(label, style: theme.textTheme.bodySmall),
          const SizedBox(height: 4),
          Text(value, style: theme.textTheme.titleMedium),
        ],
      ),
    );
  }
}

class _LogRow extends StatelessWidget {
  const _LogRow({required this.entry});

  final StreamLogEntry entry;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final levelColor = _levelColor(context, entry.level);
    final topicColor = _topicColor(context, entry.topic);
    final time =
        '${entry.timestamp.hour.toString().padLeft(2, '0')}:'
        '${entry.timestamp.minute.toString().padLeft(2, '0')}:'
        '${entry.timestamp.second.toString().padLeft(2, '0')}';

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
                time,
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
                        label: _topicLabel(entry.topic),
                      ),
                      _LogPill(
                        color: levelColor,
                        label: entry.level.name.toUpperCase(),
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
      LogTopic.upload => Colors.green.shade700,
      LogTopic.error => scheme.error,
    };
  }

  String _topicLabel(LogTopic topic) {
    return switch (topic) {
      LogTopic.system => '系统',
      LogTopic.device => '设备',
      LogTopic.permission => '权限',
      LogTopic.session => '推流',
      LogTopic.upload => '上传',
      LogTopic.error => '错误',
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

String _formatClock(DateTime? timestamp) {
  if (timestamp == null) {
    return '--:--:--';
  }
  return '${timestamp.hour.toString().padLeft(2, '0')}:'
      '${timestamp.minute.toString().padLeft(2, '0')}:'
      '${timestamp.second.toString().padLeft(2, '0')}';
}

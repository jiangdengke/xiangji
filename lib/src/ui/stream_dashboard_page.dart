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
  late final TextEditingController _fragmentController;
  late final ScrollController _logScrollController;
  _LogFilter _selectedLogFilter = _LogFilter.all;

  XiangjiSessionController get controller => widget.controller;

  @override
  void initState() {
    super.initState();
    _endpointController = TextEditingController(text: controller.endpointText);
    _streamIdController = TextEditingController(text: controller.streamIdText);
    _fragmentController = TextEditingController(
      text: controller.fragmentDurationText,
    );
    _logScrollController = ScrollController();
  }

  @override
  void dispose() {
    _endpointController.dispose();
    _streamIdController.dispose();
    _fragmentController.dispose();
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
            title: const Text('Xiangji Stream'),
            actions: <Widget>[
              IconButton(
                tooltip: 'Refresh devices',
                onPressed: controller.refreshDevices,
                icon: const Icon(Icons.refresh),
              ),
              IconButton(
                tooltip: 'Retry uploads',
                onPressed: controller.retryPendingUploads,
                icon: const Icon(Icons.restart_alt),
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
      title: 'Session',
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
                label: 'Bridge',
                value: controller.bridgeSupported ? 'Native' : 'Fallback',
              ),
              _StatTile(
                icon: _phaseIcon(controller.phase),
                label: 'Phase',
                value: controller.phase.name,
              ),
              _StatTile(
                icon: Icons.cloud_upload,
                label: 'Queued',
                value: controller.pendingUploadCount.toString(),
              ),
              _StatTile(
                icon: Icons.done,
                label: 'Uploaded',
                value: controller.uploadedSegments.toString(),
              ),
              _StatTile(
                icon: Icons.error_outline,
                label: 'Failed',
                value: controller.failedSegments.toString(),
              ),
              _StatTile(
                icon: Icons.movie_creation_outlined,
                label: 'Last video',
                value: _formatClock(controller.lastSegmentAt),
              ),
              _StatTile(
                icon: Icons.upload_file,
                label: 'Last upload',
                value: _formatClock(controller.lastUploadAt),
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
    final selectedDevice = controller.selectedDevice;
    return _Section(
      title: 'Controls',
      subtitle: controller.lastError.isEmpty
          ? 'Operate the selected USB camera.'
          : controller.lastError,
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: <Widget>[
          FilledButton.icon(
            onPressed: controller.canStart ? controller.start : null,
            icon: const Icon(Icons.play_arrow),
            label: const Text('Start'),
          ),
          FilledButton.tonalIcon(
            onPressed: controller.canStop ? controller.stop : null,
            icon: const Icon(Icons.stop),
            label: const Text('Stop'),
          ),
          OutlinedButton.icon(
            onPressed: selectedDevice == null
                ? null
                : controller.requestPermission,
            icon: const Icon(Icons.lock_open),
            label: const Text('Permission'),
          ),
          OutlinedButton.icon(
            onPressed: controller.refreshDevices,
            icon: const Icon(Icons.refresh),
            label: const Text('Rescan'),
          ),
        ],
      ),
    );
  }

  Widget _configSection(BuildContext context) {
    return _Section(
      title: 'Upload target',
      subtitle: controller.isEndpointValid
          ? 'The uploader posts each segment as a raw MP4 body.'
          : 'Enter a valid HTTP or HTTPS endpoint before starting.',
      child: Column(
        children: <Widget>[
          TextField(
            controller: _endpointController,
            onChanged: controller.updateEndpointText,
            decoration: const InputDecoration(
              labelText: 'Endpoint',
              hintText: 'http://server:8080/api/camera/segments',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.url,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Expanded(
                child: TextField(
                  controller: _streamIdController,
                  onChanged: controller.updateStreamIdText,
                  decoration: const InputDecoration(
                    labelText: 'Stream ID',
                    border: OutlineInputBorder(),
                  ),
                  textInputAction: TextInputAction.next,
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 180,
                child: TextField(
                  controller: _fragmentController,
                  onChanged: controller.updateFragmentDurationText,
                  decoration: const InputDecoration(
                    labelText: 'Fragment ms',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _devicesSection(BuildContext context) {
    final devices = controller.devices;
    return _Section(
      title: 'USB devices',
      subtitle: devices.isEmpty
          ? 'No USB camera is visible to the bridge.'
          : '${devices.length} device(s) detected.',
      child: devices.isEmpty
          ? const Text('No compatible camera was detected.')
          : Column(
              children: devices
                  .map((UsbCameraDevice device) {
                    final selected =
                        controller.selectedDeviceId == device.deviceId;
                    final scheme = Theme.of(context).colorScheme;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: InkWell(
                        onTap: () => controller.selectDevice(device.deviceId),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          decoration: BoxDecoration(
                            color: selected
                                ? scheme.primary.withValues(alpha: 0.06)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: selected
                                  ? scheme.primary
                                  : scheme.outlineVariant,
                            ),
                          ),
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: <Widget>[
                              Icon(
                                device.videoClass ? Icons.videocam : Icons.usb,
                                color: selected
                                    ? scheme.primary
                                    : scheme.outline,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Text(
                                      device.deviceName,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleMedium,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'VID ${device.vendorId.toRadixString(16).padLeft(4, '0')} '
                                      'PID ${device.productId.toRadixString(16).padLeft(4, '0')} '
                                      'IF ${device.interfaceCount}',
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Chip(
                                label: Text(
                                  device.permissionGranted
                                      ? 'Granted'
                                      : 'Pending',
                                ),
                                visualDensity: VisualDensity.compact,
                              ),
                            ],
                          ),
                        ),
                      ),
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
      title: 'Logs',
      subtitle: latestLog == null
          ? 'Watch camera, capture, and upload events here.'
          : 'Latest: ${latestLog.message}',
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
                ? const Center(child: Text('No matching logs.'))
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
      _LogFilter.all => 'All',
      _LogFilter.device => 'Device',
      _LogFilter.permission => 'Permission',
      _LogFilter.session => 'Video',
      _LogFilter.upload => 'Upload',
      _LogFilter.errors => 'Errors',
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
    final selectedDevice = controller.selectedDevice;
    final steps = <_FlowStep>[
      _FlowStep(
        icon: Icons.usb,
        label: 'USB camera',
        value: _usbValue(),
        state: _usbState(),
      ),
      _FlowStep(
        icon: Icons.lock_open,
        label: 'Permission',
        value: _permissionValue(selectedDevice),
        state: _permissionState(selectedDevice),
      ),
      _FlowStep(
        icon: Icons.videocam,
        label: 'Video',
        value: _videoValue(),
        state: _videoState(selectedDevice),
      ),
      _FlowStep(
        icon: Icons.cloud_upload,
        label: 'Upload',
        value: _uploadValue(),
        state: _uploadState(),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('Current flow', style: Theme.of(context).textTheme.titleSmall),
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
      return 'Scanning';
    }
    if (controller.devices.isEmpty) {
      return 'Not connected';
    }
    return '${controller.devices.length} detected';
  }

  _FlowState _usbState() {
    if (controller.phase == SessionPhase.error && controller.devices.isEmpty) {
      return _FlowState.error;
    }
    if (controller.phase == SessionPhase.discovering) {
      return _FlowState.active;
    }
    if (controller.devices.isNotEmpty) {
      return _FlowState.done;
    }
    return _FlowState.blocked;
  }

  String _permissionValue(UsbCameraDevice? selectedDevice) {
    if (selectedDevice == null) {
      return 'No device';
    }
    if (controller.phase == SessionPhase.permissionRequested) {
      return 'Requesting';
    }
    return selectedDevice.permissionGranted ? 'Granted' : 'Needed';
  }

  _FlowState _permissionState(UsbCameraDevice? selectedDevice) {
    if (controller.phase == SessionPhase.permissionRequested) {
      return _FlowState.active;
    }
    if (selectedDevice == null) {
      return _FlowState.blocked;
    }
    return selectedDevice.permissionGranted ? _FlowState.done : _FlowState.idle;
  }

  String _videoValue() {
    return switch (controller.phase) {
      SessionPhase.starting => 'Starting',
      SessionPhase.streaming => 'Recording',
      SessionPhase.stopping => 'Stopping',
      SessionPhase.error => 'Error',
      _ => 'Stopped',
    };
  }

  _FlowState _videoState(UsbCameraDevice? selectedDevice) {
    if (controller.phase == SessionPhase.error) {
      return _FlowState.error;
    }
    if (controller.phase == SessionPhase.starting ||
        controller.phase == SessionPhase.streaming) {
      return _FlowState.active;
    }
    if (selectedDevice?.permissionGranted ?? false) {
      return _FlowState.idle;
    }
    return _FlowState.blocked;
  }

  String _uploadValue() {
    if (controller.isUploading) {
      return 'Uploading';
    }
    if (controller.pendingUploadCount > 0) {
      return '${controller.pendingUploadCount} queued';
    }
    if (controller.uploadedSegments > 0) {
      return 'Last ${_formatClock(controller.lastUploadAt)}';
    }
    return 'Waiting';
  }

  _FlowState _uploadState() {
    if (controller.failedSegments > 0 && controller.uploadedSegments == 0) {
      return _FlowState.error;
    }
    if (controller.isUploading || controller.pendingUploadCount > 0) {
      return _FlowState.active;
    }
    if (controller.uploadedSegments > 0) {
      return _FlowState.done;
    }
    if (controller.phase == SessionPhase.streaming) {
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
          icon: Icons.videocam,
          label: 'Video',
          value: controller.phase == SessionPhase.streaming ? 'Live' : 'Idle',
        ),
        _MiniStatus(
          icon: Icons.cloud_upload,
          label: 'Upload',
          value: controller.isUploading
              ? 'Active'
              : controller.pendingUploadCount > 0
              ? 'Queued'
              : 'Idle',
        ),
        _MiniStatus(
          icon: Icons.schedule,
          label: 'Last upload',
          value: _formatClock(controller.lastUploadAt),
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
      LogTopic.system => 'SYSTEM',
      LogTopic.device => 'DEVICE',
      LogTopic.permission => 'PERMISSION',
      LogTopic.session => 'VIDEO',
      LogTopic.upload => 'UPLOAD',
      LogTopic.error => 'ERROR',
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

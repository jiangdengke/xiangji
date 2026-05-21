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

  XiangjiSessionController get controller => widget.controller;

  @override
  void initState() {
    super.initState();
    _endpointController = TextEditingController(text: controller.endpointText);
    _streamIdController = TextEditingController(text: controller.streamIdText);
    _fragmentController = TextEditingController(
      text: controller.fragmentDurationText,
    );
  }

  @override
  void dispose() {
    _endpointController.dispose();
    _streamIdController.dispose();
    _fragmentController.dispose();
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
      child: Wrap(
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
    final logs = controller.logs;
    return _Section(
      title: 'Logs',
      subtitle: 'Latest events from the bridge and uploader.',
      child: SizedBox(
        height: 420,
        child: logs.isEmpty
            ? const Center(child: Text('No logs yet.'))
            : ListView.separated(
                itemCount: logs.length,
                separatorBuilder: (BuildContext context, int index) {
                  return const SizedBox(height: 8);
                },
                itemBuilder: (BuildContext context, int index) {
                  return _LogRow(entry: logs[index]);
                },
              ),
      ),
    );
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
          Text(subtitle, style: theme.textTheme.bodySmall),
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
    final color = switch (entry.level) {
      LogLevel.debug => colorScheme.outline,
      LogLevel.info => colorScheme.primary,
      LogLevel.warning => Colors.orange.shade800,
      LogLevel.error => colorScheme.error,
    };
    final time =
        '${entry.timestamp.hour.toString().padLeft(2, '0')}:'
        '${entry.timestamp.minute.toString().padLeft(2, '0')}:'
        '${entry.timestamp.second.toString().padLeft(2, '0')}';

    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            SizedBox(
              width: 56,
              child: Text(time, style: TextStyle(color: color, fontSize: 11)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                entry.message,
                style: TextStyle(color: colorScheme.onSurface, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

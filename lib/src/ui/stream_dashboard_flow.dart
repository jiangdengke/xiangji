import 'package:flutter/material.dart';

import '../controller/xiangji_session_controller.dart';
import 'stream_dashboard_flow_model.dart';
import 'stream_dashboard_flow_types.dart';

class StreamDashboardProcessFlow extends StatelessWidget {
  const StreamDashboardProcessFlow({super.key, required this.controller});

  final XiangjiSessionController controller;

  @override
  Widget build(BuildContext context) {
    final steps = StreamDashboardFlowPresenter(
      StreamDashboardFlowSnapshot(
        phase: controller.phase,
        devices: controller.devices,
        selectedVideoDevices: controller.selectedVideoDevices,
        selectedVideoCameraCount: controller.selectedVideoCameraCount,
        videoCameraCount: controller.videoCameraCount,
        hasUsbDevices: controller.hasUsbDevices,
        hasVideoCamera: controller.hasVideoCamera,
        hasSelectedVideoCamera: controller.hasSelectedVideoCamera,
        isEndpointValid: controller.isEndpointValid,
      ),
    ).buildSteps();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('当前流程', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: steps
              .map((step) => _StreamDashboardFlowStepTile(step: step))
              .toList(growable: false),
        ),
      ],
    );
  }
}

class _StreamDashboardFlowStepTile extends StatelessWidget {
  const _StreamDashboardFlowStepTile({required this.step});

  final StreamDashboardFlowStep step;

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
          Icon(_iconFor(step.kind), color: color, size: 20),
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

  Color _flowColor(BuildContext context, StreamDashboardFlowState state) {
    final scheme = Theme.of(context).colorScheme;
    return switch (state) {
      StreamDashboardFlowState.done => Colors.green.shade700,
      StreamDashboardFlowState.active => scheme.primary,
      StreamDashboardFlowState.idle => Colors.blueGrey.shade600,
      StreamDashboardFlowState.blocked => scheme.outline,
      StreamDashboardFlowState.error => scheme.error,
    };
  }

  IconData _iconFor(StreamDashboardFlowStepKind kind) {
    return switch (kind) {
      StreamDashboardFlowStepKind.usb => Icons.usb,
      StreamDashboardFlowStepKind.permission => Icons.lock_open,
      StreamDashboardFlowStepKind.video => Icons.videocam,
      StreamDashboardFlowStepKind.live => Icons.sensors,
    };
  }
}

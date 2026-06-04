import 'package:flutter/material.dart';

import '../controller/xiangji_session_controller.dart';
import '../domain.dart';
import 'stream_dashboard_device_identity.dart';
import 'stream_dashboard_device_status_chips.dart';
import 'stream_dashboard_device_stream_id_field.dart';

class StreamDashboardDeviceCard extends StatefulWidget {
  const StreamDashboardDeviceCard({
    super.key,
    required this.controller,
    required this.device,
  });

  final XiangjiSessionController controller;
  final UsbCameraDevice device;

  @override
  State<StreamDashboardDeviceCard> createState() =>
      _StreamDashboardDeviceCardState();
}

class _StreamDashboardDeviceCardState
    extends State<StreamDashboardDeviceCard> {
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
  void didUpdateWidget(covariant StreamDashboardDeviceCard oldWidget) {
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
                  Expanded(
                    child: StreamDashboardDeviceIdentity(
                      device: device,
                      selected: selected,
                    ),
                  ),
                  const SizedBox(width: 12),
                  StreamDashboardDeviceStatusChips(
                    device: device,
                    selected: selected,
                  ),
                ],
              ),
            ),
            if (selectable) ...<Widget>[
              const SizedBox(height: 12),
              StreamDashboardDeviceStreamIdField(
                controller: controller,
                device: device,
                selected: selected,
                textController: _streamIdController,
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

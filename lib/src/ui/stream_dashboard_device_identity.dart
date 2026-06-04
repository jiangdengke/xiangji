import 'package:flutter/material.dart';

import '../domain.dart';

class StreamDashboardDeviceIdentity extends StatelessWidget {
  const StreamDashboardDeviceIdentity({
    super.key,
    required this.device,
    required this.selected,
  });

  final UsbCameraDevice device;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: <Widget>[
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
      ],
    );
  }
}

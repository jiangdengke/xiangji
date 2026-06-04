import '../domain.dart';

class StreamDashboardFlowSnapshot {
  const StreamDashboardFlowSnapshot({
    required this.phase,
    required this.devices,
    required this.selectedVideoDevices,
    required this.selectedVideoCameraCount,
    required this.videoCameraCount,
    required this.hasUsbDevices,
    required this.hasVideoCamera,
    required this.hasSelectedVideoCamera,
    required this.isEndpointValid,
  });

  final SessionPhase phase;
  final List<UsbCameraDevice> devices;
  final List<UsbCameraDevice> selectedVideoDevices;
  final int selectedVideoCameraCount;
  final int videoCameraCount;
  final bool hasUsbDevices;
  final bool hasVideoCamera;
  final bool hasSelectedVideoCamera;
  final bool isEndpointValid;
}

class StreamDashboardFlowStep {
  const StreamDashboardFlowStep({
    required this.kind,
    required this.label,
    required this.value,
    required this.state,
  });

  final StreamDashboardFlowStepKind kind;
  final String label;
  final String value;
  final StreamDashboardFlowState state;
}

enum StreamDashboardFlowStepKind { usb, permission, video, live }

enum StreamDashboardFlowState { idle, active, done, blocked, error }

import '../domain.dart';
import 'stream_dashboard_flow_types.dart';

StreamDashboardFlowStep buildVideoFlowStep(
  StreamDashboardFlowSnapshot snapshot,
) {
  final selectedDevices = snapshot.selectedVideoDevices;
  return StreamDashboardFlowStep(
    kind: StreamDashboardFlowStepKind.video,
    label: '视频',
    value: _videoValue(snapshot),
    state: _videoState(snapshot, selectedDevices),
  );
}

String _videoValue(StreamDashboardFlowSnapshot snapshot) {
  if (!snapshot.hasVideoCamera) {
    return '无摄像头';
  }
  if (!snapshot.hasSelectedVideoCamera) {
    return '未选择';
  }
  return switch (snapshot.phase) {
    SessionPhase.starting => '启动中',
    SessionPhase.streaming => '推流中',
    SessionPhase.stopping => '停止中',
    SessionPhase.error => '错误',
    _ => '${snapshot.selectedVideoCameraCount} 路待启动',
  };
}

StreamDashboardFlowState _videoState(
  StreamDashboardFlowSnapshot snapshot,
  List<UsbCameraDevice> selectedDevices,
) {
  if (snapshot.phase == SessionPhase.error) {
    return StreamDashboardFlowState.error;
  }
  if (snapshot.phase == SessionPhase.starting ||
      snapshot.phase == SessionPhase.streaming) {
    return StreamDashboardFlowState.active;
  }
  if (!snapshot.hasVideoCamera) {
    return StreamDashboardFlowState.idle;
  }
  if (selectedDevices.isEmpty) {
    return StreamDashboardFlowState.blocked;
  }
  if (_allGranted(selectedDevices)) {
    return StreamDashboardFlowState.idle;
  }
  return StreamDashboardFlowState.blocked;
}

bool _allGranted(List<UsbCameraDevice> devices) {
  return devices.every((UsbCameraDevice device) {
    return device.permissionGranted;
  });
}

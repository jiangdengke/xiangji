import '../domain.dart';
import 'stream_dashboard_flow_types.dart';

StreamDashboardFlowStep buildUsbFlowStep(StreamDashboardFlowSnapshot snapshot) {
  return StreamDashboardFlowStep(
    kind: StreamDashboardFlowStepKind.usb,
    label: 'USB 摄像头',
    value: _usbValue(snapshot),
    state: _usbState(snapshot),
  );
}

String _usbValue(StreamDashboardFlowSnapshot snapshot) {
  if (snapshot.phase == SessionPhase.discovering) {
    return '扫描中';
  }
  if (!snapshot.hasUsbDevices) {
    return '未连接';
  }
  if (snapshot.hasVideoCamera) {
    return '${snapshot.selectedVideoCameraCount}/${snapshot.videoCameraCount} 已选';
  }
  return '无摄像头';
}

StreamDashboardFlowState _usbState(StreamDashboardFlowSnapshot snapshot) {
  if (snapshot.phase == SessionPhase.error && snapshot.devices.isEmpty) {
    return StreamDashboardFlowState.error;
  }
  if (snapshot.phase == SessionPhase.discovering) {
    return StreamDashboardFlowState.active;
  }
  if (snapshot.hasSelectedVideoCamera) {
    return StreamDashboardFlowState.done;
  }
  if (snapshot.hasVideoCamera || snapshot.hasUsbDevices) {
    return StreamDashboardFlowState.idle;
  }
  return StreamDashboardFlowState.blocked;
}

import '../domain.dart';
import 'stream_dashboard_flow_types.dart';

StreamDashboardFlowStep buildPermissionFlowStep(
  StreamDashboardFlowSnapshot snapshot,
) {
  final selectedDevices = snapshot.selectedVideoDevices;
  return StreamDashboardFlowStep(
    kind: StreamDashboardFlowStepKind.permission,
    label: '权限',
    value: _permissionValue(snapshot, selectedDevices),
    state: _permissionState(snapshot, selectedDevices),
  );
}

String _permissionValue(
  StreamDashboardFlowSnapshot snapshot,
  List<UsbCameraDevice> selectedDevices,
) {
  if (selectedDevices.isEmpty) {
    return '未选择';
  }
  if (snapshot.phase == SessionPhase.permissionRequested) {
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

StreamDashboardFlowState _permissionState(
  StreamDashboardFlowSnapshot snapshot,
  List<UsbCameraDevice> selectedDevices,
) {
  if (snapshot.phase == SessionPhase.permissionRequested) {
    return StreamDashboardFlowState.active;
  }
  if (selectedDevices.isEmpty) {
    return StreamDashboardFlowState.blocked;
  }
  if (_allGranted(selectedDevices)) {
    return StreamDashboardFlowState.done;
  }
  return StreamDashboardFlowState.idle;
}

bool _allGranted(List<UsbCameraDevice> devices) {
  return devices.every((UsbCameraDevice device) {
    return device.permissionGranted;
  });
}

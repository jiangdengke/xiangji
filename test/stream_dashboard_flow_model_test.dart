import 'package:flutter_test/flutter_test.dart';

import 'package:xiangji/src/domain.dart';
import 'package:xiangji/src/ui/stream_dashboard_flow_model.dart';
import 'package:xiangji/src/ui/stream_dashboard_flow_types.dart';

void main() {
  test('marks flow blocked when no USB devices are visible', () {
    final steps = StreamDashboardFlowPresenter(
      const StreamDashboardFlowSnapshot(
        phase: SessionPhase.idle,
        devices: <UsbCameraDevice>[],
        selectedVideoDevices: <UsbCameraDevice>[],
        selectedVideoCameraCount: 0,
        videoCameraCount: 0,
        hasUsbDevices: false,
        hasVideoCamera: false,
        hasSelectedVideoCamera: false,
        isEndpointValid: true,
      ),
    ).buildSteps();

    expect(_step(steps, StreamDashboardFlowStepKind.usb).value, '未连接');
    expect(
      _step(steps, StreamDashboardFlowStepKind.usb).state,
      StreamDashboardFlowState.blocked,
    );
    expect(
      _step(steps, StreamDashboardFlowStepKind.live).state,
      StreamDashboardFlowState.blocked,
    );
  });

  test('marks selected and authorized camera flow as ready', () {
    final camera = _camera(permissionGranted: true);
    final steps = StreamDashboardFlowPresenter(
      StreamDashboardFlowSnapshot(
        phase: SessionPhase.ready,
        devices: <UsbCameraDevice>[camera],
        selectedVideoDevices: <UsbCameraDevice>[camera],
        selectedVideoCameraCount: 1,
        videoCameraCount: 1,
        hasUsbDevices: true,
        hasVideoCamera: true,
        hasSelectedVideoCamera: true,
        isEndpointValid: true,
      ),
    ).buildSteps();

    expect(_step(steps, StreamDashboardFlowStepKind.usb).value, '1/1 已选');
    expect(
      _step(steps, StreamDashboardFlowStepKind.permission).state,
      StreamDashboardFlowState.done,
    );
    expect(_step(steps, StreamDashboardFlowStepKind.video).value, '1 路待启动');
    expect(
      _step(steps, StreamDashboardFlowStepKind.live).state,
      StreamDashboardFlowState.idle,
    );
  });
}

StreamDashboardFlowStep _step(
  List<StreamDashboardFlowStep> steps,
  StreamDashboardFlowStepKind kind,
) {
  return steps.singleWhere((StreamDashboardFlowStep step) {
    return step.kind == kind;
  });
}

UsbCameraDevice _camera({required bool permissionGranted}) {
  return UsbCameraDevice(
    deviceId: 'camera-1',
    deviceName: 'Camera 1',
    vendorId: 1,
    productId: 2,
    permissionGranted: permissionGranted,
    videoClass: true,
    interfaceCount: 1,
  );
}

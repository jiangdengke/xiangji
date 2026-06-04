import '../domain.dart';
import 'live_stream_routing.dart';
import 'live_stream_start_models.dart';

class LiveStreamStartPreparer {
  const LiveStreamStartPreparer({required LiveStreamRouting routing})
    : _routing = routing;

  final LiveStreamRouting _routing;

  LiveStreamStartPreparation prepare(
    Iterable<UsbCameraDevice> selectedCameras,
  ) {
    final cameras = selectedCameras.toList(growable: false);
    if (cameras.isEmpty) {
      return LiveStreamStartPreparation.rejected(
        message: '开始前请先选择至少一个 USB 摄像头。',
        topic: LogTopic.device,
      );
    }

    if (!_routing.isStreamIdPrefixValid) {
      return LiveStreamStartPreparation.rejected(
        message: '默认流 ID 前缀不能为空，也不能包含空白字符。',
        topic: LogTopic.session,
      );
    }

    final invalidStreamIdDevices = cameras.where((UsbCameraDevice device) {
      return !_routing.isDeviceStreamIdValid(device.deviceId);
    }).toList(growable: false);
    if (invalidStreamIdDevices.isNotEmpty) {
      return LiveStreamStartPreparation.rejected(
        message: '有 ${invalidStreamIdDevices.length} 路摄像头的流 ID 无效，请先修正。',
        topic: LogTopic.session,
      );
    }

    if (!_routing.hasUniqueStreamIds(cameras)) {
      return LiveStreamStartPreparation.rejected(
        message: '选中摄像头的流 ID 不能重复，请先修正。',
        topic: LogTopic.session,
      );
    }

    final baseEndpoint = _routing.liveEndpoint;
    if (baseEndpoint == null) {
      return LiveStreamStartPreparation.rejected(
        message: '请输入有效的 HTTP 或 HTTPS WebRTC 推流地址。',
        topic: LogTopic.session,
      );
    }

    final unauthorizedDevices = cameras
        .where((UsbCameraDevice device) => !device.permissionGranted)
        .toList(growable: false);
    if (unauthorizedDevices.isNotEmpty) {
      return LiveStreamStartPreparation.needsPermission(
        selectedCameras: cameras,
        pendingPermissionDevices: unauthorizedDevices,
        message: '有 ${unauthorizedDevices.length} 路摄像头还没有 USB 权限，先请求权限。',
      );
    }

    return LiveStreamStartPreparation.ready(
      selectedCameras: cameras,
      baseEndpoint: baseEndpoint,
    );
  }
}

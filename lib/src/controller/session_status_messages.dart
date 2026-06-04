import '../live/live_stream_start_models.dart';

class SessionStatusMessages {
  const SessionStatusMessages();

  String get initial => '等待 USB 摄像头。';
  String get discovering => '正在扫描 USB 设备。';
  String get permissionReady => 'USB 权限已就绪。';
  String get discoveryFailed => '扫描 USB 设备失败。';
  String get stoppingLive => '正在停止 WebRTC 实时推流。';
  String get stoppedLive => 'WebRTC 实时推流已停止。';
  String get stopFailed => '停止 WebRTC 实时推流失败。';
  String get startFailed => '启动 WebRTC 实时推流失败。';
  String get unhandledError => '应用捕获到未处理异常，已停止当前操作。';

  String liveStarting(LiveStreamStartPreparation preparation) {
    final cameras = preparation.selectedCameras;
    return cameras.length == 1
        ? '正在从 ${cameras.first.deviceName} 启动 WebRTC 实时推流。'
        : '正在启动 ${cameras.length} 路 WebRTC 实时推流。';
  }

  String liveStarted(LiveStreamStartResult result) {
    final startedStreamIds = result.streamIds;
    return startedStreamIds.length == 1
        ? 'WebRTC 实时推流已启动，流 ID：${startedStreamIds.single}。'
        : '已启动 ${startedStreamIds.length} 路 WebRTC 实时推流：${startedStreamIds.join(', ')}。';
  }
}

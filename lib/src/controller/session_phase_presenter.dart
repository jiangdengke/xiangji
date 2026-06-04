import '../domain.dart';

String sessionPhaseLabel(SessionPhase phase) {
  return switch (phase) {
    SessionPhase.idle => '空闲',
    SessionPhase.discovering => '扫描中',
    SessionPhase.ready => '就绪',
    SessionPhase.permissionRequested => '请求权限',
    SessionPhase.starting => '启动中',
    SessionPhase.streaming => '推流中',
    SessionPhase.stopping => '停止中',
    SessionPhase.error => '错误',
  };
}

SessionPhase readyOrIdlePhase({required bool hasUsbDevices}) {
  return hasUsbDevices ? SessionPhase.ready : SessionPhase.idle;
}

bool isActiveSessionPhase(SessionPhase phase) {
  return phase == SessionPhase.starting ||
      phase == SessionPhase.streaming ||
      phase == SessionPhase.stopping;
}

import '../domain.dart';
import 'stream_dashboard_flow_types.dart';

StreamDashboardFlowStep buildLiveFlowStep(
  StreamDashboardFlowSnapshot snapshot,
) {
  return StreamDashboardFlowStep(
    kind: StreamDashboardFlowStepKind.live,
    label: 'WebRTC',
    value: _liveValue(snapshot),
    state: _liveState(snapshot),
  );
}

String _liveValue(StreamDashboardFlowSnapshot snapshot) {
  if (!snapshot.isEndpointValid) {
    return '地址无效';
  }
  if (snapshot.phase == SessionPhase.starting) {
    return '连接中';
  }
  if (snapshot.phase == SessionPhase.streaming) {
    return '在线';
  }
  if (snapshot.phase == SessionPhase.stopping) {
    return '停止中';
  }
  return '等待中';
}

StreamDashboardFlowState _liveState(StreamDashboardFlowSnapshot snapshot) {
  if (!snapshot.isEndpointValid || snapshot.phase == SessionPhase.error) {
    return StreamDashboardFlowState.error;
  }
  if (snapshot.phase == SessionPhase.starting ||
      snapshot.phase == SessionPhase.streaming ||
      snapshot.phase == SessionPhase.stopping) {
    return StreamDashboardFlowState.active;
  }
  if (snapshot.hasSelectedVideoCamera) {
    return StreamDashboardFlowState.idle;
  }
  return StreamDashboardFlowState.blocked;
}

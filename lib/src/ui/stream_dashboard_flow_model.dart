import 'stream_dashboard_flow_step_rules.dart';
import 'stream_dashboard_flow_types.dart';

class StreamDashboardFlowPresenter {
  const StreamDashboardFlowPresenter(this.snapshot);

  final StreamDashboardFlowSnapshot snapshot;

  List<StreamDashboardFlowStep> buildSteps() {
    return <StreamDashboardFlowStep>[
      buildUsbFlowStep(snapshot),
      buildPermissionFlowStep(snapshot),
      buildVideoFlowStep(snapshot),
      buildLiveFlowStep(snapshot),
    ];
  }
}

import 'package:flutter/material.dart';

import 'src/app.dart';
import 'src/bridge/camera_bridge.dart';
import 'src/controller/xiangji_session_controller.dart';
import 'src/platform/camera_bridge_factory.dart';
import 'src/upload/http_segment_uploader.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final CameraBridge bridge = createCameraBridge();
  final controller = XiangjiSessionController(
    bridge: bridge,
    uploader: HttpSegmentUploader(),
  );

  await controller.initialize();
  runApp(XiangjiApp(controller: controller));
}

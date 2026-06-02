import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'src/app.dart';
import 'src/bridge/camera_bridge.dart';
import 'src/controller/xiangji_session_controller.dart';
import 'src/live/whip_web_rtc_publisher.dart';
import 'src/platform/camera_bridge_factory.dart';
import 'src/upload/http_segment_uploader.dart';

Future<void> main() async {
  final app = runZonedGuarded<Future<void>>(() async {
    WidgetsFlutterBinding.ensureInitialized();

    final CameraBridge bridge = createCameraBridge();
    final controller = XiangjiSessionController(
      bridge: bridge,
      uploader: HttpSegmentUploader(),
      livePublisher: WhipWebRtcPublisher(),
    );

    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.presentError(details);
      controller.reportUnhandledError(details.exception, details.stack);
    };
    PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
      controller.reportUnhandledError(error, stack);
      return true;
    };

    await controller.initialize();
    runApp(XiangjiApp(controller: controller));
  }, (Object error, StackTrace stack) {
    debugPrint('Unhandled startup error: $error\n$stack');
  });
  await (app ?? Future<void>.value());
}

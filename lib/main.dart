import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import 'src/app.dart';
import 'src/bridge/camera_bridge.dart';
import 'src/controller/xiangji_session_controller.dart';
import 'src/live/whip_web_rtc_publisher.dart';
import 'src/platform/camera_bridge_factory.dart';

Future<void> main() {
  const defaultEndpoint = String.fromEnvironment('XIANGJI_DEFAULT_ENDPOINT');
  const defaultSelectedCameraLimit = int.fromEnvironment(
    'XIANGJI_DEFAULT_SELECTED_CAMERA_LIMIT',
  );
  const webRtcNetworkIgnoreMask = String.fromEnvironment(
    'XIANGJI_WEBRTC_NETWORK_IGNORE_MASK',
  );

  return runZonedGuarded<Future<void>>(
        () async {
          WidgetsFlutterBinding.ensureInitialized();
          await _initializeWebRtc(webRtcNetworkIgnoreMask);

          final CameraBridge bridge = createCameraBridge();
          final controller = XiangjiSessionController(
            bridge: bridge,
            livePublisher: WhipWebRtcPublisher(),
            endpointText: defaultEndpoint,
          );

          FlutterError.onError = (FlutterErrorDetails details) {
            FlutterError.presentError(details);
            controller.reportUnhandledError(details.exception, details.stack);
          };
          PlatformDispatcher.instance.onError =
              (Object error, StackTrace stack) {
                controller.reportUnhandledError(error, stack);
                return true;
              };

          await controller.initialize();
          _limitDefaultSelectedCameras(controller, defaultSelectedCameraLimit);
          runApp(XiangjiApp(controller: controller));
        },
        (Object error, StackTrace stack) {
          debugPrint('Unhandled startup error: $error\n$stack');
        },
      ) ??
      Future<void>.value();
}

Future<void> _initializeWebRtc(String networkIgnoreMask) async {
  final ignoredAdapters = networkIgnoreMask
      .split(',')
      .map((adapter) => adapter.trim())
      .where((adapter) => adapter.isNotEmpty)
      .toList(growable: false);
  if (ignoredAdapters.isEmpty) {
    return;
  }

  await WebRTC.initialize(
    options: <String, dynamic>{'networkIgnoreMask': ignoredAdapters},
  );
}

void _limitDefaultSelectedCameras(
  XiangjiSessionController controller,
  int limit,
) {
  if (limit <= 0) {
    return;
  }

  final selectedDevices = controller.selectedVideoDevices;
  if (selectedDevices.length <= limit) {
    return;
  }

  for (final device in selectedDevices.skip(limit)) {
    controller.setDeviceSelected(device.deviceId, false);
  }
}

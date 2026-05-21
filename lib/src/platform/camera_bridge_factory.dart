import 'package:flutter/foundation.dart';

import '../bridge/camera_bridge.dart';
import '../bridge/method_channel_camera_bridge.dart';
import '../bridge/mock_camera_bridge.dart';

CameraBridge createCameraBridge() {
  if (defaultTargetPlatform == TargetPlatform.android) {
    return MethodChannelCameraBridge();
  }
  return MockCameraBridge();
}

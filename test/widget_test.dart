import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:xiangji/src/app.dart';
import 'package:xiangji/src/bridge/mock_camera_bridge.dart';
import 'package:xiangji/src/controller/xiangji_session_controller.dart';
import 'package:xiangji/src/domain.dart';
import 'package:xiangji/src/upload/segment_uploader.dart';

void main() {
  testWidgets('dashboard renders the main controls', (
    WidgetTester tester,
  ) async {
    final controller = XiangjiSessionController(
      bridge: MockCameraBridge(),
      uploader: _NoopUploader(),
    );
    await controller.initialize();

    await tester.pumpWidget(XiangjiApp(controller: controller));
    await tester.pumpAndSettle();

    expect(find.text('Xiangji Stream'), findsOneWidget);
    expect(find.text('Controls'), findsOneWidget);
    expect(find.text('Upload target'), findsOneWidget);
    expect(find.text('Fallback'), findsOneWidget);

    await tester.drag(
      find.byKey(const Key('dashboard_scroll')),
      const Offset(0, -700),
    );
    await tester.pumpAndSettle();

    expect(find.text('USB devices'), findsOneWidget);
    expect(find.text('Mock UVC Camera'), findsOneWidget);
  });
}

class _NoopUploader implements SegmentUploader {
  @override
  Future<UploadReceipt> uploadSegment({
    required CameraSegment segment,
    required UploadTarget target,
  }) async {
    return UploadReceipt(
      endpoint: target.endpoint,
      statusCode: 200,
      bytesSent: segment.byteLength,
      responseBody: 'ok',
    );
  }

  @override
  Future<void> dispose() async {}
}

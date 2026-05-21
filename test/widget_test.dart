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

    expect(find.text('巡摄'), findsOneWidget);
    expect(find.text('回退'), findsOneWidget);
    expect(find.text('摄像头'), findsWidgets);

    await tester.scrollUntilVisible(
      find.text('控制'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(find.text('控制'), findsOneWidget);
    expect(find.text('全选'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('上传地址'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(find.text('上传地址'), findsOneWidget);
    expect(find.text('USB 设备'), findsWidgets);

    await tester.scrollUntilVisible(
      find.text('模拟 UVC 摄像头 1'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(find.text('模拟 UVC 摄像头 1'), findsOneWidget);
    expect(find.text('模拟 UVC 摄像头 2'), findsOneWidget);
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

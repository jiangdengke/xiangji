import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:xiangji/src/live/live_stream_publisher.dart';
import 'package:xiangji/src/live/whip_web_rtc_publisher.dart';
import 'package:xiangji/src/live/whip_web_rtc_session.dart';

void main() {
  test('media constraints use flutter_webrtc Android-compatible values', () {
    final constraints = buildWhipMediaConstraints(
      LiveStreamConfig(
        endpoint: Uri.parse('http://127.0.0.1:9090/offer/camera1'),
        streamId: 'camera1',
        deviceId: 'camera2:7',
        width: 640,
        height: 480,
        frameRate: 15,
      ),
    );

    final video = constraints['video'] as Map<String, dynamic>;
    expect(video['deviceId'], '7');
    expect(video['width'], 640);
    expect(video['height'], 480);
    expect(video['frameRate'], 15);
  });

  test(
    'WebRTC publisher reports unreachable endpoint before media capture',
    () async {
      final publisher = WhipWebRtcPublisher(
        preflightTimeout: const Duration(milliseconds: 10),
        endpointProbe: (Uri endpoint, Duration timeout) async {
          throw const SocketException('Connection refused');
        },
      );
      final statuses = <LivePublisherStatus>[];
      final subscription = publisher.statuses.listen(statuses.add);

      await expectLater(
        publisher.start(
          LiveStreamConfig(
            endpoint: Uri.parse('http://127.0.0.1:65535/offer/camera1'),
            streamId: 'camera1',
          ),
        ),
        throwsA(isA<WhipSignalingException>()),
      );
      await Future<void>.delayed(Duration.zero);

      expect(
        statuses.map((status) => status.message),
        contains(contains('WebRTC 实时推流启动失败。')),
      );
      expect(
        statuses.map((status) => status.details.toString()),
        contains(contains('无法连接 WebRTC 接收端')),
      );

      await subscription.cancel();
      await publisher.dispose();
    },
  );
}

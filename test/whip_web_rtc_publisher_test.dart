import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:xiangji/src/live/live_stream_publisher.dart';
import 'package:xiangji/src/live/whip_web_rtc_publisher.dart';

void main() {
  test('WHIP publisher reports unreachable endpoint before media capture', () async {
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
          endpoint: Uri.parse('http://127.0.0.1:65535/whip/camera-001'),
          streamId: 'camera-001',
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
      contains(contains('无法连接 WHIP 地址')),
    );

    await subscription.cancel();
    await publisher.dispose();
  });
}

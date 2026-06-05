import 'package:flutter_test/flutter_test.dart';

import 'package:xiangji/src/live/live_stream_id_policy.dart';

void main() {
  const policy = LiveStreamIdPolicy();

  test('validates ROS2 receiver camera names', () {
    expect(policy.isValid('camera1'), isTrue);
    expect(policy.isValid('  camera1  '), isTrue);
    expect(policy.isValid('camera4'), isTrue);
    expect(policy.isValid('camera5'), isFalse);
    expect(policy.isValid(''), isFalse);
    expect(policy.isValid('camera 1'), isFalse);
    expect(policy.isValid('camera\t1'), isFalse);
  });

  test('validates non-empty prefixes without whitespace', () {
    expect(policy.isPrefixValid('camera'), isTrue);
    expect(policy.isPrefixValid('  camera  '), isTrue);
    expect(policy.isPrefixValid(''), isFalse);
    expect(policy.isPrefixValid('camera prefix'), isFalse);
  });

  test('builds default stream ids for one or many devices', () {
    expect(
      policy.defaultForDevice(prefix: 'camera', index: 0, total: 1),
      'camera1',
    );
    expect(
      policy.defaultForDevice(prefix: 'camera', index: 1, total: 2),
      'camera2',
    );
    expect(
      policy.defaultForDevice(prefix: 'unit-stream', index: 0, total: 2),
      'unit-stream-01',
    );
    expect(policy.defaultForDevice(prefix: '', index: 0, total: 2), '');
  });
}

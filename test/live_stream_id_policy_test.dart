import 'package:flutter_test/flutter_test.dart';

import 'package:xiangji/src/live/live_stream_id_policy.dart';

void main() {
  const policy = LiveStreamIdPolicy();

  test('validates non-empty stream ids without whitespace', () {
    expect(policy.isValid('camera-001'), isTrue);
    expect(policy.isValid('  camera-001  '), isTrue);
    expect(policy.isValid(''), isFalse);
    expect(policy.isValid('camera 001'), isFalse);
    expect(policy.isValid('camera\t001'), isFalse);
  });

  test('builds default stream ids for one or many devices', () {
    expect(
      policy.defaultForDevice(prefix: 'camera-001', index: 0, total: 1),
      'camera-001',
    );
    expect(
      policy.defaultForDevice(prefix: 'camera-001', index: 1, total: 2),
      'camera-001-02',
    );
    expect(
      policy.defaultForDevice(prefix: '  camera-001  ', index: 0, total: 2),
      'camera-001-01',
    );
    expect(
      policy.defaultForDevice(prefix: '', index: 0, total: 2),
      '',
    );
  });
}

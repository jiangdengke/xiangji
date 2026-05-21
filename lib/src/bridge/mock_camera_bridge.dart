import 'dart:async';
import 'dart:io';

import '../domain.dart';
import 'camera_bridge.dart';

class MockCameraBridge implements CameraBridge {
  MockCameraBridge()
    : _devices = <UsbCameraDevice>[
        const UsbCameraDevice(
          deviceId: 'mock-camera-0',
          deviceName: '模拟 UVC 摄像头',
          vendorId: 0x1A2B,
          productId: 0x1001,
          permissionGranted: true,
          videoClass: true,
          interfaceCount: 1,
        ),
        const UsbCameraDevice(
          deviceId: 'mock-hub-1',
          deviceName: '模拟 USB 集线器',
          vendorId: 0x1A2B,
          productId: 0x2001,
          permissionGranted: false,
          videoClass: false,
          interfaceCount: 2,
        ),
      ],
      _eventController = StreamController<CameraBridgeEvent>.broadcast();

  final StreamController<CameraBridgeEvent> _eventController;
  final List<UsbCameraDevice> _devices;
  final List<Timer> _timers = <Timer>[];
  bool _sessionRunning = false;
  int _segmentSequence = 0;

  @override
  Stream<CameraBridgeEvent> get events => _eventController.stream;

  @override
  Future<bool> isSupported() async => false;

  @override
  Future<List<UsbCameraDevice>> listDevices() async {
    return List<UsbCameraDevice>.unmodifiable(_devices);
  }

  @override
  Future<bool> requestPermission(String deviceId) async {
    final index = _devices.indexWhere((UsbCameraDevice device) {
      return device.deviceId == deviceId;
    });
    if (index == -1) {
      _eventController.add(const CameraErrorEvent(message: '模拟桥接找不到请求的设备。'));
      return false;
    }

    if (_devices[index].permissionGranted) {
      _eventController.add(
        CameraPermissionEvent(deviceId: deviceId, granted: true),
      );
      return true;
    }

    _eventController.add(
      CameraLogEvent(level: LogLevel.info, message: '已为 $deviceId 排队模拟权限请求。'),
    );

    final timer = Timer(const Duration(milliseconds: 350), () {
      _devices[index] = _devices[index].copyWith(permissionGranted: true);
      _eventController.add(
        CameraPermissionEvent(deviceId: deviceId, granted: true),
      );
      _eventController.add(
        CameraDevicesUpdated(List<UsbCameraDevice>.unmodifiable(_devices)),
      );
    });
    _timers.add(timer);
    return false;
  }

  @override
  Future<void> startSession(CameraSessionRequest request) async {
    final device = _devices.where((UsbCameraDevice device) {
      return device.deviceId == request.deviceId;
    }).firstOrNull;

    if (device == null) {
      _eventController.add(const CameraErrorEvent(message: '模拟桥接无法在未选择设备时启动。'));
      return;
    }

    if (!device.permissionGranted) {
      _eventController.add(const CameraErrorEvent(message: '模拟桥接拒绝启动，因为缺少权限。'));
      return;
    }

    _sessionRunning = true;
    _eventController.add(
      CameraStatusEvent(phase: SessionPhase.starting, message: '模拟桥接正在启动录制。'),
    );
    _eventController.add(
      CameraLogEvent(
        level: LogLevel.info,
        message: '模拟会话已为 ${request.deviceId} 启动。',
      ),
    );
    _eventController.add(
      CameraStatusEvent(phase: SessionPhase.streaming, message: '模拟桥接正在录制。'),
    );

    for (var index = 0; index < 3; index++) {
      final timer = Timer(Duration(milliseconds: 500 * (index + 1)), () {
        if (!_sessionRunning) {
          return;
        }
        unawaited(_emitMockSegment(request));
      });
      _timers.add(timer);
    }
  }

  Future<void> _emitMockSegment(CameraSessionRequest request) async {
    final sequence = ++_segmentSequence;
    final segmentDir = await Directory.systemTemp.createTemp('xiangji_mock_');
    final segmentFile = File(
      '${segmentDir.path}/segment_${sequence.toString().padLeft(4, '0')}.mp4',
    );
    final payload = List<int>.generate(
      4096 + sequence * 128,
      (int position) => (position + sequence) % 256,
    );
    await segmentFile.writeAsBytes(payload, flush: true);

    _eventController.add(
      CameraSegmentReadyEvent(
        CameraSegment(
          segmentId: 'mock-segment-$sequence',
          deviceId: request.deviceId,
          streamId: request.streamId,
          filePath: segmentFile.path,
          sequence: sequence,
          durationMs: request.fragmentDurationMs,
          byteLength: payload.length,
          capturedAt: DateTime.now(),
        ),
      ),
    );
  }

  @override
  Future<void> stopSession() async {
    _sessionRunning = false;
    for (final timer in _timers) {
      timer.cancel();
    }
    _timers.clear();
    _eventController.add(
      const CameraStatusEvent(phase: SessionPhase.idle, message: '模拟桥接已停止。'),
    );
  }

  @override
  Future<void> dispose() async {
    for (final timer in _timers) {
      timer.cancel();
    }
    _timers.clear();
    await _eventController.close();
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull {
    if (isEmpty) {
      return null;
    }
    return first;
  }
}

import 'dart:async';

import 'package:flutter/services.dart';

import '../domain.dart';
import 'camera_bridge.dart';
import 'camera_bridge_event_mapper.dart';

class MethodChannelCameraBridge implements CameraBridge {
  MethodChannelCameraBridge()
    : _eventController = StreamController<CameraBridgeEvent>.broadcast() {
    _eventSubscription = _eventsChannel.receiveBroadcastStream().listen(
      _handleEvent,
      onError: (Object error, StackTrace _) {
        _eventController.add(
          CameraErrorEvent(
            message: 'Native bridge event stream failed.',
            details: error,
          ),
        );
      },
    );
  }

  static const MethodChannel _methodChannel = MethodChannel(
    'xiangji/usb_camera/method',
  );
  static const EventChannel _eventsChannel = EventChannel(
    'xiangji/usb_camera/events',
  );

  final StreamController<CameraBridgeEvent> _eventController;
  final CameraBridgeEventMapper _eventMapper = const CameraBridgeEventMapper();
  late final StreamSubscription<dynamic> _eventSubscription;

  @override
  Stream<CameraBridgeEvent> get events => _eventController.stream;

  @override
  Future<bool> isSupported() async {
    try {
      return await _methodChannel.invokeMethod<bool>('isSupported') ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  @override
  Future<List<UsbCameraDevice>> listDevices() async {
    try {
      final Object? raw = await _methodChannel.invokeMethod<Object?>(
        'listDevices',
      );
      if (raw is! List) {
        return <UsbCameraDevice>[];
      }

      return raw
          .whereType<Map<Object?, Object?>>()
          .map(UsbCameraDevice.fromMap)
          .toList(growable: false);
    } on MissingPluginException {
      return <UsbCameraDevice>[];
    } on PlatformException {
      return <UsbCameraDevice>[];
    }
  }

  @override
  Future<bool> requestPermission(String deviceId) async {
    try {
      return await _methodChannel.invokeMethod<bool>(
            'requestPermission',
            <String, Object?>{'deviceId': deviceId},
          ) ??
          false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  void _handleEvent(dynamic raw) {
    final event = _eventMapper.map(raw);
    if (event != null) {
      _eventController.add(event);
    }
  }

  @override
  Future<void> dispose() async {
    await _eventSubscription.cancel();
    await _eventController.close();
  }
}

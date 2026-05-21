import 'dart:async';

import 'package:flutter/services.dart';

import '../domain.dart';
import 'camera_bridge.dart';

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

  @override
  Future<void> startSession(CameraSessionRequest request) async {
    try {
      await _methodChannel.invokeMethod<void>('startSession', request.toMap());
    } on MissingPluginException {
      return;
    }
  }

  @override
  Future<void> stopSession() async {
    try {
      await _methodChannel.invokeMethod<void>('stopSession');
    } on MissingPluginException {
      return;
    }
  }

  void _handleEvent(dynamic raw) {
    if (raw is! Map) {
      return;
    }

    final map = Map<Object?, Object?>.from(raw);
    final type = map['type']?.toString();

    switch (type) {
      case 'devices':
        final devices = (map['devices'] as List? ?? const <Object?>[])
            .whereType<Map<Object?, Object?>>()
            .map(UsbCameraDevice.fromMap)
            .toList(growable: false);
        _eventController.add(CameraDevicesUpdated(devices));
        break;
      case 'status':
        _eventController.add(
          CameraStatusEvent(
            phase: _parsePhase(map['phase']?.toString()),
            message: map['message']?.toString() ?? '',
          ),
        );
        break;
      case 'segment':
        final segmentMap = map['segment'];
        if (segmentMap is Map<Object?, Object?>) {
          _eventController.add(
            CameraSegmentReadyEvent(CameraSegment.fromMap(segmentMap)),
          );
        }
        break;
      case 'permission':
        _eventController.add(
          CameraPermissionEvent(
            deviceId: map['deviceId']?.toString() ?? '',
            granted: map['granted']?.toString() == 'true',
          ),
        );
        break;
      case 'log':
        _eventController.add(
          CameraLogEvent(
            level: _parseLevel(map['level']?.toString()),
            message: map['message']?.toString() ?? '',
          ),
        );
        break;
      case 'error':
        _eventController.add(
          CameraErrorEvent(
            message: map['message']?.toString() ?? 'Unknown native error.',
            details: map['details'],
          ),
        );
        break;
      default:
        break;
    }
  }

  SessionPhase _parsePhase(String? value) {
    switch (value) {
      case 'discovering':
        return SessionPhase.discovering;
      case 'ready':
        return SessionPhase.ready;
      case 'permissionRequested':
        return SessionPhase.permissionRequested;
      case 'starting':
        return SessionPhase.starting;
      case 'streaming':
        return SessionPhase.streaming;
      case 'stopping':
        return SessionPhase.stopping;
      case 'error':
        return SessionPhase.error;
      case 'idle':
      default:
        return SessionPhase.idle;
    }
  }

  LogLevel _parseLevel(String? value) {
    switch (value) {
      case 'debug':
        return LogLevel.debug;
      case 'warning':
        return LogLevel.warning;
      case 'error':
        return LogLevel.error;
      case 'info':
      default:
        return LogLevel.info;
    }
  }

  @override
  Future<void> dispose() async {
    await _eventSubscription.cancel();
    await _eventController.close();
  }
}

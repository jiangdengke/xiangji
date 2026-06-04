import 'package:flutter/foundation.dart';

import '../bridge/camera_bridge.dart';
import '../domain.dart';
import '../live/live_stream_routing.dart';
import 'session_log_sink.dart';
import 'session_runtime_state.dart';
import 'usb_device_inventory_presenter.dart';
import 'usb_device_registry.dart';

class SessionDiscoveryCoordinator {
  SessionDiscoveryCoordinator({
    required CameraBridge bridge,
    required SessionRuntimeState state,
    required UsbDeviceRegistry deviceRegistry,
    required LiveStreamRouting routing,
    required UsbDeviceInventoryPresenter inventoryPresenter,
    required void Function() maybeStartAfterPermission,
    required void Function() notifyListeners,
    required SessionLogSink logSink,
  }) : _bridge = bridge,
       _state = state,
       _deviceRegistry = deviceRegistry,
       _routing = routing,
       _inventoryPresenter = inventoryPresenter,
       _maybeStartAfterPermission = maybeStartAfterPermission,
       _notifyListeners = notifyListeners,
       _logSink = logSink;

  final CameraBridge _bridge;
  final SessionRuntimeState _state;
  final UsbDeviceRegistry _deviceRegistry;
  final LiveStreamRouting _routing;
  final UsbDeviceInventoryPresenter _inventoryPresenter;
  final void Function() _maybeStartAfterPermission;
  final void Function() _notifyListeners;
  final SessionLogSink _logSink;

  Future<void> initialize() async {
    _state.bridgeSupported = await _bridge.isSupported();
    _logSink(
      _state.bridgeSupported
          ? '已检测到 Android 原生 USB 桥接。'
          : '未检测到 Android 原生 USB 桥接，当前使用模拟桥接。',
      LogLevel.info,
      null,
      true,
      LogTopic.system,
    );
    await refreshDevices();
  }

  Future<void> refreshDevices() async {
    if (_state.disposed) {
      return;
    }

    if (_state.phase == SessionPhase.idle ||
        _state.phase == SessionPhase.ready) {
      _state.beginDiscovery();
      _logSink('正在扫描 USB 设备。', LogLevel.info, null, true, LogTopic.device);
      _notifyListeners();
    }

    try {
      final devices = await _bridge.listDevices();
      replaceDevices(devices);
      final inventoryMessage = _inventoryPresenter.messageFor(
        _deviceRegistry.devices,
      );
      _state.completeDiscovery(
        hasUsbDevices: _deviceRegistry.hasUsbDevices,
        inventoryMessage: inventoryMessage,
      );
      _logSink(inventoryMessage, LogLevel.info, null, true, LogTopic.device);
      _notifyListeners();
      _maybeStartAfterPermission();
    } catch (error, stackTrace) {
      _state.failDiscovery(error);
      _logSink(
        '设备扫描失败：$error',
        LogLevel.error,
        stackTrace,
        true,
        LogTopic.device,
      );
      _notifyListeners();
      debugPrint(stackTrace.toString());
    }
  }

  void replaceDevices(List<UsbCameraDevice> devices) {
    _deviceRegistry.replaceDevices(devices);
    _routing.syncDevices(_deviceRegistry.devices);
  }
}

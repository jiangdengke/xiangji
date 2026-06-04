import 'package:flutter/foundation.dart';

import '../bridge/camera_bridge.dart';
import '../live/live_stream_publisher.dart';
import '../live/live_stream_routing.dart';
import '../live/live_stream_session_coordinator.dart';
import 'camera_permission_coordinator.dart';
import 'session_bridge_event_handler.dart';
import 'session_controller_actions.dart';
import 'session_controller_lifecycle.dart';
import 'session_controller_logger.dart';
import 'session_controller_view.dart';
import 'session_device_actions.dart';
import 'session_discovery_coordinator.dart';
import 'session_event_handlers.dart';
import 'session_live_status_handler.dart';
import 'session_live_orchestrator.dart';
import 'session_permission_flow.dart';
import 'session_runtime_state.dart';
import 'usb_device_inventory_presenter.dart';
import 'usb_device_registry.dart';

class SessionControllerComposition {
  SessionControllerComposition({
    required CameraBridge bridge,
    required LiveStreamPublisher livePublisher,
    required VoidCallback notifyListeners,
    String endpointText = '',
    String streamIdText = 'camera-001',
  }) : _notifyListeners = notifyListeners,
       _logger = SessionControllerLogger(notifyListeners: notifyListeners),
       _routing = LiveStreamRouting(
         endpointText: endpointText,
         streamIdPrefix: streamIdText,
       ),
       _state = SessionRuntimeState() {
    view = SessionControllerView(
      state: _state,
      deviceRegistry: _deviceRegistry,
      routing: _routing,
      logBuffer: _logger.buffer,
    );
    _liveSessionCoordinator = LiveStreamSessionCoordinator(
      publisher: livePublisher,
      routing: _routing,
    );
    _permissionCoordinator = CameraPermissionCoordinator(bridge: bridge);
    _discoveryCoordinator = SessionDiscoveryCoordinator(
      bridge: bridge,
      state: _state,
      deviceRegistry: _deviceRegistry,
      routing: _routing,
      inventoryPresenter: _inventoryPresenter,
      maybeStartAfterPermission: maybeStartAfterPermission,
      notifyListeners: _notifyListeners,
      logSink: _logger.logSessionEvent,
    );
    _permissionFlow = SessionPermissionFlow(
      state: _state,
      permissionCoordinator: _permissionCoordinator,
      selectedVideoDevices: () => _deviceRegistry.selectedVideoDevices,
      refreshDevices: refreshDevices,
      maybeStartAfterPermission: maybeStartAfterPermission,
      notifyListeners: _notifyListeners,
      logSink: _logger.logSessionEvent,
    );
    _deviceActions = SessionDeviceActions(
      deviceRegistry: _deviceRegistry,
      routing: _routing,
      maybeStartAfterPermission: maybeStartAfterPermission,
      notifyListeners: _notifyListeners,
      logSink: _logger.logSessionEvent,
    );
    _liveOrchestrator = SessionLiveOrchestrator(
      state: _state,
      liveSessionCoordinator: _liveSessionCoordinator,
      livePublisher: livePublisher,
      selectedVideoDevices: () => _deviceRegistry.selectedVideoDevices,
      hasUsbDevices: () => _deviceRegistry.hasUsbDevices,
      requestPermission: requestPermission,
      notifyListeners: _notifyListeners,
      logSink: _logger.logSessionEvent,
    );
    _actions = SessionControllerActions(
      state: _state,
      deviceRegistry: _deviceRegistry,
      deviceActions: _deviceActions,
      permissionFlow: _permissionFlow,
      liveOrchestrator: _liveOrchestrator,
      logSink: _logger.logSessionEvent,
    );
    _eventHandlers = SessionEventHandlers(
      bridgeHandler: SessionBridgeEventHandler(
        state: _state,
        deviceRegistry: _deviceRegistry,
        routing: _routing,
        inventoryPresenter: _inventoryPresenter,
        refreshDevices: refreshDevices,
        maybeStartAfterPermission: maybeStartAfterPermission,
        isDeviceSelected: _deviceRegistry.isDeviceSelected,
        notifyListeners: _notifyListeners,
        logSink: _logger.logSessionEvent,
      ),
      liveStatusHandler: SessionLiveStatusHandler(
        state: _state,
        hasUsbDevices: () => _deviceRegistry.hasUsbDevices,
        notifyListeners: _notifyListeners,
        logSink: _logger.logSessionEvent,
      ),
    );
    _lifecycle = SessionControllerLifecycle(
      bridge: bridge,
      livePublisher: livePublisher,
      state: _state,
      eventHandlers: _eventHandlers,
    );
  }

  final VoidCallback _notifyListeners;
  final SessionControllerLogger _logger;
  final SessionRuntimeState _state;
  final LiveStreamRouting _routing;
  final UsbDeviceRegistry _deviceRegistry = UsbDeviceRegistry();
  final UsbDeviceInventoryPresenter _inventoryPresenter =
      const UsbDeviceInventoryPresenter();

  late final SessionControllerView view;
  late final LiveStreamSessionCoordinator _liveSessionCoordinator;
  late final CameraPermissionCoordinator _permissionCoordinator;
  late final SessionDiscoveryCoordinator _discoveryCoordinator;
  late final SessionPermissionFlow _permissionFlow;
  late final SessionDeviceActions _deviceActions;
  late final SessionLiveOrchestrator _liveOrchestrator;
  late final SessionControllerActions _actions;
  late final SessionEventHandlers _eventHandlers;
  late final SessionControllerLifecycle _lifecycle;

  Future<void> initialize() => _discoveryCoordinator.initialize();

  Future<void> refreshDevices() => _discoveryCoordinator.refreshDevices();

  void selectDevice(String deviceId) {
    _actions.selectDevice(deviceId);
  }

  void toggleDeviceSelection(String deviceId) {
    _actions.toggleDeviceSelection(deviceId);
  }

  void setDeviceSelected(String deviceId, bool selected) {
    _actions.setDeviceSelected(deviceId, selected);
  }

  void selectAllVideoDevices() {
    _actions.selectAllVideoDevices();
  }

  void clearSelectedDevices() {
    _actions.clearSelectedDevices();
  }

  void updateEndpointText(String value) {
    _actions.updateEndpointText(value);
  }

  void updateStreamIdText(String value) {
    _actions.updateStreamIdText(value);
  }

  void updateDeviceStreamIdText(String deviceId, String value) {
    _actions.updateDeviceStreamIdText(deviceId, value);
  }

  void resetDeviceStreamId(String deviceId) {
    _actions.resetDeviceStreamId(deviceId);
  }

  Future<void> requestPermission() => _actions.requestPermission();

  Future<void> start() => _actions.start();

  Future<void> stop() => _actions.stop();

  void reportUnhandledError(Object error, StackTrace? stackTrace) {
    _actions.reportUnhandledError(error, stackTrace);
  }

  void maybeStartAfterPermission() {
    _actions.maybeStartAfterPermission();
  }

  void dispose() {
    _lifecycle.dispose();
  }
}

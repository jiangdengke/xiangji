import 'dart:async';
import 'dart:collection';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../bridge/camera_bridge.dart';
import '../domain.dart';
import '../live/live_stream_publisher.dart';
import '../upload/segment_uploader.dart';

class XiangjiSessionController extends ChangeNotifier {
  XiangjiSessionController({
    required CameraBridge bridge,
    required SegmentUploader uploader,
    required LiveStreamPublisher livePublisher,
    String endpointText = '',
    String streamIdText = 'camera-001',
    String fragmentDurationText = '2000',
  }) : _bridge = bridge,
       _uploader = uploader,
       _livePublisher = livePublisher,
       _endpointText = endpointText,
       _streamIdText = streamIdText,
       _fragmentDurationText = fragmentDurationText {
    _subscription = _bridge.events.listen(_handleBridgeEvent);
    _liveSubscription = _livePublisher.statuses.listen(_handleLiveStatus);
  }

  final CameraBridge _bridge;
  final SegmentUploader _uploader;
  final LiveStreamPublisher _livePublisher;
  late final StreamSubscription<CameraBridgeEvent> _subscription;
  late final StreamSubscription<LivePublisherStatus> _liveSubscription;

  final Queue<_QueuedSegment> _pendingSegments = Queue<_QueuedSegment>();
  final List<StreamLogEntry> _logs = <StreamLogEntry>[];

  Timer? _retryTimer;
  bool _bridgeSupported = false;
  bool _drainingUploads = false;
  bool _pendingStartAfterPermission = false;
  bool _sessionActive = false;
  bool _liveActive = false;
  bool _disposed = false;
  SessionPhase _phase = SessionPhase.idle;
  String _statusMessage = '等待 USB 摄像头。';
  String _lastError = '';
  List<UsbCameraDevice> _devices = <UsbCameraDevice>[];
  final Set<String> _selectedDeviceIds = <String>{};
  bool _selectionInitialized = false;
  int _uploadedSegments = 0;
  int _failedSegments = 0;
  int _pendingUploadCount = 0;
  DateTime? _lastSegmentAt;
  DateTime? _lastUploadAt;
  DateTime? _lastLiveEventAt;
  String _endpointText;
  String _streamIdText;
  String _fragmentDurationText;

  bool get bridgeSupported => _bridgeSupported;
  SessionPhase get phase => _phase;
  String get phaseLabel => _phaseText(_phase);
  String get statusMessage => _statusMessage;
  String get lastError => _lastError;
  List<UsbCameraDevice> get devices =>
      List<UsbCameraDevice>.unmodifiable(_devices);
  bool get hasUsbDevices => _devices.isNotEmpty;
  int get usbDeviceCount => _devices.length;
  bool get hasVideoCamera => _devices.any((UsbCameraDevice device) {
    return device.videoClass;
  });
  int get videoCameraCount => _devices.where((UsbCameraDevice device) {
    return device.videoClass;
  }).length;
  Set<String> get selectedDeviceIds =>
      Set<String>.unmodifiable(_selectedDeviceIds);
  List<UsbCameraDevice> get selectedDevices => _devices
      .where((UsbCameraDevice device) {
        return _selectedDeviceIds.contains(device.deviceId);
      })
      .toList(growable: false);
  List<UsbCameraDevice> get selectedVideoDevices => selectedDevices
      .where((UsbCameraDevice device) => device.videoClass)
      .toList(growable: false);
  int get selectedVideoCameraCount => selectedVideoDevices.length;
  bool get hasSelectedVideoCamera => selectedVideoCameraCount > 0;
  String? get selectedDeviceId =>
      _selectedDeviceIds.isEmpty ? null : _selectedDeviceIds.first;
  UsbCameraDevice? get selectedDevice =>
      selectedVideoDevices.isEmpty ? null : selectedVideoDevices.first;

  int get uploadedSegments => _uploadedSegments;
  int get failedSegments => _failedSegments;
  int get pendingUploadCount => _pendingUploadCount;
  bool get isUploading => _drainingUploads;
  bool get isLiveStreaming =>
      _liveActive && _phase == SessionPhase.streaming;
  DateTime? get lastSegmentAt => _lastSegmentAt;
  DateTime? get lastUploadAt => _lastUploadAt;
  DateTime? get lastLiveEventAt => _lastLiveEventAt;
  List<StreamLogEntry> get logs => List<StreamLogEntry>.unmodifiable(_logs);
  List<StreamLogEntry> get recentLogs =>
      List<StreamLogEntry>.unmodifiable(_logs.reversed);
  StreamLogEntry? get latestLog => _logs.isEmpty ? null : _logs.last;
  String get endpointText => _endpointText;
  String get streamIdText => _streamIdText;
  String get fragmentDurationText => _fragmentDurationText;

  bool get isEndpointValid {
    final uri = Uri.tryParse(_endpointText);
    return uri != null &&
        uri.hasScheme &&
        (uri.isScheme('http') || uri.isScheme('https'));
  }

  bool get isStreamIdValid {
    final value = _streamIdText.trim();
    return value.isNotEmpty && !value.contains(RegExp(r'\s'));
  }

  bool get canStart {
    return hasSelectedVideoCamera &&
        !_sessionActive &&
        phase != SessionPhase.starting &&
        phase != SessionPhase.streaming &&
        phase != SessionPhase.stopping &&
        isEndpointValid &&
        isStreamIdValid;
  }

  bool get canStop {
    return _sessionActive ||
        phase == SessionPhase.streaming ||
        phase == SessionPhase.starting;
  }

  Future<void> initialize() async {
    _bridgeSupported = await _bridge.isSupported();
    _appendLog(
      _bridgeSupported
          ? '已检测到 Android 原生 USB 桥接。'
          : '未检测到 Android 原生 USB 桥接，当前使用模拟桥接。',
      LogLevel.info,
      topic: LogTopic.system,
    );
    await refreshDevices();
  }

  Future<void> refreshDevices() async {
    if (_disposed) {
      return;
    }

    if (_phase == SessionPhase.idle || _phase == SessionPhase.ready) {
      _phase = SessionPhase.discovering;
      _statusMessage = '正在扫描 USB 设备。';
      _appendLog('正在扫描 USB 设备。', LogLevel.info, topic: LogTopic.device);
      notifyListeners();
    }

    try {
      final devices = await _bridge.listDevices();
      _replaceDevices(devices);
      final inventoryMessage = _inventoryMessage();
      if (_phase == SessionPhase.discovering) {
        _phase = _devices.isEmpty ? SessionPhase.idle : SessionPhase.ready;
        _statusMessage = inventoryMessage;
      }
      if (_phase == SessionPhase.permissionRequested && _devices.isNotEmpty) {
        _phase = SessionPhase.ready;
        _statusMessage = 'USB 权限已就绪。';
      }
      _appendLog(inventoryMessage, LogLevel.info, topic: LogTopic.device);
      _lastError = '';
      notifyListeners();
      _maybeStartAfterPermission();
    } catch (error, stackTrace) {
      _phase = SessionPhase.error;
      _lastError = error.toString();
      _statusMessage = '扫描 USB 设备失败。';
      _appendLog(
        '设备扫描失败：$error',
        LogLevel.error,
        topic: LogTopic.device,
        details: stackTrace,
      );
      notifyListeners();
    }
  }

  bool isDeviceSelected(String deviceId) {
    return _selectedDeviceIds.contains(deviceId);
  }

  void selectDevice(String deviceId) {
    setDeviceSelected(deviceId, true);
  }

  void toggleDeviceSelection(String deviceId) {
    setDeviceSelected(deviceId, !_selectedDeviceIds.contains(deviceId));
  }

  void setDeviceSelected(String deviceId, bool selected) {
    final device = _deviceById(deviceId);
    if (device == null) {
      _appendLog(
        '找不到要选择的 USB 设备：$deviceId。',
        LogLevel.warning,
        topic: LogTopic.device,
      );
      return;
    }
    if (!device.videoClass) {
      _appendLog(
        '${device.deviceName} 不是视频摄像头，不能加入推流列表。',
        LogLevel.warning,
        topic: LogTopic.device,
      );
      return;
    }

    _selectionInitialized = true;
    final changed = selected
        ? _selectedDeviceIds.add(deviceId)
        : _selectedDeviceIds.remove(deviceId);
    if (!changed) {
      return;
    }

    _appendLog(
      selected ? '已选择 ${device.deviceName}。' : '已取消选择 ${device.deviceName}。',
      LogLevel.info,
      topic: LogTopic.device,
    );
    notifyListeners();
    _maybeStartAfterPermission();
  }

  void selectAllVideoDevices() {
    final videoDeviceIds = _devices
        .where((UsbCameraDevice device) => device.videoClass)
        .map((UsbCameraDevice device) => device.deviceId)
        .toSet();
    _selectionInitialized = true;
    _selectedDeviceIds
      ..clear()
      ..addAll(videoDeviceIds);
    _appendLog(
      videoDeviceIds.isEmpty
          ? '没有可选的视频摄像头。'
          : '已选择全部 ${videoDeviceIds.length} 个视频摄像头。',
      videoDeviceIds.isEmpty ? LogLevel.warning : LogLevel.info,
      topic: LogTopic.device,
    );
    notifyListeners();
    _maybeStartAfterPermission();
  }

  void clearSelectedDevices() {
    if (_selectedDeviceIds.isEmpty) {
      return;
    }
    _selectionInitialized = true;
    _selectedDeviceIds.clear();
    _appendLog('已清空摄像头选择。', LogLevel.info, topic: LogTopic.device);
    notifyListeners();
  }

  void updateEndpointText(String value) {
    _endpointText = value.trim();
    notifyListeners();
    unawaited(_drainPendingSegments());
  }

  void updateStreamIdText(String value) {
    _streamIdText = value.trim();
    notifyListeners();
  }

  void updateFragmentDurationText(String value) {
    _fragmentDurationText = value.trim().isEmpty ? '2000' : value.trim();
    notifyListeners();
  }

  Future<void> requestPermission() async {
    final selectedCameras = selectedVideoDevices;
    if (selectedCameras.isEmpty) {
      _appendLog(
        '还没有选择要推流的 USB 摄像头。',
        LogLevel.warning,
        topic: LogTopic.permission,
      );
      return;
    }

    final pendingDevices = selectedCameras
        .where((UsbCameraDevice device) => !device.permissionGranted)
        .toList(growable: false);
    if (pendingDevices.isEmpty) {
      _appendLog(
        '当前选中的 ${selectedCameras.length} 路摄像头都已授权。',
        LogLevel.info,
        topic: LogTopic.permission,
      );
      return;
    }

    _phase = SessionPhase.permissionRequested;
    _statusMessage = '正在请求 ${pendingDevices.length} 路摄像头的 USB 权限。';
    notifyListeners();

    for (final device in pendingDevices) {
      final granted = await _bridge.requestPermission(device.deviceId);
      _appendLog(
        granted
            ? '${device.deviceName} 已授权。'
            : '已发送 ${device.deviceName} 的权限请求。',
        LogLevel.info,
        topic: LogTopic.permission,
      );
    }

    await refreshDevices();
    _maybeStartAfterPermission();
    notifyListeners();
  }

  Future<void> start() async {
    if (_disposed) {
      return;
    }

    try {
      await _startLive();
    } catch (error, stackTrace) {
      _handleStartFailure(error, stackTrace);
    }
  }

  Future<void> _startLive() async {
    final selectedCameras = selectedVideoDevices;
    if (selectedCameras.isEmpty) {
      _appendLog(
        '开始前请先选择至少一个 USB 摄像头。',
        LogLevel.warning,
        topic: LogTopic.device,
      );
      return;
    }

    if (!isStreamIdValid) {
      _appendLog(
        '流 ID 不能为空，也不能包含空白字符。',
        LogLevel.warning,
        topic: LogTopic.session,
      );
      return;
    }

    final endpoint = _buildLiveEndpoint();
    if (endpoint == null) {
      _appendLog(
        '请输入有效的 HTTP 或 HTTPS WebRTC 推流地址。',
        LogLevel.warning,
        topic: LogTopic.session,
      );
      return;
    }

    final unauthorizedDevices = selectedCameras
        .where((UsbCameraDevice device) => !device.permissionGranted)
        .toList(growable: false);
    if (unauthorizedDevices.isNotEmpty) {
      _pendingStartAfterPermission = true;
      _appendLog(
        '有 ${unauthorizedDevices.length} 路摄像头还没有 USB 权限，先请求权限。',
        LogLevel.warning,
        topic: LogTopic.permission,
      );
      await requestPermission();
      return;
    }

    _pendingStartAfterPermission = false;
    final camera = selectedCameras.first;
    final streamId = _streamIdForDevice(index: 0, total: 1);
    _phase = SessionPhase.starting;
    _statusMessage = '正在从 ${camera.deviceName} 启动 WebRTC 实时推流。';
    notifyListeners();

    if (selectedCameras.length > 1) {
      _appendLog(
        '实时预览当前先推一路，使用 ${camera.deviceName}。',
        LogLevel.info,
        topic: LogTopic.session,
      );
    }
    await _livePublisher.start(
      LiveStreamConfig(
        endpoint: endpoint,
        streamId: streamId,
        cameraName: camera.deviceName,
      ),
    );
    _sessionActive = true;
    _liveActive = true;
    _lastLiveEventAt = DateTime.now();
    _phase = SessionPhase.streaming;
    _statusMessage = 'WebRTC 实时推流已启动，流 ID：$streamId。';
    _appendLog(
      '已向 WHIP 服务端推送 WebRTC offer，流 ID：$streamId。',
      LogLevel.info,
      topic: LogTopic.session,
    );
    notifyListeners();
  }

  Future<void> stop() async {
    _pendingStartAfterPermission = false;
    _phase = SessionPhase.stopping;
    _statusMessage = '正在停止 WebRTC 实时推流。';
    notifyListeners();

    try {
      await _livePublisher.stop();
      _liveActive = false;
      _sessionActive = false;
      _phase = _devices.isEmpty ? SessionPhase.idle : SessionPhase.ready;
      _statusMessage = 'WebRTC 实时推流已停止。';
      _appendLog('WebRTC 实时推流已停止。', LogLevel.info, topic: LogTopic.session);
      notifyListeners();
    } catch (error, stackTrace) {
      _phase = SessionPhase.error;
      _statusMessage = '停止 WebRTC 实时推流失败。';
      _lastError = error.toString();
      _appendLog(
        '停止失败：$error',
        LogLevel.error,
        topic: LogTopic.session,
        details: stackTrace,
      );
      notifyListeners();
    }
  }

  Future<void> retryPendingUploads() async {
    await _drainPendingSegments(force: true);
  }

  void reportUnhandledError(Object error, StackTrace? stackTrace) {
    if (_disposed) {
      return;
    }

    _phase = SessionPhase.error;
    _sessionActive = false;
    _liveActive = false;
    _statusMessage = '应用捕获到未处理异常，已停止当前操作。';
    _lastError = error.toString();
    _appendLog(
      '捕获到未处理异常：$error',
      LogLevel.error,
      topic: LogTopic.error,
      details: stackTrace,
    );
  }

  Future<void> _handleBridgeEvent(CameraBridgeEvent event) async {
    switch (event) {
      case CameraDevicesUpdated(:final devices):
        _replaceDevices(devices);
        _appendLog(_inventoryMessage(), LogLevel.info, topic: LogTopic.device);
        notifyListeners();
        break;
      case CameraStatusEvent(:final phase, :final message):
        if (_liveActive &&
            (phase == SessionPhase.ready || phase == SessionPhase.idle)) {
          _appendLog(
            message.isEmpty ? '设备状态已刷新。' : message,
            LogLevel.info,
            topic: LogTopic.device,
          );
          notifyListeners();
          break;
        }
        if (phase == SessionPhase.streaming || phase == SessionPhase.starting) {
          _sessionActive = true;
        }
        if (phase == SessionPhase.idle) {
          _sessionActive = false;
        }
        _phase = phase;
        _statusMessage = message;
        if (phase != SessionPhase.error) {
          _lastError = '';
        }
        _appendLog(
          message.isEmpty ? '会话阶段已切换到 ${_phaseText(phase)}。' : message,
          phase == SessionPhase.error ? LogLevel.error : LogLevel.info,
          topic: phase == SessionPhase.error
              ? LogTopic.error
              : LogTopic.session,
        );
        notifyListeners();
        break;
      case CameraSegmentReadyEvent(:final segment):
        _enqueueSegment(segment);
        break;
      case CameraPermissionEvent(:final deviceId, :final granted):
        if (!granted && _selectedDeviceIds.contains(deviceId)) {
          _pendingStartAfterPermission = false;
        }
        _appendLog(
          granted ? '$deviceId 已授权。' : '$deviceId 权限被拒绝。',
          granted ? LogLevel.info : LogLevel.warning,
          topic: LogTopic.permission,
        );
        await refreshDevices();
        _maybeStartAfterPermission();
        break;
      case CameraLogEvent(:final level, :final message):
        _appendLog(message, level, topic: LogTopic.system);
        break;
      case CameraErrorEvent(:final message, :final details):
        _phase = SessionPhase.error;
        _statusMessage = message;
        _lastError = details?.toString() ?? message;
        _appendLog(
          message,
          LogLevel.error,
          topic: LogTopic.error,
          details: details,
        );
        notifyListeners();
        break;
    }
  }

  void _handleLiveStatus(LivePublisherStatus status) {
    if (_disposed) {
      return;
    }
    _lastLiveEventAt = DateTime.now();
    switch (status.phase) {
      case LivePublisherPhase.idle:
        _liveActive = false;
        _sessionActive = false;
        _phase = _devices.isEmpty ? SessionPhase.idle : SessionPhase.ready;
        break;
      case LivePublisherPhase.connecting:
        _phase = SessionPhase.starting;
        break;
      case LivePublisherPhase.streaming:
        _liveActive = true;
        _sessionActive = true;
        _phase = SessionPhase.streaming;
        _lastError = '';
        break;
      case LivePublisherPhase.stopping:
        _phase = SessionPhase.stopping;
        break;
      case LivePublisherPhase.stopped:
        _liveActive = false;
        _sessionActive = false;
        _phase = _devices.isEmpty ? SessionPhase.idle : SessionPhase.ready;
        break;
      case LivePublisherPhase.error:
        _liveActive = false;
        _sessionActive = false;
        _phase = SessionPhase.error;
        _lastError = status.details?.toString() ?? status.message;
        break;
    }
    _statusMessage = status.message;
    _appendLog(
      status.message,
      status.phase == LivePublisherPhase.error ? LogLevel.error : LogLevel.info,
      topic: LogTopic.session,
      details: status.details,
    );
    notifyListeners();
  }

  void _replaceDevices(List<UsbCameraDevice> devices) {
    _devices = List<UsbCameraDevice>.unmodifiable(devices);
    if (_devices.isEmpty) {
      _selectedDeviceIds.clear();
      return;
    }

    final selectableDeviceIds = _devices
        .where((UsbCameraDevice device) => device.videoClass)
        .map((UsbCameraDevice device) => device.deviceId)
        .toSet();
    _selectedDeviceIds.removeWhere((String deviceId) {
      return !selectableDeviceIds.contains(deviceId);
    });

    if (!_selectionInitialized) {
      final videoDeviceIds = selectableDeviceIds.toList(growable: false);
      if (videoDeviceIds.isNotEmpty) {
        _selectedDeviceIds
          ..clear()
          ..addAll(videoDeviceIds);
        _selectionInitialized = true;
      }
    }
  }

  UsbCameraDevice? _deviceById(String deviceId) {
    for (final device in _devices) {
      if (device.deviceId == deviceId) {
        return device;
      }
    }
    return null;
  }

  void _maybeStartAfterPermission() {
    if (!_pendingStartAfterPermission || _disposed) {
      return;
    }
    if (_phase == SessionPhase.starting ||
        _phase == SessionPhase.streaming ||
        _phase == SessionPhase.stopping) {
      return;
    }

    final selectedCameras = selectedVideoDevices;
    if (selectedCameras.isEmpty) {
      return;
    }
    if (selectedCameras.any((UsbCameraDevice device) {
      return !device.permissionGranted;
    })) {
      return;
    }

    _pendingStartAfterPermission = false;
    unawaited(start());
  }

  String _inventoryMessage() {
    if (_devices.isEmpty) {
      return '未检测到 USB 设备。';
    }
    if (!hasVideoCamera) {
      return '检测到 USB 设备，但没有视频摄像头。';
    }
    if (usbDeviceCount == 1 && videoCameraCount == 1) {
      return '已检测到 1 个 USB 摄像头。';
    }
    if (videoCameraCount == 1) {
      return '在 $usbDeviceCount 个 USB 设备中检测到 1 个 USB 摄像头。';
    }
    return '在 $usbDeviceCount 个 USB 设备中检测到 $videoCameraCount 个 USB 摄像头。';
  }

  String _phaseText(SessionPhase phase) {
    return switch (phase) {
      SessionPhase.idle => '空闲',
      SessionPhase.discovering => '扫描中',
      SessionPhase.ready => '就绪',
      SessionPhase.permissionRequested => '请求权限',
      SessionPhase.starting => '启动中',
      SessionPhase.streaming => '推流中',
      SessionPhase.stopping => '停止中',
      SessionPhase.error => '错误',
    };
  }

  String _streamIdForDevice({required int index, required int total}) {
    final base = _streamIdText.trim().isEmpty ? 'camera-001' : _streamIdText;
    if (total <= 1) {
      return base;
    }
    return '$base-${(index + 1).toString().padLeft(2, '0')}';
  }

  String _segmentLabel(CameraSegment segment) {
    final camera = segment.cameraId.isEmpty
        ? segment.deviceId
        : 'Camera2 ${segment.cameraId}';
    return '[${segment.streamId}][$camera]';
  }

  void _enqueueSegment(CameraSegment segment) {
    _pendingSegments.add(_QueuedSegment(segment: segment, attempts: 0));
    _pendingUploadCount = _pendingSegments.length;
    _lastSegmentAt = segment.capturedAt;
    _appendLog(
      '${_segmentLabel(segment)} 分片 ${segment.segmentId} 已加入上传队列（${segment.byteLength} 字节）。',
      LogLevel.debug,
      topic: LogTopic.upload,
    );
    notifyListeners();
    unawaited(_drainPendingSegments());
  }

  Future<void> _drainPendingSegments({bool force = false}) async {
    if (_drainingUploads || _disposed) {
      return;
    }

    final target = _buildUploadTarget();
    if (target == null) {
      if (_pendingSegments.isNotEmpty) {
        _appendLog(
          '上传队列正在等待有效的上传地址。',
          LogLevel.warning,
          topic: LogTopic.upload,
        );
      }
      return;
    }

    _retryTimer?.cancel();
    _retryTimer = null;
    _drainingUploads = true;
    notifyListeners();
    try {
      while (_pendingSegments.isNotEmpty) {
        final queued = _pendingSegments.first;
        try {
          final receipt = await _uploader.uploadSegment(
            segment: queued.segment,
            target: target,
          );
          _pendingSegments.removeFirst();
          _pendingUploadCount = _pendingSegments.length;
          _uploadedSegments += 1;
          _lastUploadAt = DateTime.now();
          _appendLog(
            '${_segmentLabel(queued.segment)} 分片 ${queued.segment.segmentId} 已上传，HTTP ${receipt.statusCode}。',
            LogLevel.info,
            topic: LogTopic.upload,
          );
          if (target.deleteAfterUpload) {
            final file = File(queued.segment.filePath);
            if (await file.exists()) {
              await file.delete();
            }
          }
          notifyListeners();
        } catch (error, stackTrace) {
          queued.attempts += 1;
          if (queued.attempts >= 3 && !force) {
            _pendingSegments.removeFirst();
            _pendingUploadCount = _pendingSegments.length;
            _failedSegments += 1;
            _appendLog(
              '${_segmentLabel(queued.segment)} 分片 ${queued.segment.segmentId} 连续 3 次上传失败，已丢弃。',
              LogLevel.error,
              topic: LogTopic.upload,
              details: error,
            );
            notifyListeners();
          } else {
            _appendLog(
              '${_segmentLabel(queued.segment)} 分片 ${queued.segment.segmentId} 上传失败，稍后重试。',
              LogLevel.warning,
              topic: LogTopic.upload,
              details: stackTrace,
            );
            _scheduleRetry();
            return;
          }
        }
      }
    } finally {
      _drainingUploads = false;
      notifyListeners();
    }
  }

  void _scheduleRetry() {
    _retryTimer?.cancel();
    _retryTimer = Timer(const Duration(seconds: 2), () {
      _retryTimer = null;
      if (!_disposed) {
        unawaited(_drainPendingSegments());
      }
    });
  }

  Uri? _buildLiveEndpoint() {
    final endpoint = Uri.tryParse(_endpointText);
    if (endpoint == null ||
        !endpoint.hasScheme ||
        (!endpoint.isScheme('http') && !endpoint.isScheme('https'))) {
      return null;
    }
    return endpoint;
  }

  UploadTarget? _buildUploadTarget() {
    final endpoint = Uri.tryParse(_endpointText);
    if (endpoint == null ||
        !endpoint.hasScheme ||
        (!endpoint.isScheme('http') && !endpoint.isScheme('https'))) {
      return null;
    }

    return UploadTarget(
      endpoint: endpoint,
      streamId: _streamIdText,
      headers: const <String, String>{},
      timeout: const Duration(seconds: 30),
      deleteAfterUpload: true,
    );
  }

  void _handleStartFailure(Object error, StackTrace stackTrace) {
    _phase = SessionPhase.error;
    _liveActive = false;
    _sessionActive = false;
    _statusMessage = '启动 WebRTC 实时推流失败。';
    _lastError = error.toString();
    _appendLog(
      '启动失败：$error',
      LogLevel.error,
      topic: LogTopic.session,
      details: stackTrace,
    );
  }

  void _appendLog(
    String message,
    LogLevel level, {
    LogTopic topic = LogTopic.system,
    Object? details,
    StackTrace? stackTrace,
    bool notify = true,
  }) {
    final detailText = _compactLogDetails(details);
    final composed = detailText == null ? message : '$message $detailText';
    _logs.add(
      StreamLogEntry(
        timestamp: DateTime.now(),
        level: level,
        topic: topic,
        message: composed,
      ),
    );
    if (_logs.length > 200) {
      _logs.removeAt(0);
    }
    if (notify) {
      notifyListeners();
    }
    if (stackTrace != null) {
      debugPrint(stackTrace.toString());
    }
  }

  String? _compactLogDetails(Object? details) {
    if (details == null) {
      return null;
    }

    final raw = details.toString();
    final firstLine = raw.split('\n').first.trim();
    if (firstLine.isEmpty) {
      return null;
    }
    if (firstLine.length <= 180) {
      return firstLine;
    }
    return '${firstLine.substring(0, 180)}...';
  }

  @override
  void dispose() {
    _disposed = true;
    _retryTimer?.cancel();
    unawaited(_subscription.cancel());
    unawaited(_liveSubscription.cancel());
    unawaited(_livePublisher.dispose());
    unawaited(_uploader.dispose());
    unawaited(_bridge.dispose());
    super.dispose();
  }
}

class _QueuedSegment {
  _QueuedSegment({required this.segment, required this.attempts});

  final CameraSegment segment;
  int attempts;
}

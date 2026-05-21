import 'dart:async';
import 'dart:collection';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../bridge/camera_bridge.dart';
import '../domain.dart';
import '../upload/segment_uploader.dart';

class XiangjiSessionController extends ChangeNotifier {
  XiangjiSessionController({
    required CameraBridge bridge,
    required SegmentUploader uploader,
    String endpointText = 'http://127.0.0.1:8080/api/camera/segments',
    String streamIdText = 'camera-001',
    String fragmentDurationText = '2000',
  }) : _bridge = bridge,
       _uploader = uploader,
       _endpointText = endpointText,
       _streamIdText = streamIdText,
       _fragmentDurationText = fragmentDurationText {
    _subscription = _bridge.events.listen(_handleBridgeEvent);
  }

  final CameraBridge _bridge;
  final SegmentUploader _uploader;
  late final StreamSubscription<CameraBridgeEvent> _subscription;

  final Queue<_QueuedSegment> _pendingSegments = Queue<_QueuedSegment>();
  final List<StreamLogEntry> _logs = <StreamLogEntry>[];

  Timer? _retryTimer;
  bool _bridgeSupported = false;
  bool _drainingUploads = false;
  bool _pendingStartAfterPermission = false;
  bool _disposed = false;
  SessionPhase _phase = SessionPhase.idle;
  String _statusMessage = 'Waiting for USB camera.';
  String _lastError = '';
  List<UsbCameraDevice> _devices = <UsbCameraDevice>[];
  String? _selectedDeviceId;
  int _uploadedSegments = 0;
  int _failedSegments = 0;
  int _pendingUploadCount = 0;
  DateTime? _lastSegmentAt;
  DateTime? _lastUploadAt;
  String _endpointText;
  String _streamIdText;
  String _fragmentDurationText;

  bool get bridgeSupported => _bridgeSupported;
  SessionPhase get phase => _phase;
  String get statusMessage => _statusMessage;
  String get lastError => _lastError;
  List<UsbCameraDevice> get devices =>
      List<UsbCameraDevice>.unmodifiable(_devices);
  String? get selectedDeviceId => _selectedDeviceId;
  UsbCameraDevice? get selectedDevice {
    final id = _selectedDeviceId;
    if (id == null) {
      return null;
    }
    for (final device in _devices) {
      if (device.deviceId == id) {
        return device;
      }
    }
    return null;
  }

  int get uploadedSegments => _uploadedSegments;
  int get failedSegments => _failedSegments;
  int get pendingUploadCount => _pendingUploadCount;
  bool get isUploading => _drainingUploads;
  DateTime? get lastSegmentAt => _lastSegmentAt;
  DateTime? get lastUploadAt => _lastUploadAt;
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

  bool get canStart {
    final device = selectedDevice;
    return device != null &&
        phase != SessionPhase.starting &&
        phase != SessionPhase.stopping &&
        !isUploading &&
        isEndpointValid;
  }

  bool get canStop {
    return phase == SessionPhase.streaming || phase == SessionPhase.starting;
  }

  Future<void> initialize() async {
    _bridgeSupported = await _bridge.isSupported();
    _appendLog(
      _bridgeSupported
          ? 'Native USB bridge detected.'
          : 'Native USB bridge unavailable. Running with fallback bridge.',
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
      _statusMessage = 'Scanning USB devices.';
      _appendLog(
        'Scanning USB devices.',
        LogLevel.info,
        topic: LogTopic.device,
      );
      notifyListeners();
    }

    try {
      final devices = await _bridge.listDevices();
      _replaceDevices(devices);
      if (_phase == SessionPhase.discovering) {
        _phase = _devices.isEmpty ? SessionPhase.idle : SessionPhase.ready;
        _statusMessage = _devices.isEmpty
            ? 'No USB camera detected.'
            : '${_devices.length} USB device(s) found.';
      }
      if (_phase == SessionPhase.permissionRequested && _devices.isNotEmpty) {
        _phase = SessionPhase.ready;
        _statusMessage = 'USB permission ready.';
      }
      _appendLog(
        _devices.isEmpty
            ? 'No USB camera detected.'
            : 'Found ${_devices.length} USB device(s).',
        LogLevel.info,
        topic: LogTopic.device,
      );
      _lastError = '';
      notifyListeners();
    } catch (error, stackTrace) {
      _phase = SessionPhase.error;
      _lastError = error.toString();
      _statusMessage = 'Failed to scan USB devices.';
      _appendLog(
        'Device scan failed: $error',
        LogLevel.error,
        topic: LogTopic.device,
        details: stackTrace,
      );
      notifyListeners();
    }
  }

  void selectDevice(String deviceId) {
    if (_selectedDeviceId == deviceId) {
      return;
    }
    _selectedDeviceId = deviceId;
    final device = selectedDevice;
    _appendLog(
      device == null
          ? 'Selected device removed.'
          : 'Selected ${device.deviceName}.',
      LogLevel.info,
      topic: LogTopic.device,
    );
    notifyListeners();
  }

  void updateEndpointText(String value) {
    _endpointText = value.trim();
    notifyListeners();
    unawaited(_drainPendingSegments());
  }

  void updateStreamIdText(String value) {
    _streamIdText = value.trim().isEmpty ? 'camera-001' : value.trim();
    notifyListeners();
  }

  void updateFragmentDurationText(String value) {
    _fragmentDurationText = value.trim().isEmpty ? '2000' : value.trim();
    notifyListeners();
  }

  Future<void> requestPermission() async {
    final device = selectedDevice;
    if (device == null) {
      _appendLog(
        'No USB camera selected.',
        LogLevel.warning,
        topic: LogTopic.permission,
      );
      return;
    }

    _phase = SessionPhase.permissionRequested;
    _statusMessage = 'Requesting permission for ${device.deviceName}.';
    notifyListeners();

    final granted = await _bridge.requestPermission(device.deviceId);
    if (granted) {
      _pendingStartAfterPermission = false;
      await refreshDevices();
      return;
    }

    _pendingStartAfterPermission = true;
    _appendLog(
      'Permission request sent for ${device.deviceName}.',
      LogLevel.info,
      topic: LogTopic.permission,
    );
    notifyListeners();
  }

  Future<void> start() async {
    final device = selectedDevice;
    if (device == null) {
      _appendLog(
        'Pick a USB camera before starting.',
        LogLevel.warning,
        topic: LogTopic.device,
      );
      return;
    }

    final target = _buildUploadTarget();
    if (target == null) {
      _appendLog(
        'Enter a valid HTTP or HTTPS upload endpoint.',
        LogLevel.warning,
        topic: LogTopic.upload,
      );
      return;
    }

    final fragmentDurationMs = _fragmentDuration();
    if (fragmentDurationMs == null) {
      _appendLog(
        'Fragment duration must be a positive integer.',
        LogLevel.warning,
        topic: LogTopic.session,
      );
      return;
    }

    if (!device.permissionGranted) {
      _pendingStartAfterPermission = true;
      await requestPermission();
      return;
    }

    _pendingStartAfterPermission = false;
    _phase = SessionPhase.starting;
    _statusMessage = 'Starting stream from ${device.deviceName}.';
    notifyListeners();

    try {
      await _bridge.startSession(
        CameraSessionRequest(
          deviceId: device.deviceId,
          streamId: _streamIdText,
          fragmentDurationMs: fragmentDurationMs,
        ),
      );
      _phase = SessionPhase.starting;
      _statusMessage = 'Start command sent to ${device.deviceName}.';
      _appendLog(
        'Start command sent for ${device.deviceName}. Waiting for recorder status.',
        LogLevel.info,
        topic: LogTopic.session,
      );
      notifyListeners();
      unawaited(_drainPendingSegments());
    } catch (error, stackTrace) {
      _phase = SessionPhase.error;
      _statusMessage = 'Failed to start the stream.';
      _lastError = error.toString();
      _appendLog(
        'Start failed: $error',
        LogLevel.error,
        topic: LogTopic.session,
        details: stackTrace,
      );
      notifyListeners();
    }
  }

  Future<void> stop() async {
    _pendingStartAfterPermission = false;
    _phase = SessionPhase.stopping;
    _statusMessage = 'Stopping stream.';
    notifyListeners();

    try {
      await _bridge.stopSession();
      _phase = _devices.isEmpty ? SessionPhase.idle : SessionPhase.ready;
      _statusMessage = 'Stream stopped.';
      _appendLog('Stream stopped.', LogLevel.info, topic: LogTopic.session);
      notifyListeners();
    } catch (error, stackTrace) {
      _phase = SessionPhase.error;
      _statusMessage = 'Failed to stop the stream.';
      _lastError = error.toString();
      _appendLog(
        'Stop failed: $error',
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

  Future<void> _handleBridgeEvent(CameraBridgeEvent event) async {
    switch (event) {
      case CameraDevicesUpdated(:final devices):
        _replaceDevices(devices);
        _appendLog(
          devices.isEmpty
              ? 'USB scan updated: no camera detected.'
              : 'USB scan updated: ${devices.length} device(s) visible.',
          LogLevel.info,
          topic: LogTopic.device,
        );
        notifyListeners();
        break;
      case CameraStatusEvent(:final phase, :final message):
        _phase = phase;
        _statusMessage = message;
        if (phase != SessionPhase.error) {
          _lastError = '';
        }
        _appendLog(
          message.isEmpty ? 'Session phase changed to ${phase.name}.' : message,
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
        _appendLog(
          granted
              ? 'Permission granted for $deviceId.'
              : 'Permission denied for $deviceId.',
          granted ? LogLevel.info : LogLevel.warning,
          topic: LogTopic.permission,
        );
        await refreshDevices();
        if (granted &&
            _pendingStartAfterPermission &&
            _selectedDeviceId == deviceId) {
          _pendingStartAfterPermission = false;
          unawaited(start());
        }
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

  void _replaceDevices(List<UsbCameraDevice> devices) {
    _devices = List<UsbCameraDevice>.unmodifiable(devices);
    if (_devices.isEmpty) {
      _selectedDeviceId = null;
      return;
    }

    if (_selectedDeviceId == null ||
        !_devices.any((UsbCameraDevice device) {
          return device.deviceId == _selectedDeviceId;
        })) {
      _selectedDeviceId = _devices.first.deviceId;
    }
  }

  void _enqueueSegment(CameraSegment segment) {
    _pendingSegments.add(_QueuedSegment(segment: segment, attempts: 0));
    _pendingUploadCount = _pendingSegments.length;
    _lastSegmentAt = segment.capturedAt;
    _appendLog(
      'Queued segment ${segment.segmentId} (${segment.byteLength} bytes).',
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
          'Upload queue is waiting for a valid endpoint.',
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
            'Uploaded ${queued.segment.segmentId} -> ${receipt.statusCode}.',
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
              'Dropping ${queued.segment.segmentId} after 3 failures.',
              LogLevel.error,
              topic: LogTopic.upload,
              details: error,
            );
            notifyListeners();
          } else {
            _appendLog(
              'Upload failed for ${queued.segment.segmentId}, retrying later.',
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

  int? _fragmentDuration() {
    final parsed = int.tryParse(_fragmentDurationText);
    if (parsed == null || parsed <= 0) {
      return null;
    }
    return parsed;
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

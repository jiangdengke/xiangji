enum SessionPhase {
  idle,
  discovering,
  ready,
  permissionRequested,
  starting,
  streaming,
  stopping,
  error,
}

enum LogLevel { debug, info, warning, error }

class UsbCameraDevice {
  const UsbCameraDevice({
    required this.deviceId,
    required this.deviceName,
    required this.vendorId,
    required this.productId,
    required this.permissionGranted,
    required this.videoClass,
    required this.interfaceCount,
  });

  final String deviceId;
  final String deviceName;
  final int vendorId;
  final int productId;
  final bool permissionGranted;
  final bool videoClass;
  final int interfaceCount;

  factory UsbCameraDevice.fromMap(Map<Object?, Object?> map) {
    return UsbCameraDevice(
      deviceId: _stringValue(map['deviceId']),
      deviceName: _stringValue(map['deviceName']),
      vendorId: _intValue(map['vendorId']),
      productId: _intValue(map['productId']),
      permissionGranted: _boolValue(map['permissionGranted']),
      videoClass: _boolValue(map['videoClass']),
      interfaceCount: _intValue(map['interfaceCount']),
    );
  }

  UsbCameraDevice copyWith({
    String? deviceId,
    String? deviceName,
    int? vendorId,
    int? productId,
    bool? permissionGranted,
    bool? videoClass,
    int? interfaceCount,
  }) {
    return UsbCameraDevice(
      deviceId: deviceId ?? this.deviceId,
      deviceName: deviceName ?? this.deviceName,
      vendorId: vendorId ?? this.vendorId,
      productId: productId ?? this.productId,
      permissionGranted: permissionGranted ?? this.permissionGranted,
      videoClass: videoClass ?? this.videoClass,
      interfaceCount: interfaceCount ?? this.interfaceCount,
    );
  }

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'deviceId': deviceId,
      'deviceName': deviceName,
      'vendorId': vendorId,
      'productId': productId,
      'permissionGranted': permissionGranted,
      'videoClass': videoClass,
      'interfaceCount': interfaceCount,
    };
  }
}

class CameraSessionRequest {
  const CameraSessionRequest({
    required this.deviceId,
    required this.streamId,
    required this.fragmentDurationMs,
  });

  final String deviceId;
  final String streamId;
  final int fragmentDurationMs;

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'deviceId': deviceId,
      'streamId': streamId,
      'fragmentDurationMs': fragmentDurationMs,
    };
  }
}

class CameraSegment {
  const CameraSegment({
    required this.segmentId,
    required this.deviceId,
    required this.streamId,
    required this.filePath,
    required this.sequence,
    required this.durationMs,
    required this.byteLength,
    required this.capturedAt,
  });

  final String segmentId;
  final String deviceId;
  final String streamId;
  final String filePath;
  final int sequence;
  final int durationMs;
  final int byteLength;
  final DateTime capturedAt;

  factory CameraSegment.fromMap(Map<Object?, Object?> map) {
    return CameraSegment(
      segmentId: _stringValue(map['segmentId']),
      deviceId: _stringValue(map['deviceId']),
      streamId: _stringValue(map['streamId']),
      filePath: _stringValue(map['filePath']),
      sequence: _intValue(map['sequence']),
      durationMs: _intValue(map['durationMs']),
      byteLength: _intValue(map['byteLength']),
      capturedAt: _dateTimeValue(map['capturedAt']) ?? DateTime.now(),
    );
  }

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'segmentId': segmentId,
      'deviceId': deviceId,
      'streamId': streamId,
      'filePath': filePath,
      'sequence': sequence,
      'durationMs': durationMs,
      'byteLength': byteLength,
      'capturedAt': capturedAt.toIso8601String(),
    };
  }
}

class UploadTarget {
  const UploadTarget({
    required this.endpoint,
    required this.streamId,
    required this.headers,
    required this.timeout,
    required this.deleteAfterUpload,
  });

  final Uri endpoint;
  final String streamId;
  final Map<String, String> headers;
  final Duration timeout;
  final bool deleteAfterUpload;

  UploadTarget copyWith({
    Uri? endpoint,
    String? streamId,
    Map<String, String>? headers,
    Duration? timeout,
    bool? deleteAfterUpload,
  }) {
    return UploadTarget(
      endpoint: endpoint ?? this.endpoint,
      streamId: streamId ?? this.streamId,
      headers: headers ?? this.headers,
      timeout: timeout ?? this.timeout,
      deleteAfterUpload: deleteAfterUpload ?? this.deleteAfterUpload,
    );
  }
}

class StreamLogEntry {
  const StreamLogEntry({
    required this.timestamp,
    required this.level,
    required this.message,
  });

  final DateTime timestamp;
  final LogLevel level;
  final String message;
}

int _intValue(Object? value, [int fallback = 0]) {
  if (value is int) {
    return value;
  }
  if (value is String) {
    return int.tryParse(value) ?? fallback;
  }
  return fallback;
}

bool _boolValue(Object? value, [bool fallback = false]) {
  if (value is bool) {
    return value;
  }
  if (value is String) {
    return value.toLowerCase() == 'true';
  }
  return fallback;
}

String _stringValue(Object? value, [String fallback = '']) {
  if (value == null) {
    return fallback;
  }
  return value.toString();
}

DateTime? _dateTimeValue(Object? value) {
  if (value is DateTime) {
    return value;
  }
  if (value is String) {
    return DateTime.tryParse(value);
  }
  return null;
}

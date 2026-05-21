import '../domain.dart';

class UploadReceipt {
  const UploadReceipt({
    required this.endpoint,
    required this.statusCode,
    required this.bytesSent,
    required this.responseBody,
  });

  final Uri endpoint;
  final int statusCode;
  final int bytesSent;
  final String responseBody;
}

abstract class SegmentUploader {
  Future<UploadReceipt> uploadSegment({
    required CameraSegment segment,
    required UploadTarget target,
  });

  Future<void> dispose();
}

class UploadException implements Exception {
  const UploadException(this.message, [this.details]);

  final String message;
  final Object? details;

  @override
  String toString() {
    if (details == null) {
      return message;
    }
    return '$message: $details';
  }
}

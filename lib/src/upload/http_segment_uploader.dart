import 'dart:io';

import 'package:http/http.dart' as http;

import '../domain.dart';
import 'segment_uploader.dart';

class HttpSegmentUploader implements SegmentUploader {
  HttpSegmentUploader({http.Client? client})
    : _client = client ?? http.Client();

  final http.Client _client;

  @override
  Future<UploadReceipt> uploadSegment({
    required CameraSegment segment,
    required UploadTarget target,
  }) async {
    final file = File(segment.filePath);
    if (!await file.exists()) {
      throw UploadException('分片文件不存在。', segment.filePath);
    }

    final request = http.StreamedRequest('POST', target.endpoint);
    request.headers.addAll(target.headers);
    request.headers['Content-Type'] = 'video/mp4';
    request.headers['X-Stream-Id'] = segment.streamId;
    request.headers['X-Device-Id'] = segment.deviceId;
    request.headers['X-Segment-Id'] = segment.segmentId;
    request.headers['X-Sequence'] = segment.sequence.toString();
    request.headers['X-Duration-Ms'] = segment.durationMs.toString();
    request.headers['X-Byte-Length'] = segment.byteLength.toString();
    request.headers['X-Captured-At'] = segment.capturedAt.toIso8601String();
    request.contentLength = await file.length();

    await request.sink.addStream(file.openRead());
    await request.sink.close();

    final response = await _client.send(request).timeout(target.timeout);
    final responseBody = await response.stream.bytesToString();

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw UploadException('上传失败，HTTP ${response.statusCode}。', responseBody);
    }

    return UploadReceipt(
      endpoint: target.endpoint,
      statusCode: response.statusCode,
      bytesSent: request.contentLength ?? segment.byteLength,
      responseBody: responseBody,
    );
  }

  @override
  Future<void> dispose() async {
    _client.close();
  }
}

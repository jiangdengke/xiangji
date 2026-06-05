import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'whip_endpoint_probe.dart';
import 'whip_signaling_headers.dart';
import 'live_stream_publisher.dart';

class WhipSignalingClient {
  WhipSignalingClient({
    http.Client? client,
    this.signalingTimeout = const Duration(seconds: 15),
    this.preflightTimeout = const Duration(seconds: 3),
    Future<void> Function(Uri endpoint, Duration timeout)? endpointProbe,
  }) : _client = client ?? http.Client(),
       _endpointProbe = endpointProbe ?? probeWhipEndpoint;

  final http.Client _client;
  final Future<void> Function(Uri endpoint, Duration timeout) _endpointProbe;
  final Duration signalingTimeout;
  final Duration preflightTimeout;

  Future<void> preflight(Uri endpoint) async {
    await _preflightEndpoint(endpoint);
  }

  Future<WhipOfferResult> publishOffer({
    required LiveStreamConfig config,
    required String sdp,
  }) async {
    final response = await _postOffer(config: config, sdp: sdp);
    final answer = _decodeAnswer(response.body);
    if (answer.sdp.isEmpty) {
      throw const WhipSignalingException('WebRTC 接收端没有返回 SDP answer。');
    }
    if (!answer.sdp.trimLeft().startsWith('v=0')) {
      throw WhipSignalingException(
        'WebRTC 接收端返回的 answer 不是有效 SDP。',
        'body 开头: ${_bodyPreview(answer.sdp)}',
      );
    }

    return WhipOfferResult(
      answerSdp: answer.sdp,
      answerType: answer.type,
      resourceUri: null,
    );
  }

  void close() {
    _client.close();
  }

  Future<http.Response> _postOffer({
    required LiveStreamConfig config,
    required String sdp,
  }) async {
    final http.Response response;
    try {
      response = await _client
          .post(
            config.endpoint,
            headers: whipOfferHeaders(
              streamId: config.streamId,
              bearerToken: config.bearerToken,
            ),
            body: jsonEncode(<String, String>{'sdp': sdp, 'type': 'offer'}),
          )
          .timeout(signalingTimeout);
    } on TimeoutException catch (error) {
      throw WhipSignalingException('连接 WebRTC 接收端超时，请检查 IP、端口和网络。', error);
    } on http.ClientException catch (error) {
      throw WhipSignalingException(
        '无法连接 WebRTC 接收端，请检查 IP、端口和服务是否已启动。',
        error.message,
      );
    } catch (error) {
      throw WhipSignalingException('无法连接 WebRTC 接收端，请检查 IP、端口和服务是否已启动。', error);
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw WhipSignalingException(
        'WebRTC 接收端返回 HTTP ${response.statusCode}。',
        response.body,
      );
    }
    return response;
  }

  Future<void> _preflightEndpoint(Uri endpoint) async {
    try {
      await _endpointProbe(endpoint, preflightTimeout);
    } on TimeoutException catch (error) {
      throw WhipSignalingException('连接 WebRTC 接收端超时，请检查 IP、端口和网络。', error);
    } on SocketException catch (error) {
      throw WhipSignalingException(
        '无法连接 WebRTC 接收端，请检查 IP、端口和服务是否已启动。',
        error.message,
      );
    } on WhipSignalingException {
      rethrow;
    } catch (error) {
      throw WhipSignalingException('无法连接 WebRTC 接收端，请检查 IP、端口和服务是否已启动。', error);
    }
  }

  _WebRtcAnswer _decodeAnswer(String body) {
    final trimmedBody = body.trim();
    if (trimmedBody.isEmpty) {
      return const _WebRtcAnswer(sdp: '', type: 'answer');
    }
    if (!trimmedBody.startsWith('{')) {
      return _WebRtcAnswer(sdp: trimmedBody, type: 'answer');
    }

    try {
      final decoded = jsonDecode(trimmedBody);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('answer JSON is not an object');
      }
      final sdp = decoded['sdp'];
      final type = decoded['type'];
      return _WebRtcAnswer(
        sdp: sdp is String ? sdp.trim() : '',
        type: _answerType(type),
      );
    } catch (error) {
      throw WhipSignalingException(
        '解析 WebRTC 接收端 JSON answer 失败。',
        '$error；body 开头: ${_bodyPreview(trimmedBody)}',
      );
    }
  }
}

String _answerType(Object? value) {
  if (value is! String) {
    return 'answer';
  }
  final trimmed = value.trim();
  if (trimmed.isEmpty) {
    return 'answer';
  }
  return trimmed;
}

String _bodyPreview(String value) {
  final compact = value.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (compact.length <= 80) {
    return compact;
  }
  return '${compact.substring(0, 80)}...';
}

class WhipOfferResult {
  const WhipOfferResult({
    required this.answerSdp,
    required this.answerType,
    required this.resourceUri,
  });

  final String answerSdp;
  final String answerType;
  final Uri? resourceUri;
}

class _WebRtcAnswer {
  const _WebRtcAnswer({required this.sdp, required this.type});

  final String sdp;
  final String type;
}

class WhipSignalingException implements Exception {
  const WhipSignalingException(this.message, [this.details]);

  final String message;
  final Object? details;

  @override
  String toString() {
    if (details == null || details.toString().isEmpty) {
      return message;
    }
    return '$message $details';
  }
}

import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'whip_endpoint_probe.dart';
import 'whip_location_resolver.dart';
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
    final answerSdp = response.body.trim();
    if (answerSdp.isEmpty) {
      throw const WhipSignalingException('WHIP 服务端没有返回 SDP answer。');
    }

    return WhipOfferResult(
      answerSdp: answerSdp,
      resourceUri: resolveWhipResourceLocation(
        config.endpoint,
        response.headers['location'],
      ),
    );
  }

  Future<void> deleteResource(Uri resourceUri, String? bearerToken) async {
    await _client
        .delete(resourceUri, headers: whipAuthorizationHeaders(bearerToken))
        .timeout(signalingTimeout);
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
            body: sdp,
          )
          .timeout(signalingTimeout);
    } on TimeoutException catch (error) {
      throw WhipSignalingException('连接 WHIP 地址超时，请检查 IP、端口和网络。', error);
    } on http.ClientException catch (error) {
      throw WhipSignalingException(
        '无法连接 WHIP 地址，请检查 IP、端口和服务是否已启动。',
        error.message,
      );
    } catch (error) {
      throw WhipSignalingException(
        '无法连接 WHIP 地址，请检查 IP、端口和服务是否已启动。',
        error,
      );
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw WhipSignalingException(
        'WHIP 服务端返回 HTTP ${response.statusCode}。',
        response.body,
      );
    }
    return response;
  }

  Future<void> _preflightEndpoint(Uri endpoint) async {
    try {
      await _endpointProbe(endpoint, preflightTimeout);
    } on TimeoutException catch (error) {
      throw WhipSignalingException('连接 WHIP 地址超时，请检查 IP、端口和网络。', error);
    } on SocketException catch (error) {
      throw WhipSignalingException(
        '无法连接 WHIP 地址，请检查 IP、端口和服务是否已启动。',
        error.message,
      );
    } on WhipSignalingException {
      rethrow;
    } catch (error) {
      throw WhipSignalingException(
        '无法连接 WHIP 地址，请检查 IP、端口和服务是否已启动。',
        error,
      );
    }
  }
}

class WhipOfferResult {
  const WhipOfferResult({required this.answerSdp, required this.resourceUri});

  final String answerSdp;
  final Uri? resourceUri;
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

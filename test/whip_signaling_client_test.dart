import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:xiangji/src/live/live_stream_publisher.dart';
import 'package:xiangji/src/live/whip_signaling_client.dart';

void main() {
  test('signaling client posts WHIP offer headers and resolves location', () async {
    final requests = <_RecordedRequest>[];
    final client = WhipSignalingClient(
      client: _RecordingHttpClient(
        onRequest: (http.BaseRequest request, String body) async {
          requests.add(_RecordedRequest(request: request, body: body));
          return http.Response(
            'answer-sdp',
            201,
            headers: <String, String>{'location': '../resource/abc'},
          );
        },
      ),
      endpointProbe: (_, _) async {},
    );

    final result = await client.publishOffer(
      config: LiveStreamConfig(
        endpoint: Uri.parse('http://127.0.0.1:8080/whip/camera-001'),
        streamId: 'camera-001',
        bearerToken: ' token ',
      ),
      sdp: 'offer-sdp',
    );

    expect(result.answerSdp, 'answer-sdp');
    expect(
      result.resourceUri,
      Uri.parse('http://127.0.0.1:8080/resource/abc'),
    );
    expect(requests, hasLength(1));
    expect(requests.single.request.method, 'POST');
    expect(requests.single.body, 'offer-sdp');
    expect(requests.single.request.headers['Accept'], 'application/sdp');
    expect(
      requests.single.request.headers['Content-Type'],
      'application/sdp',
    );
    expect(requests.single.request.headers['X-Stream-Id'], 'camera-001');
    expect(
      requests.single.request.headers['Authorization'],
      'Bearer token',
    );

    client.close();
  });

  test('signaling client maps failed preflight to WHIP exception', () async {
    final client = WhipSignalingClient(
      client: _RecordingHttpClient(
        onRequest: (_, _) async => http.Response('unused', 200),
      ),
      endpointProbe: (_, _) async {
        throw const SocketException('Connection refused');
      },
    );

    await expectLater(
      client.preflight(Uri.parse('http://127.0.0.1:65535/whip/camera-001')),
      throwsA(isA<WhipSignalingException>()),
    );

    client.close();
  });

  test('signaling client reports non-success WHIP responses', () async {
    final client = WhipSignalingClient(
      client: _RecordingHttpClient(
        onRequest: (_, _) async => http.Response('bad request', 400),
      ),
      endpointProbe: (_, _) async {},
    );

    await expectLater(
      client.publishOffer(
        config: LiveStreamConfig(
          endpoint: Uri.parse('http://127.0.0.1:8080/whip/camera-001'),
          streamId: 'camera-001',
        ),
        sdp: 'offer-sdp',
      ),
      throwsA(
        isA<WhipSignalingException>().having(
          (WhipSignalingException error) => error.toString(),
          'message',
          contains('HTTP 400'),
        ),
      ),
    );

    client.close();
  });
}

class _RecordingHttpClient extends http.BaseClient {
  _RecordingHttpClient({required this.onRequest});

  final Future<http.Response> Function(http.BaseRequest request, String body)
  onRequest;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final body = await utf8.decoder.bind(request.finalize()).join();
    final response = await onRequest(request, body);
    return http.StreamedResponse(
      Stream<List<int>>.value(utf8.encode(response.body)),
      response.statusCode,
      headers: response.headers,
      reasonPhrase: response.reasonPhrase,
      request: request,
    );
  }
}

class _RecordedRequest {
  const _RecordedRequest({required this.request, required this.body});

  final http.BaseRequest request;
  final String body;
}

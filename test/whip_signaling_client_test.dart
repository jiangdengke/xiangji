import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:xiangji/src/live/live_stream_publisher.dart';
import 'package:xiangji/src/live/whip_signaling_client.dart';

void main() {
  test('signaling client posts JSON offer and reads JSON answer', () async {
    final requests = <_RecordedRequest>[];
    final client = WhipSignalingClient(
      client: _RecordingHttpClient(
        onRequest: (http.BaseRequest request, String body) async {
          requests.add(_RecordedRequest(request: request, body: body));
          return http.Response(
            jsonEncode(<String, String>{'sdp': 'v=0\r\n', 'type': 'answer'}),
            201,
          );
        },
      ),
      endpointProbe: (_, _) async {},
    );

    final result = await client.publishOffer(
      config: LiveStreamConfig(
        endpoint: Uri.parse('http://127.0.0.1:9090/offer/camera1'),
        streamId: 'camera1',
        bearerToken: ' token ',
      ),
      sdp: 'offer-sdp',
    );

    expect(result.answerSdp, 'v=0');
    expect(result.answerType, 'answer');
    expect(result.resourceUri, isNull);
    expect(requests, hasLength(1));
    expect(requests.single.request.method, 'POST');
    expect(jsonDecode(requests.single.body), <String, dynamic>{
      'sdp': 'offer-sdp',
      'type': 'offer',
    });
    expect(requests.single.request.headers['Accept'], 'application/json');
    expect(requests.single.request.headers['Content-Type'], 'application/json');
    expect(requests.single.request.headers['X-Stream-Id'], 'camera1');
    expect(requests.single.request.headers['Authorization'], 'Bearer token');

    client.close();
  });

  test(
    'signaling client maps failed preflight to signaling exception',
    () async {
      final client = WhipSignalingClient(
        client: _RecordingHttpClient(
          onRequest: (_, _) async => http.Response('unused', 200),
        ),
        endpointProbe: (_, _) async {
          throw const SocketException('Connection refused');
        },
      );

      await expectLater(
        client.preflight(Uri.parse('http://127.0.0.1:65535/offer/camera1')),
        throwsA(isA<WhipSignalingException>()),
      );

      client.close();
    },
  );

  test('signaling client reports non-success receiver responses', () async {
    final client = WhipSignalingClient(
      client: _RecordingHttpClient(
        onRequest: (_, _) async => http.Response('bad request', 400),
      ),
      endpointProbe: (_, _) async {},
    );

    await expectLater(
      client.publishOffer(
        config: LiveStreamConfig(
          endpoint: Uri.parse('http://127.0.0.1:9090/offer/camera1'),
          streamId: 'camera1',
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

  test('signaling client still accepts raw SDP answers', () async {
    final client = WhipSignalingClient(
      client: _RecordingHttpClient(
        onRequest: (_, _) async => http.Response('v=0\r\n', 201),
      ),
      endpointProbe: (_, _) async {},
    );

    final result = await client.publishOffer(
      config: LiveStreamConfig(
        endpoint: Uri.parse('http://127.0.0.1:9090/offer/camera1'),
        streamId: 'camera1',
      ),
      sdp: 'offer-sdp',
    );

    expect(result.answerSdp, 'v=0');
    expect(result.answerType, 'answer');

    client.close();
  });

  test('signaling client rejects non-SDP answers before WebRTC', () async {
    final client = WhipSignalingClient(
      client: _RecordingHttpClient(
        onRequest: (_, _) async {
          return http.Response(
            jsonEncode(<String, String>{'sdp': 'not-sdp', 'type': 'answer'}),
            201,
          );
        },
      ),
      endpointProbe: (_, _) async {},
    );

    await expectLater(
      client.publishOffer(
        config: LiveStreamConfig(
          endpoint: Uri.parse('http://127.0.0.1:9090/offer/camera1'),
          streamId: 'camera1',
        ),
        sdp: 'offer-sdp',
      ),
      throwsA(
        isA<WhipSignalingException>().having(
          (WhipSignalingException error) => error.toString(),
          'message',
          contains('不是有效 SDP'),
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

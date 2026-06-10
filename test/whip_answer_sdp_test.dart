import 'package:flutter_test/flutter_test.dart';

import 'package:xiangji/src/live/whip_answer_sdp.dart';

void main() {
  test(
    'splitWhipAnswerSdp removes inline candidates for separate addCandidate',
    () {
      const answerSdp = '''v=0
o=- 3990064730 3990064730 IN IP4 0.0.0.0
s=-
t=0 0
a=group:BUNDLE 0
m=video 9 UDP/TLS/RTP/SAVPF 96
c=IN IP4 0.0.0.0
a=recvonly
a=mid:0
a=rtcp-mux
a=rtpmap:96 VP8/90000
a=ice-ufrag:ODpu
a=ice-pwd:BfyDU48exDtaXvZG91i7iF
a=fingerprint:sha-256 0D:A0
a=setup:active
a=candidate:ac5c 1 udp 2130706431 192.168.50.194 42139 typ host
a=end-of-candidates
''';

      final result = splitWhipAnswerSdp(answerSdp);

      expect(result.sessionDescriptionSdp, contains('m=video 9'));
      expect(result.sessionDescriptionSdp, contains('a=mid:0'));
      expect(result.sessionDescriptionSdp, isNot(contains('a=candidate:')));
      expect(
        result.sessionDescriptionSdp,
        isNot(contains('a=end-of-candidates')),
      );
      expect(result.candidates, hasLength(1));
      expect(
        result.candidates.single.candidate,
        'candidate:ac5c 1 udp 2130706431 192.168.50.194 42139 typ host',
      );
      expect(result.candidates.single.sdpMid, '0');
      expect(result.candidates.single.sdpMLineIndex, 0);
    },
  );
}

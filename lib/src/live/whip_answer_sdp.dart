import 'package:flutter_webrtc/flutter_webrtc.dart';

class WhipAnswerSdp {
  const WhipAnswerSdp({
    required this.sessionDescriptionSdp,
    required this.candidates,
  });

  final String sessionDescriptionSdp;
  final List<RTCIceCandidate> candidates;
}

WhipAnswerSdp splitWhipAnswerSdp(String sdp) {
  final descriptionLines = <String>[];
  final candidates = <RTCIceCandidate>[];
  var mediaLineIndex = -1;
  int? currentMediaLineIndex;
  String? currentMid;

  for (final line in sdp.split(RegExp(r'\r?\n'))) {
    if (line.isEmpty) {
      continue;
    }

    if (line.startsWith('m=')) {
      mediaLineIndex += 1;
      currentMediaLineIndex = mediaLineIndex;
      currentMid = null;
      descriptionLines.add(line);
      continue;
    }

    if (line.startsWith('a=mid:')) {
      currentMid = line.substring('a=mid:'.length).trim();
      descriptionLines.add(line);
      continue;
    }

    if (line.startsWith('a=candidate:')) {
      candidates.add(
        RTCIceCandidate(
          line.substring('a='.length),
          currentMid,
          currentMediaLineIndex,
        ),
      );
      continue;
    }

    if (line == 'a=end-of-candidates') {
      continue;
    }

    descriptionLines.add(line);
  }

  return WhipAnswerSdp(
    sessionDescriptionSdp: descriptionLines.isEmpty
        ? ''
        : '${descriptionLines.join('\r\n')}\r\n',
    candidates: candidates,
  );
}

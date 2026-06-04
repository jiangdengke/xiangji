class LiveStreamEndpoint {
  LiveStreamEndpoint({String endpointText = ''})
    : _endpointText = endpointText.trim();

  String _endpointText;

  String get text => _endpointText;
  bool get isValid => uri != null;
  Uri? get uri => parseHttpEndpoint(_endpointText);

  void updateText(String value) {
    _endpointText = value.trim();
  }

  Uri endpointForStreamId({
    required Uri endpoint,
    required String streamId,
    required String streamIdPrefix,
    required Iterable<String> knownStreamIds,
  }) {
    final pathSegments = endpoint.pathSegments.toList(growable: true);
    if (pathSegments.isEmpty) {
      pathSegments.add(streamId);
    } else if (pathSegments.last.isEmpty) {
      pathSegments[pathSegments.length - 1] = streamId;
    } else if (_shouldAppendEndpointStreamSegment(pathSegments.last)) {
      pathSegments.add(streamId);
    } else if (_shouldReplaceEndpointStreamSegment(
      pathSegments.last,
      streamIdPrefix: streamIdPrefix,
      knownStreamIds: knownStreamIds,
    )) {
      pathSegments[pathSegments.length - 1] = streamId;
    }
    return endpoint.replace(pathSegments: pathSegments);
  }

  static Uri? parseHttpEndpoint(String value) {
    final endpoint = Uri.tryParse(value.trim());
    if (endpoint == null ||
        !endpoint.hasScheme ||
        (!endpoint.isScheme('http') && !endpoint.isScheme('https')) ||
        endpoint.host.trim().isEmpty) {
      return null;
    }
    return endpoint;
  }

  bool _shouldAppendEndpointStreamSegment(String segment) {
    return segment == 'whip' || segment == 'offer';
  }

  bool _shouldReplaceEndpointStreamSegment(
    String segment, {
    required String streamIdPrefix,
    required Iterable<String> knownStreamIds,
  }) {
    if (segment == streamIdPrefix.trim()) {
      return true;
    }
    return knownStreamIds.contains(segment);
  }
}

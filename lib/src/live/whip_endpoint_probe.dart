import 'dart:io';

typedef WhipEndpointProbe =
    Future<void> Function(Uri endpoint, Duration timeout);

Future<void> probeWhipEndpoint(Uri endpoint, Duration timeout) async {
  final socket = await Socket.connect(
    endpoint.host,
    _endpointPort(endpoint),
    timeout: timeout,
  );
  socket.destroy();
}

int _endpointPort(Uri endpoint) {
  if (endpoint.hasPort) {
    return endpoint.port;
  }
  return endpoint.isScheme('https') ? 443 : 80;
}

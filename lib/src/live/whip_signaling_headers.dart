Map<String, String> whipAuthorizationHeaders(String? bearerToken) {
  final token = bearerToken;
  if (token == null || token.trim().isEmpty) {
    return const <String, String>{};
  }
  return <String, String>{'Authorization': 'Bearer ${token.trim()}'};
}

Map<String, String> whipOfferHeaders({
  required String streamId,
  required String? bearerToken,
}) {
  return <String, String>{
    ...whipAuthorizationHeaders(bearerToken),
    'Accept': 'application/json',
    'Content-Type': 'application/json',
    'X-Stream-Id': streamId,
  };
}

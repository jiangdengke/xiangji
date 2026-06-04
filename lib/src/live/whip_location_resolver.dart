Uri? resolveWhipResourceLocation(Uri endpoint, String? location) {
  if (location == null || location.trim().isEmpty) {
    return null;
  }
  final parsed = Uri.tryParse(location.trim());
  if (parsed == null) {
    return null;
  }
  if (parsed.hasScheme) {
    return parsed;
  }
  return endpoint.resolveUri(parsed);
}

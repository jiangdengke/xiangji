class LiveStreamIdPolicy {
  const LiveStreamIdPolicy();

  bool isValid(String value) {
    final trimmed = value.trim();
    return trimmed.isNotEmpty && !trimmed.contains(RegExp(r'\s'));
  }

  String defaultForDevice({
    required String prefix,
    required int index,
    required int total,
  }) {
    final base = prefix.trim();
    if (base.isEmpty) {
      return '';
    }
    if (total <= 1) {
      return base;
    }
    return '$base-${(index + 1).toString().padLeft(2, '0')}';
  }
}

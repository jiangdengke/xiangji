class LiveStreamIdPolicy {
  const LiveStreamIdPolicy();

  static const validCameraNames = <String>{
    'camera1',
    'camera2',
    'camera3',
    'camera4',
  };

  bool isValid(String value) {
    return validCameraNames.contains(value.trim());
  }

  bool isPrefixValid(String value) {
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
    if (base == 'camera') {
      return 'camera${index + 1}';
    }
    if (total <= 1) {
      return base;
    }
    return '$base-${(index + 1).toString().padLeft(2, '0')}';
  }
}

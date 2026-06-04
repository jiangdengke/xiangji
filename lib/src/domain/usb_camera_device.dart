import 'value_parsers.dart';

class UsbCameraDevice {
  const UsbCameraDevice({
    required this.deviceId,
    required this.deviceName,
    required this.vendorId,
    required this.productId,
    required this.permissionGranted,
    required this.videoClass,
    required this.interfaceCount,
  });

  final String deviceId;
  final String deviceName;
  final int vendorId;
  final int productId;
  final bool permissionGranted;
  final bool videoClass;
  final int interfaceCount;

  factory UsbCameraDevice.fromMap(Map<Object?, Object?> map) {
    return UsbCameraDevice(
      deviceId: stringValue(map['deviceId']),
      deviceName: stringValue(map['deviceName']),
      vendorId: intValue(map['vendorId']),
      productId: intValue(map['productId']),
      permissionGranted: boolValue(map['permissionGranted']),
      videoClass: boolValue(map['videoClass']),
      interfaceCount: intValue(map['interfaceCount']),
    );
  }

  UsbCameraDevice copyWith({
    String? deviceId,
    String? deviceName,
    int? vendorId,
    int? productId,
    bool? permissionGranted,
    bool? videoClass,
    int? interfaceCount,
  }) {
    return UsbCameraDevice(
      deviceId: deviceId ?? this.deviceId,
      deviceName: deviceName ?? this.deviceName,
      vendorId: vendorId ?? this.vendorId,
      productId: productId ?? this.productId,
      permissionGranted: permissionGranted ?? this.permissionGranted,
      videoClass: videoClass ?? this.videoClass,
      interfaceCount: interfaceCount ?? this.interfaceCount,
    );
  }

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'deviceId': deviceId,
      'deviceName': deviceName,
      'vendorId': vendorId,
      'productId': productId,
      'permissionGranted': permissionGranted,
      'videoClass': videoClass,
      'interfaceCount': interfaceCount,
    };
  }
}

import '../domain.dart';

enum LiveStreamStartPreparationKind { ready, rejected, needsPermission }

class LiveStreamStartPreparation {
  LiveStreamStartPreparation._({
    required this.kind,
    required Iterable<UsbCameraDevice> selectedCameras,
    required Iterable<UsbCameraDevice> pendingPermissionDevices,
    required this.message,
    required this.topic,
    required this.baseEndpoint,
  }) : selectedCameras = List<UsbCameraDevice>.unmodifiable(selectedCameras),
       pendingPermissionDevices = List<UsbCameraDevice>.unmodifiable(
         pendingPermissionDevices,
       );

  factory LiveStreamStartPreparation.ready({
    required Iterable<UsbCameraDevice> selectedCameras,
    required Uri baseEndpoint,
  }) {
    return LiveStreamStartPreparation._(
      kind: LiveStreamStartPreparationKind.ready,
      selectedCameras: selectedCameras,
      pendingPermissionDevices: const <UsbCameraDevice>[],
      message: '',
      topic: LogTopic.session,
      baseEndpoint: baseEndpoint,
    );
  }

  factory LiveStreamStartPreparation.rejected({
    required String message,
    required LogTopic topic,
  }) {
    return LiveStreamStartPreparation._(
      kind: LiveStreamStartPreparationKind.rejected,
      selectedCameras: const <UsbCameraDevice>[],
      pendingPermissionDevices: const <UsbCameraDevice>[],
      message: message,
      topic: topic,
      baseEndpoint: null,
    );
  }

  factory LiveStreamStartPreparation.needsPermission({
    required Iterable<UsbCameraDevice> selectedCameras,
    required Iterable<UsbCameraDevice> pendingPermissionDevices,
    required String message,
  }) {
    return LiveStreamStartPreparation._(
      kind: LiveStreamStartPreparationKind.needsPermission,
      selectedCameras: selectedCameras,
      pendingPermissionDevices: pendingPermissionDevices,
      message: message,
      topic: LogTopic.permission,
      baseEndpoint: null,
    );
  }

  final LiveStreamStartPreparationKind kind;
  final List<UsbCameraDevice> selectedCameras;
  final List<UsbCameraDevice> pendingPermissionDevices;
  final String message;
  final LogTopic topic;
  final Uri? baseEndpoint;

  bool get isReady => kind == LiveStreamStartPreparationKind.ready;
  bool get isRejected => kind == LiveStreamStartPreparationKind.rejected;
  bool get requiresPermission =>
      kind == LiveStreamStartPreparationKind.needsPermission;
}

class LiveStreamStartedStream {
  const LiveStreamStartedStream({
    required this.camera,
    required this.streamId,
    required this.endpoint,
  });

  final UsbCameraDevice camera;
  final String streamId;
  final Uri endpoint;
}

class LiveStreamStartResult {
  LiveStreamStartResult({required Iterable<LiveStreamStartedStream> streams})
    : streams = List<LiveStreamStartedStream>.unmodifiable(streams);

  final List<LiveStreamStartedStream> streams;

  List<String> get streamIds {
    return streams
        .map((LiveStreamStartedStream stream) => stream.streamId)
        .toList(growable: false);
  }
}

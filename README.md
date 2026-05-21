# Xiangji

Flutter shell for an Android USB camera streaming app.

## What is implemented

- Flutter dashboard for stream status, USB device selection, endpoint config, and logs.
- Dart-side upload queue that uploads each finished video segment with HTTP `POST`.
- Android native bridge over `MethodChannel` and `EventChannel`.
- USB device enumeration and permission request through Android USB Host APIs.
- Android foreground service skeleton for the camera stream lifecycle.
- Mock bridge for non-Android development and tests.

The current Android service does not yet capture and encode real UVC frames. The
integration point is:

```text
android/app/src/main/kotlin/com/example/xiangji/service/CameraStreamService.kt
```

Wire a UVC backend there, write each encoded segment to app storage, then emit a
segment event through `CameraBridgeEventBus.segment(...)`.

## Architecture

```text
lib/src/domain.dart                         Domain models
lib/src/controller/xiangji_session_controller.dart
                                             Session state, USB flow, upload queue
lib/src/bridge/*                             Flutter bridge abstractions
lib/src/upload/*                             HTTP segment uploader
lib/src/ui/stream_dashboard_page.dart        Operational UI

android/app/src/main/kotlin/com/example/xiangji/bridge/*
                                             Native USB channel and event bus
android/app/src/main/kotlin/com/example/xiangji/service/CameraStreamService.kt
                                             Foreground service and UVC hook point
```

## HTTP segment upload

Each segment is posted as the raw request body:

```http
POST /api/camera/segments
Content-Type: video/mp4
X-Stream-Id: camera-001
X-Device-Id: /dev/bus/usb/001/002
X-Segment-Id: segment-1
X-Sequence: 1
X-Duration-Ms: 2000
X-Byte-Length: 123456
X-Captured-At: 2026-05-21T06:00:00.000Z
```

## Verify

```bash
flutter analyze
flutter test
flutter build apk --debug
```

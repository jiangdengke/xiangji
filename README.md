# Xiangji

Flutter shell for an Android USB camera streaming app.

## What is implemented

- Flutter dashboard for stream status, USB device selection, endpoint config, and logs.
- Dart-side upload queue that uploads each finished video segment with HTTP `POST`.
- Android native bridge over `MethodChannel` and `EventChannel`.
- USB device enumeration and permission request through Android USB Host APIs.
- Android foreground service for Camera2 recording.
- Camera2 H.264/MP4 segment recorder that emits finished segments to the Dart
  upload queue while recording continues.
- Mock bridge for non-Android development and tests.

The native recorder uses Android Camera2. It works when the board exposes the
USB camera as a Camera2 device, preferably with `LENS_FACING_EXTERNAL`. If the
camera only appears as `/dev/video*` and is not visible through Camera2, the app
logs a clear error and a libuvc/V4L2 backend is still required for that board.

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
android/app/src/main/kotlin/com/example/xiangji/camera/Camera2SegmentRecorder.kt
                                             Camera2 encoder and MP4 segmenter
android/app/src/main/kotlin/com/example/xiangji/service/CameraStreamService.kt
                                             Foreground service lifecycle
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
flutter build apk --release
```

## Release workflow

GitHub Actions builds and publishes an APK when a `v*` tag is pushed:

```bash
git tag v1.0.0
git push origin v1.0.0
```

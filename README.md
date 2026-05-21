# 巡摄

面向 Android USB 摄像头的边录边传 Flutter 应用。

## 已实现

- Flutter 控制台，包含状态、多摄像头选择、上传地址和日志。
- Dart 侧上传队列，会把每个完成的视频分片通过 HTTP `POST` 发出。
- Android 原生桥接，基于 `MethodChannel` 和 `EventChannel`。
- 通过 Android USB Host API 枚举设备并请求权限。
- 基于 Camera2 的前台录制服务。
- Camera2 H.264/MP4 分片录制器，会在录制继续时持续产出可上传分片。
- 支持同时选择并录制多路 USB 摄像头，每路会生成独立流 ID。
- USB 热插拔检测，能区分普通 USB 设备和真正的视频摄像头。
- 非 Android 开发和测试用的模拟桥接。

原生录制器使用 Android Camera2。只有当板子把 USB 摄像头暴露成 Camera2
设备时才可直接工作，最好是 `LENS_FACING_EXTERNAL`。如果摄像头只显示为
`/dev/video*`，并且 Camera2 看不到它，应用会明确报错，这类板子仍然需要
libuvc/V4L2 后端。

多摄像头录制会在同一个前台服务中为每路摄像头启动一个录制器。基础流 ID
会自动追加序号，例如 `camera-001-01`、`camera-001-02`。当前实现会按
Camera2 外置摄像头列表顺序分配给选中的 USB 摄像头；如果板子的 Camera2
实现没有提供 USB 设备和 Camera2 cameraId 的稳定对应关系，需要在设备适配层
继续补映射。

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
X-Camera-Id: 3
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

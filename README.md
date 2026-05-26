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

原生录制器使用 Android Camera2。优先枚举 USB Video Class 设备；如果真机
摄像头是擎朗机器人内置摄像头且没有枚举为 USB 设备，应用会回退列出系统
Camera2 摄像头并直接录制。只有当摄像头只显示为 `/dev/video*`，并且
Camera2 看不到它时，仍然需要 libuvc/V4L2 后端。

多摄像头录制会在同一个前台服务中为每路摄像头启动一个录制器。基础流 ID
会自动追加序号，例如 `camera-001-01`、`camera-001-02`。当前实现会按
Camera2 外置摄像头列表顺序分配给选中的 USB 摄像头；如果板子的 Camera2
实现没有提供 USB 设备和 Camera2 cameraId 的稳定对应关系，需要在设备适配层
继续补映射。

## 录制与上传流程

1. Flutter 端选择摄像头、上传地址、流 ID 和分片时长。
2. 点击开始后，Dart 通过 MethodChannel 调 Android 原生前台服务。
3. 原生侧用 Camera2 + MediaCodec + MediaMuxer 录制成连续的 MP4 分片。
4. 分片先写入应用私有目录 `files/segments/<streamId>/`。
5. 每个分片完成后，原生侧通过 EventChannel 把文件路径和元数据回传给 Dart。
6. Dart 端把分片加入上传队列，按顺序发 HTTP `POST`。
7. 上传成功后删除本地分片；上传失败则重试，连续 3 次失败后标记失败并保留文件。

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

Each segment is posted as the raw MP4 body:

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

服务端只要能接收原始二进制请求体就行，推荐直接按 `Content-Type: video/mp4`
保存或转存。返回 2xx 视为成功；非 2xx 会被客户端重试。

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

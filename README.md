# 巡摄

面向 Android USB 摄像头的实时预览 Flutter 应用。

## 已实现

- Flutter 控制台，包含状态、摄像头选择、每路摄像头流 ID、WebRTC 地址和日志。
- WebRTC 实时推流发布端，按 WHIP 协议把一路视频推到服务端。
- Android 原生桥接，基于 `MethodChannel` 和 `EventChannel`。
- 通过 Android USB Host API 枚举设备并请求权限。
- USB 热插拔检测，能区分普通 USB 设备和真正的视频摄像头。
- 非 Android 开发和测试用的模拟桥接。
- 旧的 Camera2 MP4 分片录制和 HTTP 上传代码保留在仓库里，但当前启动流程不再调用。

当前实时预览通过 `flutter_webrtc` 调 Android 标准摄像头接口获取画面。应用的
USB 设备列表用于现场选择和权限流程；真正的视频采集由系统 WebRTC 摄像头能力
决定。如果机器人摄像头只暴露为 `/dev/video*`，并且 Android 标准摄像头接口
看不到它，仍然需要后续做原生 libuvc/V4L2 采集接入。

## WebRTC 实时预览流程

1. Flutter 端选择摄像头、WHIP 地址和默认流 ID 前缀；每个检测到的摄像头可单独修改流 ID。
2. 点击开始后，应用通过 Android 标准摄像头接口获取本地视频轨。
3. 应用创建 WebRTC offer，等待 ICE candidate 收集完成。
4. 应用把 SDP offer 以 `application/sdp` POST 到 WHIP 地址。
5. 服务端返回 SDP answer 后，应用设置 remote description 并开始推流。
6. 点击停止时，如果服务端返回了 `Location`，应用会向该地址发 `DELETE` 释放会话。

本版本先做实时预览；按时间段查看历史录像的服务端录制/回放链路暂不实现。

## Architecture

```text
lib/src/domain.dart                         Domain models
lib/src/controller/xiangji_session_controller.dart
                                             Session state, USB flow, live stream control
lib/src/bridge/*                             Flutter bridge abstractions
lib/src/live/*                               WHIP/WebRTC publisher
lib/src/upload/*                             HTTP segment uploader
lib/src/ui/stream_dashboard_page.dart        Operational UI

android/app/src/main/kotlin/com/example/xiangji/bridge/*
                                             Native USB channel and event bus
android/app/src/main/kotlin/com/example/xiangji/camera/Camera2SegmentRecorder.kt
                                             Camera2 encoder and MP4 segmenter
android/app/src/main/kotlin/com/example/xiangji/service/CameraStreamService.kt
                                             Foreground service lifecycle
```

## WHIP endpoint

服务端需要提供 WHIP 接入地址。应用会把地址最后一段替换成启动摄像头自己的流 ID，并发送：

```http
POST /whip/camera-001
Accept: application/sdp
Content-Type: application/sdp
X-Stream-Id: camera-001

v=0
...
```

服务端返回 2xx 和 SDP answer。推荐返回 `201 Created`，并通过 `Location`
给出 WHIP resource URL；客户端停止时会对该地址发 `DELETE`。

网页端实时观看不直接连机器人 app，而是连接服务端/SFU/gateway 提供的播放入口
（例如 WHEP、WebRTC viewer 页面或服务端自定义 signaling）。

## Python 接收示例

仓库提供了一个最小 WHIP 接收端示例：`examples/whip_receiver.py`。它会接收
Flutter 端发来的 SDP offer，返回 SDP answer，并消费视频轨，控制台每收到约
30 帧打印一次帧统计。

```bash
python3 -m venv .venv-whip
source .venv-whip/bin/activate
pip install -r examples/requirements-whip-receiver.txt
python examples/whip_receiver.py --host 0.0.0.0 --port 8080
```

应用端的 WebRTC 地址填写：

```text
http://<接收端机器 IP>:8080/whip/camera-001
```

如果检测到多路摄像头，默认流 ID 前缀为 `camera-001` 时，界面会自动生成
`camera-001-01`、`camera-001-02` 这类每路 ID；也可以在摄像头卡片里手动改成
任意不重复、无空白字符的 ID。当前实时 WebRTC 启动流程仍先推选中的第一路摄像头。

如果是在同一台电脑的模拟环境测试，也可以填：

```text
http://127.0.0.1:8080/whip/camera-001
```

旧的 MP4 分片上传代码是普通 HTTP `POST video/mp4` 接收，不是当前默认启动流程；
当前实时链路请优先使用这个 WHIP 接收示例。

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

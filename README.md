# 巡摄

面向 Android USB 摄像头的实时预览 Flutter 应用。

## 已实现

- Flutter 控制台，包含状态、摄像头选择、每路 `camera_name`、WebRTC 地址和日志。
- WebRTC 实时推流发布端，按 ROS2 接收端的 JSON 信令把一路或多路视频推到服务端。
- Android 原生桥接，基于 `MethodChannel` 和 `EventChannel`。
- 通过 Android USB Host API 枚举设备并请求权限。
- USB 热插拔检测，能区分普通 USB 设备和真正的视频摄像头。
- 非 Android 开发和测试用的模拟桥接。

当前实时预览通过 `flutter_webrtc` 调 Android 标准摄像头接口获取画面。应用的
USB 设备列表用于现场选择和权限流程；真正的视频采集由系统 WebRTC 摄像头能力
决定。如果机器人摄像头只暴露为 `/dev/video*`，并且 Android 标准摄像头接口
看不到它，仍然需要后续做原生 libuvc/V4L2 采集接入。

## WebRTC 实时预览流程

1. Flutter 端选择摄像头、接收端地址和默认 `camera_name` 前缀；每个检测到的摄像头可单独修改 `camera_name`。
2. 点击开始后，应用通过 Android 标准摄像头接口获取本地视频轨。
3. 应用创建 WebRTC offer，等待 ICE candidate 收集完成。
4. 应用把 `{ "sdp": "...", "type": "offer" }` 以 JSON POST 到接收端地址。
5. 服务端返回 SDP answer 后，应用设置 remote description 并开始推流。
6. 点击停止时，应用关闭本地 WebRTC 连接和本地媒体流。

本版本先做实时预览；按时间段查看历史录像的服务端录制/回放链路暂不实现。

## Architecture

```text
lib/src/domain.dart                         Domain models
lib/src/controller/xiangji_session_controller.dart
                                             Session state, USB flow, live stream control
lib/src/bridge/*                             Flutter bridge abstractions
lib/src/live/*                               WebRTC publisher and signaling
lib/src/ui/stream_dashboard_page.dart        Operational UI

android/app/src/main/kotlin/com/example/xiangji/bridge/*
                                             Native USB channel and event bus
```

## ROS2 WebRTC 接收端

当前项目已适配 ROS2 WebRTC 接收端。接收端需要提供这些地址：

```text
POST /offer/camera1
POST /offer/camera2
POST /offer/camera3
POST /offer/camera4
```

应用会把地址最后一段替换成启动摄像头自己的 `camera_name`，并发送：

```http
POST /offer/camera1
Accept: application/json
Content-Type: application/json

{"sdp":"v=0\r\n...","type":"offer"}
```

服务端返回 2xx 和 JSON answer：

```json
{"sdp":"v=0\r\n...","type":"answer"}
```

网页端实时观看不直接连机器人 app，而是连接服务端/SFU/gateway 提供的播放入口
（例如 WHEP、WebRTC viewer 页面或服务端自定义 signaling）。

## 接收端配置

应用端的 WebRTC 地址填写：

```text
http://<接收端机器 IP>:9090/offer/camera1
```

如果检测到多路摄像头，默认 `camera_name` 前缀为 `camera` 时，界面会自动生成
`camera1`、`camera2`、`camera3`、`camera4`。当前接收端只接受这四个名字，应用会在启动前校验。

如果是在同一台电脑的模拟环境测试，也可以填：

```text
http://127.0.0.1:9090/offer/camera1
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

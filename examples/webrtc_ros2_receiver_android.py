#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""ROS2 WebRTC receiver with Android-compatible answer SDP cleanup."""

import asyncio
import signal
from typing import Dict, List, Optional, Set, Tuple

from aiohttp import web

from aiortc import RTCPeerConnection, RTCSessionDescription
from aiortc.contrib.media import MediaBlackhole

import rclpy
from rclpy.node import Node
from rclpy.qos import QoSProfile, ReliabilityPolicy, HistoryPolicy

from sensor_msgs.msg import Image
from cv_bridge import CvBridge


# ==============================
# 配置区
# ==============================

HOST = "0.0.0.0"
PORT = 9090

# 四路地址 -> ROS2 话题
CAMERA_CONFIG = {
    "camera1": {
        "topic": "/webrtc/camera1/image_raw",
        "frame_id": "webrtc_camera1",
    },
    "camera2": {
        "topic": "/webrtc/camera2/image_raw",
        "frame_id": "webrtc_camera2",
    },
    "camera3": {
        "topic": "/webrtc/camera3/image_raw",
        "frame_id": "webrtc_camera3",
    },
    "camera4": {
        "topic": "/webrtc/camera4/image_raw",
        "frame_id": "webrtc_camera4",
    },
}

# aiortc 有时会在只接收的 answer SDP 中保留发送端专用属性，或把 ICE
# candidate 放在 ice-ufrag/ice-pwd/fingerprint/setup 前面。Android libwebrtc
# 对这类 SDP 更严格，可能直接解析失败并报 SessionDescription is NULL。
SESSION_SENDER_ATTRIBUTE_PREFIXES = (
    "a=msid-semantic:",
)

RECVONLY_SENDER_ATTRIBUTE_PREFIXES = (
    "a=msid:",
    "a=ssrc:",
    "a=ssrc-group:",
)


def sanitize_android_recvonly_answer_sdp(sdp: str) -> Tuple[str, int]:
    """
    清理 Android WebRTC 不兼容的 recvonly answer SDP。

    当前服务端只接收 Flutter 推来的视频，因此 answer 的 video m-line 是
    recvonly。recvonly answer 不应该再描述本端发送流的 msid/ssrc 信息。
    同时将 ICE candidate 放到 ice-ufrag/ice-pwd/fingerprint/setup 后面，
    移除 a=end-of-candidates，并优先只保留 VP8，避免部分 Android libwebrtc
    版本对 aiortc 输出的 H264/RTX answer 解析失败。
    """
    if not sdp:
        return "", 0

    removed_count = 0
    sanitized_lines: List[str] = []
    for section in _split_sdp_sections(sdp):
        section_is_recvonly = _is_recvonly_media_section(section)
        preferred_payloads = _preferred_recvonly_payloads(section)
        section_lines: List[str] = []
        candidate_lines: List[str] = []
        has_end_of_candidates = False

        for line in section:
            if line.startswith(SESSION_SENDER_ATTRIBUTE_PREFIXES):
                removed_count += 1
                continue

            if section_is_recvonly and line.startswith(
                RECVONLY_SENDER_ATTRIBUTE_PREFIXES
            ):
                removed_count += 1
                continue

            if line.startswith("a=candidate:"):
                candidate_lines.append(line)
                continue

            if line == "a=end-of-candidates":
                has_end_of_candidates = True
                continue

            if section_is_recvonly:
                line = _sanitize_recvonly_media_line(line, preferred_payloads)
                if line is None:
                    removed_count += 1
                    continue

            section_lines.append(line)

        sanitized_lines.extend(section_lines)
        sanitized_lines.extend(candidate_lines)
        if has_end_of_candidates:
            removed_count += 1

    return "\r\n".join(sanitized_lines) + "\r\n", removed_count


def _split_sdp_sections(sdp: str) -> List[List[str]]:
    sections: List[List[str]] = []
    current_section: List[str] = []

    for line in sdp.splitlines():
        if line.startswith("m=") and current_section:
            sections.append(current_section)
            current_section = [line]
            continue
        current_section.append(line)

    if current_section:
        sections.append(current_section)
    return sections


def _is_recvonly_media_section(section: List[str]) -> bool:
    return bool(section and section[0].startswith("m=") and "a=recvonly" in section)


def _preferred_recvonly_payloads(section: List[str]) -> Optional[Set[str]]:
    vp8_payloads: Set[str] = set()
    for line in section:
        if not line.startswith("a=rtpmap:"):
            continue

        payload, codec = _split_sdp_attribute_value(line)
        if payload and codec.upper().startswith("VP8/"):
            vp8_payloads.add(payload)

    return vp8_payloads or None


def _sanitize_recvonly_media_line(
    line: str,
    preferred_payloads: Optional[Set[str]],
) -> Optional[str]:
    if line.startswith("m=video "):
        return _sanitize_video_m_line(line, preferred_payloads)

    if line.startswith("c=IN IP4 "):
        return "c=IN IP4 0.0.0.0"

    if line.startswith("a=rtcp:"):
        return None

    if preferred_payloads is None:
        return line

    if line.startswith(("a=rtpmap:", "a=fmtp:", "a=rtcp-fb:")):
        payload, _ = _split_sdp_attribute_value(line)
        if payload not in preferred_payloads:
            return None

    return line


def _sanitize_video_m_line(
    line: str,
    preferred_payloads: Optional[Set[str]],
) -> str:
    parts = line.split()
    if len(parts) < 4 or preferred_payloads is None:
        return line

    payloads = [payload for payload in parts[3:] if payload in preferred_payloads]
    if not payloads:
        return line

    return " ".join([parts[0], "9", parts[2], *payloads])


def _split_sdp_attribute_value(line: str) -> Tuple[str, str]:
    _, _, value = line.partition(":")
    payload, _, rest = value.partition(" ")
    return payload, rest


class WebRTCToRos2Node(Node):
    """
    WebRTC 视频帧接收后，转换成 ROS2 sensor_msgs/Image 并发布。
    """

    def __init__(self):
        super().__init__("webrtc_to_ros2_server")

        self.bridge = CvBridge()

        # 视频流建议使用 SensorData 风格 QoS：只保留最新帧，避免积压
        qos = QoSProfile(
            reliability=ReliabilityPolicy.BEST_EFFORT,
            history=HistoryPolicy.KEEP_LAST,
            depth=1,
        )

        self.publishers_dict = {}

        for camera_name, cfg in CAMERA_CONFIG.items():
            topic = cfg["topic"]
            self.publishers_dict[camera_name] = self.create_publisher(
                Image,
                topic,
                qos,
            )
            self.get_logger().info(f"[INIT] {camera_name} -> ROS2 topic: {topic}")

    def publish_frame(self, camera_name: str, frame_bgr):
        """
        发布单帧 OpenCV BGR 图像到对应 ROS2 topic。
        """
        if camera_name not in self.publishers_dict:
            self.get_logger().error(f"[ERROR] 未知 camera_name: {camera_name}")
            return

        try:
            msg = self.bridge.cv2_to_imgmsg(frame_bgr, encoding="bgr8")
            msg.header.stamp = self.get_clock().now().to_msg()
            msg.header.frame_id = CAMERA_CONFIG[camera_name]["frame_id"]

            self.publishers_dict[camera_name].publish(msg)

        except Exception as e:
            self.get_logger().error(
                f"[ERROR] 发布 {camera_name} 图像失败: {repr(e)}"
            )


class WebRTCServer:
    """
    WebRTC 信令服务 + 视频 track 接收管理。
    """

    def __init__(self, ros_node: WebRTCToRos2Node):
        self.ros_node = ros_node
        self.pcs: Set[RTCPeerConnection] = set()

        # 每路只保留当前连接，新的连接进来时可以覆盖旧连接
        self.camera_pc_map: Dict[str, RTCPeerConnection] = {}

    async def offer(self, request: web.Request):
        """
        WebRTC offer 接口。

        客户端 POST:
        {
            "sdp": "...",
            "type": "offer"
        }

        服务端返回:
        {
            "sdp": "...",
            "type": "answer"
        }
        """
        camera_name = request.match_info.get("camera_name", "")

        if camera_name not in CAMERA_CONFIG:
            return web.json_response(
                {
                    "success": False,
                    "error": f"未知 camera_name: {camera_name}",
                    "valid_camera_names": list(CAMERA_CONFIG.keys()),
                },
                status=404,
            )

        try:
            params = await request.json()
            offer = RTCSessionDescription(
                sdp=params["sdp"],
                type=params["type"],
            )
        except Exception as e:
            return web.json_response(
                {
                    "success": False,
                    "error": f"解析 offer 失败: {repr(e)}",
                },
                status=400,
            )

        # 如果该 camera 已经有旧连接，先关闭旧连接
        old_pc = self.camera_pc_map.get(camera_name)
        if old_pc is not None:
            await old_pc.close()
            self.pcs.discard(old_pc)
            self.ros_node.get_logger().warn(
                f"[{camera_name}] 检测到旧连接，已关闭旧 WebRTC 连接"
            )

        pc = RTCPeerConnection()
        self.pcs.add(pc)
        self.camera_pc_map[camera_name] = pc

        # 如果客户端还推了音频，这里丢弃即可
        media_blackhole = MediaBlackhole()

        self.ros_node.get_logger().info(f"[{camera_name}] 新 WebRTC 连接创建")

        @pc.on("connectionstatechange")
        async def on_connectionstatechange():
            state = pc.connectionState
            self.ros_node.get_logger().info(
                f"[{camera_name}] WebRTC connection state: {state}"
            )

            if state in ("failed", "closed", "disconnected"):
                await pc.close()
                self.pcs.discard(pc)

                if self.camera_pc_map.get(camera_name) is pc:
                    self.camera_pc_map.pop(camera_name, None)

                self.ros_node.get_logger().warn(
                    f"[{camera_name}] WebRTC 连接已关闭/断开"
                )

        @pc.on("track")
        def on_track(track):
            self.ros_node.get_logger().info(
                f"[{camera_name}] 收到 track: kind={track.kind}"
            )

            if track.kind == "video":
                asyncio.create_task(self._consume_video_track(camera_name, track))
            else:
                media_blackhole.addTrack(track)
                asyncio.create_task(media_blackhole.start())

            @track.on("ended")
            async def on_ended():
                self.ros_node.get_logger().warn(
                    f"[{camera_name}] track ended: kind={track.kind}"
                )

        # 标准 WebRTC 应答流程
        await pc.setRemoteDescription(offer)
        answer = await pc.createAnswer()
        await pc.setLocalDescription(answer)

        answer_sdp, removed_count = sanitize_android_recvonly_answer_sdp(
            pc.localDescription.sdp
        )
        if removed_count:
            self.ros_node.get_logger().info(
                f"[{camera_name}] 已清理 answer SDP 中 {removed_count} 行 "
                "recvonly 发送端属性"
            )

        return web.json_response(
            {
                "sdp": answer_sdp,
                "type": pc.localDescription.type,
            }
        )

    async def _consume_video_track(self, camera_name: str, track):
        """
        持续从 WebRTC video track 中取帧，然后发布到 ROS2。
        """
        self.ros_node.get_logger().info(f"[{camera_name}] 开始接收视频帧")

        frame_count = 0

        while True:
            try:
                frame = await track.recv()

                # aiortc/av 的 VideoFrame 转 OpenCV BGR
                img_bgr = frame.to_ndarray(format="bgr24")

                self.ros_node.publish_frame(camera_name, img_bgr)

                frame_count += 1
                if frame_count % 100 == 0:
                    h, w = img_bgr.shape[:2]
                    self.ros_node.get_logger().info(
                        f"[{camera_name}] 已发布 {frame_count} 帧, size={w}x{h}"
                    )

            except asyncio.CancelledError:
                self.ros_node.get_logger().warn(
                    f"[{camera_name}] 视频接收任务取消"
                )
                break

            except Exception as e:
                self.ros_node.get_logger().error(
                    f"[{camera_name}] 视频接收异常: {repr(e)}"
                )
                break

    async def close_all(self):
        """
        关闭所有 WebRTC 连接。
        """
        self.ros_node.get_logger().info("[SHUTDOWN] 正在关闭所有 WebRTC 连接...")

        close_tasks = []
        for pc in list(self.pcs):
            close_tasks.append(pc.close())

        if close_tasks:
            await asyncio.gather(*close_tasks)

        self.pcs.clear()
        self.camera_pc_map.clear()


async def main_async():
    rclpy.init()

    ros_node = WebRTCToRos2Node()
    webrtc_server = WebRTCServer(ros_node)

    app = web.Application()

    # 健康检查接口
    async def health(request):
        return web.json_response(
            {
                "success": True,
                "message": "WebRTC ROS2 server is running",
                "port": PORT,
                "cameras": {
                    name: {
                        "offer_url": f"/offer/{name}",
                        "topic": cfg["topic"],
                    }
                    for name, cfg in CAMERA_CONFIG.items()
                },
            }
        )

    app.router.add_get("/", health)
    app.router.add_get("/health", health)

    # 四路 WebRTC offer 地址
    app.router.add_post("/offer/{camera_name}", webrtc_server.offer)

    runner = web.AppRunner(app)
    await runner.setup()

    site = web.TCPSite(runner, HOST, PORT)
    await site.start()

    ros_node.get_logger().info("======================================")
    ros_node.get_logger().info(f"WebRTC ROS2 Server 已启动: {HOST}:{PORT}")
    ros_node.get_logger().info("四路推流地址:")
    for name, cfg in CAMERA_CONFIG.items():
        ros_node.get_logger().info(f"  POST /offer/{name}  ->  {cfg['topic']}")
    ros_node.get_logger().info("======================================")

    stop_event = asyncio.Event()

    def ask_exit():
        ros_node.get_logger().warn("[SHUTDOWN] 收到退出信号")
        stop_event.set()

    loop = asyncio.get_running_loop()

    for sig in (signal.SIGINT, signal.SIGTERM):
        try:
            loop.add_signal_handler(sig, ask_exit)
        except NotImplementedError:
            pass

    try:
        # rclpy 不需要 spin 才能 publish，这里保持 aiohttp + aiortc 主循环即可
        await stop_event.wait()

    finally:
        await webrtc_server.close_all()
        await runner.cleanup()

        ros_node.destroy_node()
        rclpy.shutdown()


def main():
    asyncio.run(main_async())


if __name__ == "__main__":
    main()

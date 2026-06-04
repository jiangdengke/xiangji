#!/usr/bin/env python3
"""Minimal WHIP receiver for the Xiangji Flutter publisher.

这个入口只负责命令行参数和服务启动。WHIP 路由和 WebRTC 会话管理分别在
whip_receiver_app.py 与 whip_receiver_sessions.py 中，方便按职责维护。

Run:
    pip install -r examples/requirements-whip-receiver.txt
    python examples/whip_receiver.py --host 0.0.0.0 --port 8080

Set the app endpoint to:
    http://<server-ip>:8080/offer

When multiple cameras are selected, the app appends each stream ID:
    http://<server-ip>:8080/offer/camera-001-01
    http://<server-ip>:8080/offer/camera-001-02
"""

from __future__ import annotations

import argparse

from aiohttp import web

from whip_receiver_app import build_app


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Minimal WHIP receiver")
    parser.add_argument("--host", default="0.0.0.0")
    parser.add_argument("--port", default=8080, type=int)
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    print(f"Listening on http://{args.host}:{args.port}/offer")
    web.run_app(build_app(), host=args.host, port=args.port)


if __name__ == "__main__":
    main()

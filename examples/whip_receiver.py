#!/usr/bin/env python3
"""Minimal WHIP receiver for the Xiangji Flutter publisher.

Run:
    pip install aiohttp aiortc
    python examples/whip_receiver.py --host 0.0.0.0 --port 8080

Set the app endpoint to:
    http://<server-ip>:8080/whip/camera-001
"""

from __future__ import annotations

import argparse
import asyncio
import contextlib
import uuid
from dataclasses import dataclass, field
from typing import Dict, List

from aiohttp import web
from aiortc import RTCPeerConnection, RTCSessionDescription
from aiortc.mediastreams import MediaStreamError, MediaStreamTrack


@dataclass
class WhipSession:
    stream_id: str
    peer_connection: RTCPeerConnection
    tasks: List[asyncio.Task[None]] = field(default_factory=list)


sessions: Dict[str, WhipSession] = {}


async def receive_track(stream_id: str, track: MediaStreamTrack) -> None:
    count = 0
    try:
        while True:
            frame = await track.recv()
            count += 1
            if track.kind == "video" and count % 30 == 0:
                print(
                    f"[{stream_id}] received {count} video frames, "
                    f"last={frame.width}x{frame.height}"
                )
            elif track.kind != "video" and count % 100 == 0:
                print(f"[{stream_id}] received {count} {track.kind} frames")
    except MediaStreamError:
        print(f"[{stream_id}] {track.kind} track ended after {count} frames")


async def close_session(session_id: str) -> None:
    session = sessions.pop(session_id, None)
    if session is None:
        return

    for task in session.tasks:
        task.cancel()
    for task in session.tasks:
        with contextlib.suppress(asyncio.CancelledError):
            await task

    await session.peer_connection.close()
    print(f"[{session.stream_id}] closed WHIP session {session_id}")


async def create_whip_session(request: web.Request) -> web.Response:
    stream_id = request.match_info["stream_id"]
    header_stream_id = request.headers.get("X-Stream-Id")
    if header_stream_id:
        stream_id = header_stream_id

    offer_sdp = await request.text()
    if not offer_sdp.strip():
        return web.Response(status=400, text="Missing SDP offer")

    session_id = uuid.uuid4().hex
    peer_connection = RTCPeerConnection()
    session = WhipSession(stream_id=stream_id, peer_connection=peer_connection)
    sessions[session_id] = session

    @peer_connection.on("connectionstatechange")
    async def on_connectionstatechange() -> None:
        state = peer_connection.connectionState
        print(f"[{stream_id}] connection state: {state}")
        if state in {"failed", "closed"}:
            await close_session(session_id)

    @peer_connection.on("track")
    def on_track(track: MediaStreamTrack) -> None:
        print(f"[{stream_id}] track received: {track.kind}")
        task = asyncio.create_task(receive_track(stream_id, track))
        session.tasks.append(task)

    try:
        offer = RTCSessionDescription(sdp=offer_sdp, type="offer")
        await peer_connection.setRemoteDescription(offer)
        answer = await peer_connection.createAnswer()
        await peer_connection.setLocalDescription(answer)
    except Exception:
        await close_session(session_id)
        raise

    resource_path = f"/whip/{stream_id}/{session_id}"
    print(f"[{stream_id}] created WHIP session {session_id}")
    return web.Response(
        status=201,
        text=peer_connection.localDescription.sdp,
        content_type="application/sdp",
        headers={"Location": resource_path},
    )


async def delete_whip_session(request: web.Request) -> web.Response:
    session_id = request.match_info["session_id"]
    if session_id not in sessions:
        return web.Response(status=404, text="WHIP session not found")

    await close_session(session_id)
    return web.Response(status=200, text="OK")


async def health(_: web.Request) -> web.Response:
    return web.json_response({"ok": True, "sessions": len(sessions)})


async def cleanup(_: web.Application) -> None:
    for session_id in list(sessions):
        await close_session(session_id)


def build_app() -> web.Application:
    app = web.Application()
    app.router.add_get("/health", health)
    app.router.add_post("/whip/{stream_id}", create_whip_session)
    app.router.add_delete("/whip/{stream_id}/{session_id}", delete_whip_session)
    app.on_cleanup.append(cleanup)
    return app


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Minimal WHIP receiver")
    parser.add_argument("--host", default="0.0.0.0")
    parser.add_argument("--port", default=8080, type=int)
    return parser.parse_args()


if __name__ == "__main__":
    args = parse_args()
    print(f"Listening on http://{args.host}:{args.port}/whip/camera-001")
    web.run_app(build_app(), host=args.host, port=args.port)

from __future__ import annotations

import asyncio
import uuid
from typing import Optional

from aiohttp import web
from aiortc import RTCPeerConnection, RTCSessionDescription
from aiortc.mediastreams import MediaStreamTrack

from whip_receiver_sessions import WhipSessionRegistry, receive_track


class WhipReceiverHandlers:
    """aiohttp handlers for the demo WHIP receiver."""

    def __init__(self, sessions: WhipSessionRegistry) -> None:
        self._sessions = sessions

    async def create_whip_session(self, request: web.Request) -> web.Response:
        stream_id = _stream_id_from_request(request)
        offer_sdp = await request.text()
        if not offer_sdp.strip():
            return web.Response(status=400, text="Missing SDP offer")

        session_id = uuid.uuid4().hex
        peer_connection = RTCPeerConnection()
        session = self._sessions.create(
            session_id=session_id,
            stream_id=stream_id,
            peer_connection=peer_connection,
        )

        @peer_connection.on("connectionstatechange")
        async def on_connectionstatechange() -> None:
            state = peer_connection.connectionState
            print(f"[{stream_id}] connection state: {state}")
            if state in {"failed", "closed"}:
                await self._sessions.close(session_id)

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
            await self._sessions.close(session_id)
            raise

        resource_path = f"/whip/{stream_id}/{session_id}"
        print(f"[{stream_id}] created WHIP session {session_id}")
        return web.Response(
            status=201,
            text=peer_connection.localDescription.sdp,
            content_type="application/sdp",
            headers={"Location": resource_path},
        )

    async def delete_whip_session(self, request: web.Request) -> web.Response:
        session_id = request.match_info["session_id"]
        if not self._sessions.has(session_id):
            return web.Response(status=404, text="WHIP session not found")

        await self._sessions.close(session_id)
        return web.Response(status=200, text="OK")

    async def health(self, _: web.Request) -> web.Response:
        return web.json_response({"ok": True, "sessions": self._sessions.count})

    async def cleanup(self, _: web.Application) -> None:
        await self._sessions.close_all()


def build_app(sessions: Optional[WhipSessionRegistry] = None) -> web.Application:
    registry = sessions or WhipSessionRegistry()
    handlers = WhipReceiverHandlers(registry)
    app = web.Application()

    app.router.add_get("/health", handlers.health)
    app.router.add_post("/whip/{stream_id}", handlers.create_whip_session)
    app.router.add_post("/offer/{stream_id}", handlers.create_whip_session)
    app.router.add_delete(
        "/whip/{stream_id}/{session_id}",
        handlers.delete_whip_session,
    )
    app.router.add_delete(
        "/offer/{stream_id}/{session_id}",
        handlers.delete_whip_session,
    )
    app.on_cleanup.append(handlers.cleanup)
    return app


def _stream_id_from_request(request: web.Request) -> str:
    header_stream_id = request.headers.get("X-Stream-Id")
    if header_stream_id:
        return header_stream_id
    return request.match_info["stream_id"]

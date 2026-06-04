from __future__ import annotations

import asyncio
import contextlib
from dataclasses import dataclass, field
from typing import Dict, List, Optional

from aiortc import RTCPeerConnection
from aiortc.mediastreams import MediaStreamError, MediaStreamTrack


@dataclass
class WhipSession:
    """Runtime state for one WHIP/WebRTC session."""

    stream_id: str
    peer_connection: RTCPeerConnection
    tasks: List[asyncio.Task[None]] = field(default_factory=list)


class WhipSessionRegistry:
    """In-memory WHIP session registry for the demo receiver."""

    def __init__(self) -> None:
        self._sessions: Dict[str, WhipSession] = {}

    @property
    def count(self) -> int:
        return len(self._sessions)

    def has(self, session_id: str) -> bool:
        return session_id in self._sessions

    def create(
        self,
        session_id: str,
        stream_id: str,
        peer_connection: RTCPeerConnection,
    ) -> WhipSession:
        session = WhipSession(
            stream_id=stream_id,
            peer_connection=peer_connection,
        )
        self._sessions[session_id] = session
        return session

    async def close(self, session_id: str) -> None:
        session = self._sessions.pop(session_id, None)
        if session is None:
            return

        for task in session.tasks:
            task.cancel()
        for task in session.tasks:
            with contextlib.suppress(asyncio.CancelledError):
                await task

        await session.peer_connection.close()
        print(f"[{session.stream_id}] closed WHIP session {session_id}")

    async def close_all(self) -> None:
        for session_id in list(self._sessions):
            await self.close(session_id)

    def get(self, session_id: str) -> Optional[WhipSession]:
        return self._sessions.get(session_id)


async def receive_track(stream_id: str, track: MediaStreamTrack) -> None:
    """Read media frames from a WebRTC track and print lightweight progress."""

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

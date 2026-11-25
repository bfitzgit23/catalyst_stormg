"""Async fan-out event bus. No polling: publishers push, subscribers await."""
from __future__ import annotations

import asyncio
import time
from collections.abc import AsyncIterator


class EventBus:
    def __init__(self, queue_size: int = 512) -> None:
        self._queue_size = queue_size
        self._subscribers: set[asyncio.Queue] = set()
        self._lock = asyncio.Lock()
        self._recent: list[dict] = []

    async def publish(self, topic: str, data: dict) -> None:
        message = {"topic": topic, "data": data, "ts": round(time.time(), 3)}
        self._recent.append(message)
        if len(self._recent) > 200:
            self._recent.pop(0)
        for queue in tuple(self._subscribers):
            try:
                queue.put_nowait(message)
            except asyncio.QueueFull:
                # Slow consumer: drop the oldest frame, never block a producer.
                try:
                    queue.get_nowait()
                    queue.put_nowait(message)
                except (asyncio.QueueEmpty, asyncio.QueueFull):
                    pass

    async def subscribe(self) -> AsyncIterator[dict]:
        queue: asyncio.Queue = asyncio.Queue(maxsize=self._queue_size)
        async with self._lock:
            self._subscribers.add(queue)
        try:
            while True:
                yield await queue.get()
        finally:
            async with self._lock:
                self._subscribers.discard(queue)

    @property
    def recent(self) -> list[dict]:
        return list(self._recent)

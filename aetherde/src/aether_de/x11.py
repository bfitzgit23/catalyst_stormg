"""Event-driven EWMH/ICCCM tracker built on python-xlib.

A dedicated thread blocks in Display.next_event() and forwards only X11 property
and structure notifications to the asyncio world. There is no polling loop for
window or notification state.
"""
from __future__ import annotations

import asyncio
import base64
import logging
import os
import struct
import threading
import zlib
from typing import Any

from Xlib import X, Xatom, display
from Xlib.protocol import event as xevent

from .events import EventBus
from .models import Window

LOG = logging.getLogger("aether.x11")

ATOMS = (
    "_NET_SUPPORTING_WM_CHECK",
    "_NET_CLIENT_LIST",
    "_NET_ACTIVE_WINDOW",
    "_NET_NUMBER_OF_DESKTOPS",
    "_NET_CURRENT_DESKTOP",
    "_NET_DESKTOP_NAMES",
    "_NET_WM_STATE",
    "_NET_WM_STATE_HIDDEN",
    "_NET_WM_STATE_MAXIMIZED_VERT",
    "_NET_WM_STATE_MAXIMIZED_HORZ",
    "_NET_WM_STATE_FULLSCREEN",
    "_NET_WM_NAME",
    "_NET_WM_CLASS",
    "_NET_WM_PID",
    "_NET_WM_ICON",
    "_NET_WM_WINDOW_TYPE",
    "_NET_WM_DESKTOP",
    "_NET_CLOSE_WINDOW",
    "WM_NAME",
    "WM_CHANGE_STATE",
    "_AETHER_WAKE",
)


def _png_chunk(tag: bytes, payload: bytes) -> bytes:
    return (
        struct.pack(">I", len(payload))
        + tag
        + payload
        + struct.pack(">I", zlib.crc32(tag + payload) & 0xFFFFFFFF)
    )


def argb_to_png_data_uri(width: int, height: int, argb: list[int] | tuple[int, ...]) -> str:
    """Encode a _NET_WM_ICON ARGB array as a PNG data URI without PIL."""
    rows = bytearray()
    for y in range(height):
        rows.append(0)  # PNG filter type 0 (None)
        base = y * width
        for x in range(width):
            px = int(argb[base + x]) & 0xFFFFFFFF
            a = (px >> 24) & 0xFF
            r = (px >> 16) & 0xFF
            g = (px >> 8) & 0xFF
            b = px & 0xFF
            rows.extend((r, g, b, a))
    ihdr = struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0)
    png = (
        b"\x89PNG\r\n\x1a\n"
        + _png_chunk(b"IHDR", ihdr)
        + _png_chunk(b"IDAT", zlib.compress(bytes(rows), 6))
        + _png_chunk(b"IEND", b"")
    )
    return "data:image/png;base64," + base64.b64encode(png).decode("ascii")


class X11Tracker:
    """Bridges X11 window state into the async application via an EventBus."""

    def __init__(self, bus: EventBus, loop: asyncio.AbstractEventLoop) -> None:
        self.bus = bus
        self.loop = loop
        self.display: Any = None
        self.root: Any = None
        self.atom: dict[str, int] = {}
        self._thread: threading.Thread | None = None
        self._stop = threading.Event()
        self._managed: dict[int, bool] = {}
        self._snapshot: dict[str, Any] = {"windows": [], "workspaces": {}, "active": None}

    # ---------------------------------------------------------------- lifecycle
    def start(self) -> None:
        self.display = display.Display()
        self.display.sync()
        self.root = self.display.screen().root
        self.atom = {name: self.display.intern_atom(name) for name in ATOMS}
        self.root.change_attributes(
            event_mask=X.PropertyChangeMask
            | X.SubstructureNotifyMask
            | X.StructureNotifyMask
        )
        self.display.sync()
        self._refresh(publish=False)
        self._thread = threading.Thread(target=self._run, name="aether-x11", daemon=True)
        self._thread.start()
        LOG.info("X11 tracker listening on %s", os.environ.get("DISPLAY", ":0"))

    def stop(self) -> None:
        self._stop.set()
        threading.Thread(target=self._poke, name="aether-x11-wake", daemon=True).start()
        if self._thread is not None:
            self._thread.join(timeout=2)
        try:
            if self.display is not None:
                self.display.close()
        except Exception:
            pass

    def _poke(self) -> None:
        """Wake a blocked next_event() with a synthetic client message."""
        try:
            d = display.Display()
            r = d.screen().root
            atom = d.intern_atom("_AETHER_WAKE")
            msg = xevent.ClientMessage(
                window=r, client_type=atom, data=(32, [0, 0, 0, 0, 0])
            )
            r.send_event(
                msg, event_mask=X.SubstructureRedirectMask | X.SubstructureNotifyMask
            )
            d.sync()
            d.close()
        except Exception as exc:
            LOG.debug("wake message failed: %s", exc)

    def _run(self) -> None:
        while not self._stop.is_set():
            try:
                event = self.display.next_event()
            except Exception as exc:
                if self._stop.is_set():
                    break
                LOG.debug("next_event: %s", exc)
                continue
            try:
                self._handle_event(event)
            except Exception as exc:
                LOG.exception("X11 event handling failed: %s", exc)

    # ------------------------------------------------------------- event filter
    def _handle_event(self, event: Any) -> None:
        etype = event.type
        if etype == X.PropertyNotify:
            if event.window == self.root:
                if event.atom in (
                    self.atom["_NET_CLIENT_LIST"],
                    self.atom["_NET_ACTIVE_WINDOW"],
                    self.atom["_NET_NUMBER_OF_DESKTOPS"],
                    self.atom["_NET_CURRENT_DESKTOP"],
                    self.atom["_NET_DESKTOP_NAMES"],
                ):
                    self._refresh(publish=True)
            elif getattr(event.window, "id", None) in self._managed:
                if event.atom == self.atom["_NET_WM_STATE"]:
                    self._refresh(publish=True)
        elif etype in (X.MapNotify, X.UnmapNotify, X.DestroyNotify, X.ConfigureNotify):
            self._refresh(publish=True)

    # ------------------------------------------------------------ X property IO
    def _prop(self, window: Any, name: str) -> Any:
        atom = self.atom.get(name)
        if atom is None:
            return None
        try:
            prop = window.get_full_property(atom, Xatom.AnyPropertyType)
        except Exception:
            return None
        return prop.value if prop else None

    def _text(self, window: Any, name: str) -> str:
        value = self._prop(window, name)
        if value is None:
            return ""
        if isinstance(value, bytes):
            return value.decode("utf-8", "replace")
        if isinstance(value, (list, tuple)) and value:
            first = value[0]
            if isinstance(first, bytes):
                return first.decode("utf-8", "replace")
            return str(first)
        return str(value)

    def _atom_name(self, atom_id: int) -> str:
        try:
            name = self.display.get_atom_name(int(atom_id))
        except Exception:
            return ""
        if isinstance(name, bytes):
            return name.decode("utf-8", "replace")
        return str(name or "")

    def _icon(self, window: Any) -> str | None:
        raw = self._prop(window, "_NET_WM_ICON")
        if not raw or not isinstance(raw, (list, tuple)):
            return None
        index = 0
        best: tuple[int, int, list[int] | tuple[int, ...]] | None = None
        total = len(raw)
        while index + 2 <= total:
            w = int(raw[index])
            h = int(raw[index + 1])
            index += 2
            count = w * h
            if w <= 0 or h <= 0 or count > 1 << 22 or index + count > total:
                break
            data = raw[index : index + count]
            index += count
            if best is None or count > best[0] * best[1]:
                best = (w, h, data)
        if best is None:
            return None
        return argb_to_png_data_uri(best[0], best[1], best[2])

    def _window_info(self, wid: int) -> Window:
        window = self.display.create_resource_object("window", wid)
        klass = self._prop(window, "_NET_WM_CLASS") or ("", "")
        if isinstance(klass, (list, tuple)) and len(klass) >= 2:
            class_part = klass[1]
        else:
            class_part = klass[0] if klass else ""
        if isinstance(class_part, bytes):
            class_part = class_part.decode("utf-8", "replace")
        states = [
            self._atom_name(a) for a in (self._prop(window, "_NET_WM_STATE") or ())
        ]
        types = [
            self._atom_name(a)
            for a in (self._prop(window, "_NET_WM_WINDOW_TYPE") or ())
        ]
        desktop = self._prop(window, "_NET_WM_DESKTOP")
        pid = self._prop(window, "_NET_WM_PID")
        try:
            geometry = window.get_geometry()
            geom = {
                "x": int(geometry.x),
                "y": int(geometry.y),
                "width": int(geometry.width),
                "height": int(geometry.height),
            }
        except Exception:
            geom = {"x": 0, "y": 0, "width": 0, "height": 0}
        return Window(
            id=int(wid),
            name=self._text(window, "_NET_WM_NAME") or self._text(window, "WM_NAME"),
            wm_class=str(class_part),
            pid=int(pid) if pid else None,
            desktop=int(desktop) if desktop is not None else 0,
            states=states,
            window_type=types,
            geometry=geom,
            icon=self._icon(window),
        )

    def _desktops(self) -> dict[str, Any]:
        count = self._prop(self.root, "_NET_NUMBER_OF_DESKTOP") or 1
        current = self._prop(self.root, "_NET_CURRENT_DESKTOP") or 0
        names = self._prop(self.root, "_NET_DESKTOP_NAMES") or []
        decoded = [
            n.decode("utf-8", "replace") if isinstance(n, bytes) else str(n)
            for n in (names if isinstance(names, (list, tuple)) else [names])
        ]
        return {
            "count": int(count),
            "current": int(current),
            "names": decoded,
        }

    def _refresh(self, publish: bool = True) -> dict[str, Any]:
        client_ids = self._prop(self.root, "_NET_CLIENT_LIST") or ()
        windows: list[Window] = []
        for wid in client_ids:
            try:
                windows.append(self._window_info(int(wid)))
            except Exception as exc:
                LOG.debug("skipping window %s: %s", wid, exc)
        live = {w.id for w in windows}
        for wid in live - set(self._managed):
            try:
                obj = self.display.create_resource_object("window", wid)
                obj.change_attributes(
                    event_mask=X.PropertyChangeMask | X.StructureNotifyMask
                )
            except Exception:
                pass
            self._managed[wid] = True
        for wid in set(self._managed) - live:
            self._managed.pop(wid, None)
        active = self._prop(self.root, "_NET_ACTIVE_WINDOW")
        snapshot = {
            "windows": [w.to_dict() for w in windows],
            "workspaces": self._desktops(),
            "active": int(active) if active else None,
        }
        self._snapshot = snapshot
        if publish:
            self._emit("windows", snapshot)
        return snapshot

    def _emit(self, topic: str, data: dict[str, Any]) -> None:
        try:
            self.loop.call_soon_threadsafe(
                lambda: asyncio.create_task(self.bus.publish(topic, data))
            )
        except RuntimeError:
            pass

    def _client_message(
        self, message: str, target: Any, data: list[int], window: Any | None = None
    ) -> None:
        payload = list(data) + [0] * (5 - len(data))
        event = xevent.ClientMessage(
            window=window or self.root,
            client_type=self.atom[message],
            data=(32, payload[:5]),
        )
        self.root.send_event(
            event, event_mask=X.SubstructureRedirectMask | X.SubstructureNotifyMask
        )
        self.display.sync()

    # ------------------------------------------------------------ public API
    async def snapshot(self) -> dict[str, Any]:
        return await asyncio.to_thread(self._refresh, False)

    async def focus(self, wid: int) -> bool:
        def action() -> bool:
            self._client_message("_NET_ACTIVE_WINDOW", self.root, [1, 0, int(wid), 0, 0])
            return True

        return await asyncio.to_thread(action)

    async def minimize(self, wid: int) -> bool:
        def action() -> bool:
            target = self.display.create_resource_object("window", int(wid))
            message = xevent.ClientMessage(
                window=target,
                client_type=self.atom["WM_CHANGE_STATE"],
                data=(32, [1, 0, 0, 0, 0]),  # ICCCM IconicState
            )
            self.root.send_event(
                message,
                event_mask=X.SubstructureRedirectMask | X.SubstructureNotifyMask,
            )
            self.display.sync()
            return True

        return await asyncio.to_thread(action)

    async def maximize(self, wid: int) -> bool:
        def action() -> bool:
            self._client_message(
                "_NET_WM_STATE",
                self.root,
                [
                    1,
                    self.atom["_NET_WM_STATE_MAXIMIZED_VERT"],
                    self.atom["_NET_WM_STATE_MAXIMIZED_HORZ"],
                    0,
                    0,
                ],
            )
            return True

        return await asyncio.to_thread(action)

    async def close(self, wid: int) -> bool:
        def action() -> bool:
            target = self.display.create_resource_object("window", int(wid))
            self._client_message("_NET_CLOSE_WINDOW", self.root, [0, 0, 0, 0, 0], target)
            return True

        return await asyncio.to_thread(action)

    async def set_desktop(self, number: int) -> bool:
        def action() -> bool:
            self._client_message("_NET_CURRENT_DESKTOP", self.root, [int(number), 0, 0, 0, 0])
            return True

        return await asyncio.to_thread(action)

    async def move_to_desktop(self, wid: int, number: int) -> bool:
        def action() -> bool:
            target = self.display.create_resource_object("window", int(wid))
            self._client_message("_NET_WM_DESKTOP", target, [int(number), 0, 0, 0, 0])
            return True

        return await asyncio.to_thread(action)

"""D-Bus integration: notifications, NetworkManager signals and audio control."""
from __future__ import annotations

import asyncio
import logging
import re
from typing import Any

from dbus_next import BusType, Message, MessageType, NameFlag
from dbus_next.aio import MessageBus
from dbus_next.service import ServiceInterface, method

from .events import EventBus
from .models import NetworkStatus, Notification, Volume

LOG = logging.getLogger("aether.dbus")

NM_STATES = {
    0: "Unknown",
    1: "Asleep",
    2: "Disconnected",
    3: "Connecting",
    4: "Connected",
    5: "Disconnecting",
}


class NotificationsService(ServiceInterface):
    """Implements org.freedesktop.Notifications and forwards every Notify call."""

    def __init__(self, events: EventBus) -> None:
        super().__init__("org.freedesktop.Notifications")
        self.events = events
        self.counter = 0
        self.active: dict[int, Notification] = {}

    @method("", "as")
    def GetCapabilities(self) -> "as":
        return ["actions", "body", "body-markup", "icon-static", "persistence"]

    @method("sssusasa{sv}i", "u")
    def Notify(
        self,
        app_name: str,
        replaces_id: int,
        app_icon: str,
        summary: str,
        body: str,
        actions: list[str],
        hints: dict[str, Any],
        expire_timeout: int,
    ) -> "u":
        self.counter += 1
        ident = int(replaces_id) if replaces_id else self.counter
        note = Notification(
            id=ident,
            app_name=app_name,
            app_icon=app_icon,
            summary=summary,
            body=body,
            actions=list(actions),
            hints=dict(hints),
            expire_timeout=int(expire_timeout),
        )
        self.active[ident] = note
        asyncio.create_task(self.events.publish("notification", note.to_dict()))
        return ident

    @method("u")
    def CloseNotification(self, ident: int) -> None:
        self.active.pop(int(ident), None)
        asyncio.create_task(
            self.events.publish("notification_close", {"id": int(ident)})
        )

    @method("", "ssss")
    def GetServerInformation(self) -> "ssss":
        return ("AetherDE", "AetherDE Project", "0.1.0", "1.2")


class DbusBridge:
    def __init__(self, events: EventBus) -> None:
        self.events = events
        self.bus: MessageBus | None = None
        self._handlers: list[Any] = []
        self._audio_backend: str | None = None

    async def start(self) -> None:
        self.bus = await MessageBus(bus_type=BusType.SESSION).connect()
        service = NotificationsService(self.events)
        self.bus.export("/org/freedesktop/Notifications", service)
        try:
            await self.bus.request_name(
                "org.freedesktop.Notifications", flags=NameFlag.REPLACE_EXISTING
            )
            LOG.info("org.freedesktop.Notifications acquired")
        except Exception as exc:
            LOG.warning("could not own notification name: %s", exc)
        await self._watch_network()
        LOG.info("D-Bus session bridge connected")

    def stop(self) -> None:
        if self.bus is not None:
            try:
                self.bus.disconnect()
            except Exception:
                pass

    async def _watch_network(self) -> None:
        rule = (
            "type='signal',sender='org.freedesktop.NetworkManager',"
            "interface='org.freedesktop.DBus.Properties',member='PropertiesChanged'"
        )
        try:
            await self.bus.add_match_rule(rule)
        except Exception as exc:
            LOG.warning("NetworkManager match rule failed: %s", exc)

        def handler(message: Message) -> None:
            if message.message_type != MessageType.SIGNAL:
                return
            if message.interface != "org.freedesktop.DBus.Properties":
                return
            if message.member != "PropertiesChanged" or not message.body:
                return
            if message.body[0] != "org.freedesktop.NetworkManager":
                return
            changed = {
                key: (value.value if hasattr(value, "value") else value)
                for key, value in (message.body[1] or {}).items()
            }
            asyncio.create_task(
                self.events.publish("network", {"changed": changed})
            )

        self.bus.add_message_handler(handler)
        self._handlers.append(handler)

    async def _property(self, name: str) -> Any:
        try:
            reply = await self.bus.call(
                Message(
                    destination="org.freedesktop.NetworkManager",
                    path="/org/freedesktop/NetworkManager",
                    interface="org.freedesktop.DBus.Properties",
                    member="Get",
                    signature="ss",
                    body=["org.freedesktop.NetworkManager", name],
                )
            )
            value = reply.body[0]
            return value.value if hasattr(value, "value") else value
        except Exception:
            return None

    async def network_status(self) -> dict[str, Any]:
        state = await self._property("State")
        state = int(state) if state is not None else 0
        connectivity = await self._property("Connectivity")
        connections = await self._property("ActiveConnections") or []
        return NetworkStatus(
            state=state,
            state_label=NM_STATES.get(state, "Unknown"),
            connectivity=int(connectivity) if connectivity is not None else None,
            active_connections=[str(path) for path in connections],
        ).to_dict()

    # ------------------------------------------------------------------ audio
    @staticmethod
    async def _command(*args: str) -> str:
        process = await asyncio.create_subprocess_exec(
            *args,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE,
        )
        stdout, stderr = await process.communicate()
        if process.returncode != 0:
            raise RuntimeError(
                stderr.decode("utf-8", "replace").strip()
                or f"command exited {process.returncode}"
            )
        return stdout.decode("utf-8", "replace")

    async def _backend(self) -> str:
        if self._audio_backend is not None:
            return self._audio_backend
        try:
            await self._command("wpctl", "get-volume", "@DEFAULT_AUDIO_SINK@")
            self._audio_backend = "pipewire"
        except Exception:
            self._audio_backend = "pulse"
        return self._audio_backend

    async def volume(self) -> dict[str, Any]:
        backend = await self._backend()
        try:
            if backend == "pipewire":
                output = await self._command(
                    "wpctl", "get-volume", "@DEFAULT_AUDIO_SINK@"
                )
                match = re.search(r"Volume:\s*([\d.]+)", output)
                level = round(float(match.group(1)) * 100) if match else 0
                muted = "[MUTED]" in output
            else:
                output = await self._command(
                    "pactl", "get-sink-volume", "@DEFAULT_SINK@"
                )
                match = re.search(r"(\d+)%", output)
                level = int(match.group(1)) if match else 0
                mute_output = await self._command(
                    "pactl", "get-sink-mute", "@DEFAULT_SINK@"
                )
                muted = "yes" in mute_output.lower()
        except Exception as exc:
            LOG.debug("volume query failed: %s", exc)
            return Volume(level=0, muted=False, backend=backend).to_dict()
        return Volume(
            level=max(0, min(100, level)), muted=muted, backend=backend
        ).to_dict()

    async def set_volume(self, level: int) -> dict[str, Any]:
        level = max(0, min(100, int(level)))
        backend = await self._backend()
        if backend == "pipewire":
            await self._command(
                "wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", f"{level}%"
            )
        else:
            await self._command(
                "pactl", "set-sink-volume", "@DEFAULT_SINK@", f"{level}%"
            )
        result = await self.volume()
        await self.events.publish("volume", result)
        return result

    async def toggle_mute(self) -> dict[str, Any]:
        backend = await self._backend()
        if backend == "pipewire":
            await self._command("wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "toggle")
        else:
            await self._command("pactl", "set-sink-mute", "@DEFAULT_SINK@", "toggle")
        result = await self.volume()
        await self.events.publish("volume", result)
        return result

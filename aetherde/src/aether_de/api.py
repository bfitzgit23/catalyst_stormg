"""FastAPI REST + newline-delimited JSON event stream over a Unix domain socket."""
from __future__ import annotations

import asyncio
import json
import os
import shlex
from pathlib import Path
from subprocess import DEVNULL
from urllib.parse import quote

import psutil
from fastapi import Body, FastAPI, HTTPException, Request
from fastapi.responses import FileResponse, StreamingResponse

from .xdg import resolve_icon

MEDIA_TYPES = {
    ".png": "image/png",
    ".svg": "image/svg+xml",
    ".xpm": "image/x-xpixmap",
    ".jpg": "image/jpeg",
    ".jpeg": "image/jpeg",
}


def create_app(daemon) -> FastAPI:
    app = FastAPI(title="AetherDE System Bridge", docs_url=None, redoc_url=None)
    bus = daemon.bus

    @app.get("/api/health")
    async def health() -> dict:
        return {"ok": True, "service": "aether-de", "version": "0.1.0"}

    @app.get("/api/windows")
    async def windows() -> dict:
        return await daemon.x11.snapshot()

    @app.post("/api/window/{wid}/{action}")
    async def window_action(
        wid: int,
        action: str,
        payload: dict | None = Body(default=None),
    ) -> dict:
        handlers = {
            "focus": daemon.x11.focus,
            "minimize": daemon.x11.minimize,
            "maximize": daemon.x11.maximize,
            "close": daemon.x11.close,
        }
        if action == "workspace":
            if payload is None or "desktop" not in payload:
                raise HTTPException(status_code=400, detail="desktop is required")
            ok = await daemon.x11.move_to_desktop(wid, int(payload["desktop"]))
        elif action in handlers:
            ok = await handlers[action](wid)
        else:
            raise HTTPException(status_code=404, detail="unknown window action")
        return {"ok": bool(ok)}

    @app.get("/api/workspaces")
    async def workspaces() -> dict:
        snapshot = await daemon.x11.snapshot()
        return snapshot["workspaces"]

    @app.post("/api/workspace/{number}")
    async def set_workspace(number: int) -> dict:
        return {"ok": await daemon.x11.set_desktop(number)}

    @app.get("/api/apps")
    async def apps() -> dict:
        items = []
        for app in daemon.apps:
            item = dict(app)
            icon = item.get("icon")
            if icon:
                key = "path" if icon.startswith("/") else "name"
                item["icon"] = f"/api/icon?{key}={quote(icon, safe='')}"
            items.append(item)
        return {"apps": items, "categories": daemon.categories}

    @app.get("/api/icon")
    async def icon(name: str | None = None, path: str | None = None) -> FileResponse:
        target: Path | None = None
        if path:
            target = Path(path)
        elif name:
            resolved = resolve_icon(name)
            target = Path(resolved) if resolved else None
        if target is None or not target.is_file():
            raise HTTPException(status_code=404, detail="icon not found")
        return FileResponse(
            target,
            media_type=MEDIA_TYPES.get(target.suffix.lower(), "application/octet-stream"),
        )

    @app.get("/api/status")
    async def status() -> dict:
        return daemon.status()

    @app.get("/api/volume")
    async def volume() -> dict:
        return await daemon.bridge.volume()

    @app.post("/api/volume")
    async def set_volume(payload: dict) -> dict:
        if "level" not in payload:
            raise HTTPException(status_code=400, detail="level is required")
        return await daemon.bridge.set_volume(int(payload["level"]))

    @app.post("/api/mute")
    async def mute() -> dict:
        return await daemon.bridge.toggle_mute()

    @app.get("/api/network")
    async def network() -> dict:
        return await daemon.bridge.network_status()

    @app.post("/api/notification")
    async def notification(payload: dict) -> dict:
        note = {
            "id": int(payload.get("id", 0)),
            "app_name": str(payload.get("app_name", "AetherDE")),
            "app_icon": str(payload.get("app_icon", "")),
            "summary": str(payload.get("summary", "")),
            "body": str(payload.get("body", "")),
            "actions": list(payload.get("actions", [])),
            "hints": dict(payload.get("hints", {})),
            "expire_timeout": int(payload.get("expire_timeout", 0)),
        }
        await bus.publish("notification", note)
        return {"ok": True}

    @app.post("/api/launch")
    async def launch(payload: dict) -> dict:
        command = payload.get("command")
        if isinstance(command, str):
            try:
                command = json.loads(command)
            except (ValueError, TypeError):
                command = shlex.split(command)
        if not isinstance(command, list) or not command:
            raise HTTPException(
                status_code=400, detail="command must be a non-empty array"
            )
        try:
            process = await asyncio.create_subprocess_exec(
                *[str(part) for part in command],
                stdout=DEVNULL,
                stderr=DEVNULL,
                start_new_session=True,
            )
        except OSError as exc:
            raise HTTPException(status_code=500, detail=str(exc)) from exc
        return {"ok": True, "pid": process.pid}

    @app.get("/api/events")
    async def events(request: Request) -> StreamingResponse:
        async def stream():
            async for message in bus.subscribe():
                if await request.is_disconnected():
                    break
                yield json.dumps(
                    message, separators=(",", ":"), ensure_ascii=False
                ) + "\n"

        return StreamingResponse(
            stream(),
            media_type="application/x-ndjson",
            headers={"Cache-Control": "no-cache", "X-Accel-Buffering": "no"},
        )

    return app

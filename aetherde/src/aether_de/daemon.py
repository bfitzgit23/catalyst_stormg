"""AetherDE async system daemon: X11 + D-Bus bridge behind a FastAPI UDS server."""
from __future__ import annotations

import argparse
import asyncio
import logging
import os
import signal
import time
from pathlib import Path

import psutil
import uvicorn

from .api import create_app
from .config import Config
from .dbus import DbusBridge
from .events import EventBus
from .xdg import CATEGORY_LABELS, scan_applications
from .x11 import X11Tracker

LOG = logging.getLogger("aether.daemon")


class Daemon:
    def __init__(
        self,
        config: Config,
        bus: EventBus,
        x11: X11Tracker,
        bridge: DbusBridge,
        apps: list[dict],
    ) -> None:
        self.config = config
        self.bus = bus
        self.x11 = x11
        self.bridge = bridge
        self.apps = apps
        self.categories = CATEGORY_LABELS
        self.history: list[dict] = []

    async def metrics_loop(self) -> None:
        while True:
            cpu = psutil.cpu_percent(interval=None)
            memory = psutil.virtual_memory()
            self.history.append(
                {"cpu": round(cpu, 1), "ram": round(memory.percent, 1), "ts": time.time()}
            )
            if len(self.history) > self.config.metric_samples:
                self.history.pop(0)
            load = os.getloadavg()[0] if hasattr(os, "getloadavg") else 0.0
            await self.bus.publish(
                "metrics",
                {
                    "cpu": cpu,
                    "ram": memory.percent,
                    "load": round(load, 2),
                    "history": list(self.history),
                },
            )
            await asyncio.sleep(1)

    def status(self) -> dict:
        memory = psutil.virtual_memory()
        load = os.getloadavg()[0] if hasattr(os, "getloadavg") else 0.0
        return {
            "cpu": psutil.cpu_percent(interval=None),
            "ram": memory.percent,
            "ram_used": memory.used,
            "ram_total": memory.total,
            "load": round(load, 2),
            "uptime": time.time() - psutil.boot_time(),
            "history": list(self.history),
        }


async def amain(config: Config) -> None:
    logging.basicConfig(
        level=getattr(logging, config.log_level.upper(), logging.INFO),
        format="%(asctime)s %(levelname)s %(name)s: %(message)s",
    )
    loop = asyncio.get_running_loop()
    bus = EventBus(config.event_queue_size)

    x11 = X11Tracker(bus, loop)
    x11.start()

    bridge = DbusBridge(bus)
    await bridge.start()

    apps = await asyncio.to_thread(scan_applications)
    LOG.info("parsed %d applications", len(apps))

    daemon = Daemon(config, bus, x11, bridge, apps)
    app = create_app(daemon)
    server = uvicorn.Server(
        uvicorn.Config(
            app,
            uds=config.socket,
            log_level="warning",
            access_log=False,
            lifespan="off",
        )
    )
    server.install_signal_handlers = lambda: None  # own the signal handlers here

    stop = asyncio.Event()
    for sig in (signal.SIGTERM, signal.SIGINT, signal.SIGHUP):
        try:
            loop.add_signal_handler(sig, stop.set)
        except NotImplementedError:
            pass

    metrics = asyncio.create_task(daemon.metrics_loop())
    serving = asyncio.create_task(server.serve())
    await asyncio.wait([serving, stop.wait()], return_when=asyncio.FIRST_COMPLETED)

    server.should_exit = True
    try:
        await asyncio.wait_for(serving, timeout=5)
    except (asyncio.TimeoutError, asyncio.CancelledError):
        serving.cancel()
    metrics.cancel()

    bridge.stop()
    x11.stop()
    try:
        Path(config.socket).unlink(missing_ok=True)
    except OSError:
        pass
    LOG.info("daemon stopped cleanly")


def main() -> None:
    parser = argparse.ArgumentParser(prog="aether-de-daemon")
    parser.add_argument(
        "--socket",
        default=os.environ.get("AETHER_SOCKET", "/tmp/aether-sys.sock"),
        help="path of the Unix domain socket exposed to the Node gateway",
    )
    options = parser.parse_args()
    asyncio.run(amain(Config(socket=options.socket)))


if __name__ == "__main__":
    main()

"""Runtime configuration for the AetherDE system bridge."""
from __future__ import annotations

import os
from dataclasses import dataclass, field


@dataclass(slots=True)
class Config:
    socket: str = field(
        default_factory=lambda: os.environ.get("AETHER_SOCKET", "/tmp/aether-sys.sock")
    )
    metric_samples: int = 60
    icon_size: int = 48
    event_queue_size: int = 512
    locale: str = field(default_factory=lambda: os.environ.get("LANG", "C.UTF-8"))
    log_level: str = field(default_factory=lambda: os.environ.get("AETHER_LOG", "INFO"))

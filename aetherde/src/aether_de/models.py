"""Wire-format data models shared by the Python bridge and the Node gateway."""
from __future__ import annotations

from dataclasses import asdict, dataclass, field
from typing import Any


@dataclass(slots=True)
class Window:
    id: int
    name: str
    wm_class: str
    pid: int | None
    desktop: int
    states: list[str] = field(default_factory=list)
    window_type: list[str] = field(default_factory=list)
    geometry: dict[str, int] = field(default_factory=dict)
    icon: str | None = None

    def to_dict(self) -> dict[str, Any]:
        return asdict(self)


@dataclass(slots=True)
class AppEntry:
    id: str
    name: str
    generic_name: str
    comment: str
    exec: str
    icon: str
    categories: list[str] = field(default_factory=list)
    terminal: bool = False
    only_show_in: list[str] = field(default_factory=list)

    def to_dict(self) -> dict[str, Any]:
        return asdict(self)


@dataclass(slots=True)
class Notification:
    id: int
    app_name: str
    app_icon: str
    summary: str
    body: str
    actions: list[str] = field(default_factory=list)
    hints: dict[str, Any] = field(default_factory=dict)
    expire_timeout: int = 0

    def to_dict(self) -> dict[str, Any]:
        return asdict(self)


@dataclass(slots=True)
class NetworkStatus:
    state: int
    state_label: str
    connectivity: int | None = None
    active_connections: list[str] = field(default_factory=list)

    def to_dict(self) -> dict[str, Any]:
        return asdict(self)


@dataclass(slots=True)
class Volume:
    level: int
    muted: bool
    backend: str

    def to_dict(self) -> dict[str, Any]:
        return asdict(self)

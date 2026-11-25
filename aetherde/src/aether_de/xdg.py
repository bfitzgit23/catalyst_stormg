"""Freedesktop XDG application and icon parser."""
from __future__ import annotations

import configparser
import json
import os
import shlex
import shutil
from pathlib import Path

from .models import AppEntry

CATEGORY_LABELS: dict[str, str] = {
    "Development": "Development",
    "System": "System",
    "Network": "Network",
    "Graphics": "Graphics",
    "AudioVideo": "Multimedia",
    "Office": "Office",
    "Education": "Education",
    "Game": "Games",
    "Utility": "Utilities",
    "Settings": "Settings",
    "Core": "System",
}


def _data_dirs() -> list[Path]:
    value = os.environ.get("XDG_DATA_DIRS", "/usr/local/share:/usr/share")
    return [Path(p) for p in value.split(":") if p and Path(p).is_dir()]


def application_dirs() -> list[Path]:
    dirs = [Path.home() / ".local" / "share" / "applications"]
    dirs.extend(path / "applications" for path in _data_dirs())
    return [path for path in dirs if path.is_dir()]


def icon_roots() -> list[Path]:
    roots = [Path.home() / ".local" / "share" / "icons", Path.home() / ".icons"]
    roots.extend(path / "icons" for path in _data_dirs())
    roots.append(Path("/usr/share/pixmaps"))
    return [path for path in roots if path.is_dir()]


def icon_theme() -> str:
    for settings in (
        Path.home() / ".config" / "gtk-3.0" / "settings.ini",
        Path.home() / ".config" / "gtk-4.0" / "settings.ini",
    ):
        if not settings.is_file():
            continue
        parser = configparser.ConfigParser(interpolation=None)
        try:
            parser.read(settings, encoding="utf-8")
            name = parser.get("Settings", "gtk-icon-theme-name", fallback="")
            if name:
                return name
        except (configparser.Error, OSError):
            continue
    return "hicolor"


def _size_key(folder: Path, target: int) -> int:
    head = folder.name.split("x", 1)[0]
    try:
        return abs(int(head) - target)
    except ValueError:
        return 9999


def resolve_icon(name: str, size: int = 48) -> str | None:
    """Resolve an icon name to an on-disk file using the XDG icon theme spec."""
    if not name:
        return None
    path = Path(name)
    if path.is_absolute():
        return str(path) if path.is_file() else None
    extensions = ("png", "svg", "xpm")
    themes = [icon_theme(), "hicolor", "Adwaita"]
    for root in icon_roots():
        for theme in themes:
            base = root / theme
            index = base / "index.theme"
            parents: list[str] = []
            if index.is_file():
                parser = configparser.ConfigParser(interpolation=None)
                try:
                    parser.read(index, encoding="utf-8")
                    parents = [
                        part.strip()
                        for part in parser.get(
                            "Icon Theme", "Inherits", fallback=""
                        ).split(",")
                        if part.strip()
                    ]
                except (configparser.Error, OSError):
                    parents = []
            for candidate_theme in [theme, *parents]:
                theme_dir = root / candidate_theme
                if not theme_dir.is_dir():
                    continue
                try:
                    folders = sorted(
                        (f for f in theme_dir.iterdir() if f.is_dir()),
                        key=lambda f: _size_key(f, size),
                    )
                except OSError:
                    folders = []
                for folder in folders:
                    for extension in extensions:
                        candidate = folder / f"{name}.{extension}"
                        if candidate.is_file():
                            return str(candidate)
        for extension in extensions:
            candidate = root / f"{name}.{extension}"
            if candidate.is_file():
                return str(candidate)
    return None


def _expand_exec(raw: str, name: str, icon: str, desktop_file: Path) -> str:
    """Apply Desktop Entry field codes and return the command as a JSON array."""
    if not raw:
        return ""
    command = raw.replace("%%", "\x00")
    command = command.replace("%f", "").replace("%F", "")
    command = command.replace("%u", "").replace("%U", "")
    command = command.replace("%i", f"--icon {shlex.quote(icon)}" if icon else "")
    command = command.replace("%c", shlex.quote(name))
    command = command.replace("%k", shlex.quote(str(desktop_file)))
    command = command.replace("\x00", "%")
    try:
        parts = shlex.split(command)
    except ValueError:
        parts = command.split()
    if not parts:
        return ""
    executable = Path(parts[0])
    if not executable.is_absolute() and shutil.which(parts[0]) is None:
        return ""
    return json.dumps(parts, ensure_ascii=False)


def parse_desktop_file(path: Path) -> AppEntry | None:
    parser = configparser.ConfigParser(interpolation=None, strict=False)
    parser.optionxform = str
    try:
        parser.read(path, encoding="utf-8")
    except (configparser.Error, OSError, UnicodeDecodeError):
        return None
    if not parser.has_section("Desktop Entry"):
        return None
    section = parser["Desktop Entry"]
    if section.get("Type", fallback="Application") != "Application":
        return None
    if section.getboolean("NoDisplay", fallback=False):
        return None
    if section.getboolean("Hidden", fallback=False):
        return None

    current = os.environ.get("XDG_CURRENT_DESKTOP", "AetherDE")
    only_show = [x for x in section.get("OnlyShowIn", "").split(";") if x]
    not_show = [x for x in section.get("NotShowIn", "").split(";") if x]
    if only_show and current not in only_show:
        return None
    if current in not_show:
        return None

    try_exec = section.get("TryExec", "").strip()
    if try_exec:
        if Path(try_exec).is_absolute():
            if not Path(try_exec).exists():
                return None
        elif shutil.which(try_exec) is None:
            return None

    name = section.get("Name", fallback="") or path.stem
    icon = section.get("Icon", fallback="")
    categories = [c for c in section.get("Categories", "").split(";") if c]
    return AppEntry(
        id=path.stem,
        name=name,
        generic_name=section.get("GenericName", fallback=""),
        comment=section.get("Comment", fallback=""),
        exec=_expand_exec(section.get("Exec", ""), name, icon, path),
        icon=resolve_icon(icon) or icon,
        categories=categories,
        terminal=section.getboolean("Terminal", fallback=False),
        only_show_in=only_show,
    )


def scan_applications() -> list[dict]:
    found: dict[str, AppEntry] = {}
    for folder in application_dirs():
        for path in sorted(folder.glob("*.desktop")):
            entry = parse_desktop_file(path)
            if entry is not None:
                found.setdefault(entry.id, entry)
    return [
        entry.to_dict()
        for entry in sorted(found.values(), key=lambda item: item.name.casefold())
    ]

# AetherDE

A web-native desktop environment for Arch Linux. Native X11 applications are managed by
`xfwm4`; the web shell is pinned to the EWMH desktop layer and never takes keyboard focus.
A Python async bridge and a Node.js realtime gateway connect the shell to the system.

## Layout

```
AetherDE/
├── PKGBUILD
├── README.md
├── bin/
│   ├── aether-session          # atomic X11 session + signal cleanup
│   └── aether-de               # ~/.xinitrc entry point
├── share/xsessions/aether-de.desktop
├── systemd/aether-de.service   # optional user unit for the bridge
├── src/aether_de/
│   ├── __init__.py  __main__.py  config.py  models.py  events.py
│   ├── x11.py                   # event-driven EWMH/ICCCM tracker
│   ├── xdg.py                   # .desktop + icon theme parser
│   ├── dbus.py                  # notifications, NetworkManager, audio
│   ├── api.py                   # FastAPI REST + NDJSON stream
│   └── daemon.py                # orchestrator
├── gateway/
│   ├── package.json  server.js  ipc.js  pty.js  fsapi.js
└── shell/
    ├── index.html  electron-main.js  preload.js
    ├── css/shell.css
    └── js/{ipc,main,topbar,launcher,dock,terminal,quicksettings,notifications}.js
```

## Build and install

```bash
cd AetherDE
makepkg -si
```

`xorg-xprop` is added to `depends` because the Electron host uses it to force
`_NET_WM_WINDOW_TYPE_DESKTOP` and `_NET_WM_STATE_BELOW` on the shell window.

## Run

From a display manager: select **AetherDE**. From a TTY, put this in `~/.xinitrc`:

```bash
exec /usr/bin/aether-de
```

then run `startx`. The session launches, in order:

1. `dbus-update-activation-environment` + `systemctl --user import-environment`
2. `xfsettingsd`
3. `picom` and `xfwm4 --compositor=off --replace`
4. `polkit-gnome-authentication-agent-1`
5. `python3 -m aether_de.daemon --socket /tmp/aether-sys.sock`
6. `node /usr/lib/aether-de/gateway/server.js ...`
7. the borderless Electron shell at the published loopback URL

`SIGTERM`, `SIGHUP`, `SIGINT` and `EXIT` all run the same cleanup trap: the unix socket and
port file are removed, children get `SIGTERM`, then `SIGKILL` after one second.

## Architecture notes

- **No state polling.** `X11Tracker` blocks in `Display.next_event()` on a dedicated thread
  and forwards `PropertyNotify`/`MapNotify`/`UnmapNotify`/`DestroyNotify`/`ConfigureNotify`
  to an `asyncio.EventBus`. D-Bus events arrive via `dbus-next` signal handlers.
- **Focus discipline.** The shell window is `focusable: false`, `skipTaskbar: true`,
  `_NET_WM_WINDOW_TYPE_DESKTOP` and `_NET_WM_STATE_BELOW`; native windows always render
  above it and keep focus.
- **Icons** are read from `_NET_WM_ICON` and encoded to PNG data URIs with `zlib` alone
  (no Pillow dependency).
- **IPC.** The Python daemon serves REST and an NDJSON event stream on a unix socket.
  The gateway proxies `/api/*` by piping the upstream response straight to the raw HTTP
  reply, and forwards each system event to every browser WebSocket with one JSON
  serialization.
- **Terminal.** `node-pty` spawns a real Zsh/Bash; `term.resize()` issues `TIOCSWINSZ`, and
  xterm.js runs in the browser with `contextIsolation` enabled.

## HTTP / WebSocket surface

| Path | Purpose |
| --- | --- |
| `GET /api/health` | liveness |
| `GET /api/windows` | windows, workspaces, active window |
| `POST /api/window/{id}/{focus,minimize,maximize,close,workspace}` | window actions |
| `GET /api/workspaces`, `POST /api/workspace/{n}` | workspace state |
| `GET /api/apps`, `GET /api/icon` | XDG applications and icons |
| `GET /api/status`, `GET /api/volume`, `POST /api/volume`, `POST /api/mute` | system controls |
| `GET /api/network` | NetworkManager state |
| `POST /api/launch` | launch a parsed `Exec` command |
| `POST /api/notification` | inject a notification (testing) |
| `GET /api/events` | NDJSON event stream |
| `WS /ws` | `sys`, `pty`, `fs` channels |

The filesystem channel is sandboxed to `$HOME` and the system temp directory; thumbnails
use ImageMagick when installed and fall back to the original file otherwise.

## Development without packaging

```bash
cd gateway && npm install
PYTHONPATH=src python3 -m aether_de.daemon --socket /tmp/aether-sys.sock &
node gateway/server.js --socket /tmp/aether-sys.sock --port 8787 --static shell
```

Open `http://127.0.0.1:8787/index.html`. The Electron host is only needed for the real
desktop-layer window; a normal browser is enough for UI development.

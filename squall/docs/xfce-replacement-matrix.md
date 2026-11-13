# Replacing Xfce — component by component

StormG keeps Xfce **only as a substrate**: a window manager, a settings daemon,
a config store and a notification server. Every surface a user interacts with is
Squall. This matrix is the contract for that: what is gone, what is interim, and
what still blocks a full replacement.

Status legend: **Replaced** = Squall owns it · **Interim** = Squall UI, Xfce binary
underneath · **Kept** = no replacement exists yet, and here's why.

| Xfce component | Job | Squall replacement | Status |
|---|---|---|---|
| `xfce4-panel` | panel, taskbar, tray, clock | Squall bar + dock (`frontend/`) | **Replaced** — panel masked in `xfce-minimize.sh` |
| `xfdesktop` | wallpaper, desktop icons, right-click menu | Squall wallpaper/desktop layer + Squall Files | **Replaced** — icons/menu disabled, process masked |
| `xfce4-appfinder` | app launcher / run dialog | Squall launcher (⛈, search, categories) | **Replaced** |
| `Thunar` | file manager, volumes, trash | Squall Files (`apps/files.html` + `fs/*` API) | **Replaced** for browse/search/move; Thunar optional for GVFS/mount dialogs |
| `xfce4-settings-manager` | settings hub | Squall Settings panel in the shell | **Interim** — reads/writes the same `xfconf` keys |
| `xfce4-power-manager` | brightness, lid, suspend, battery, power profiles | `elogind` + Control Center + `squalld` | **Replaced** — battery health/draw/time-left from sysfs, `powerprofilesctl` or ACPI `platform_profile`, CPU governors via `cpufreq`, keyboard backlight LED, hybrid GPU switching via `envycontrol` |
| `xfce4-settings-helper` keys | XF86 brightness/volume/mute shortcuts | `session/squall-key` + `squall-session` xfconf bindings | **Replaced** — keys POST to squalld, same path as the Control Center |
| `xfce4-applet-pulseaudio` | volume tray | Control Center (pactl backend planned) | **Interim** — sliders currently UI-only |
| `nm-applet` | network tray | Control Center network card (nmcli planned) | **Interim** — masked, nmcli wiring pending |
| `blueman-applet` | bluetooth tray | Control Center toggle | **Interim** — masked, `bluetoothctl` wiring pending |
| `xfce4-clipman` | clipboard history | not built | **Kept** (maskable; no clipboard daemon yet) |
| `xfce4-notifyd` | notification server | Squall draws the popups, but apps talk to `org.freedesktop.Notifications` | **Kept** — running the server avoids breaking every app |
| `tumbler` | thumbnails | Squall Files renders previews on demand via `/api/fs/raw` | **Replaced** — tumbler not required |
| `xfce4-terminal` | terminal emulator | Squall Terminal (xterm.js + PTY endpoint) | **Interim** — not built yet, terminal stays |
| `xfce4-session` | session manager, logout dialog | `session/squall-session` + Squall session menu | **Replaced** — Squall session does not use `xfce4-session` |
| `xfwm4` | window manager, compositor, snapping, workspaces | none | **Kept** — writing a WM is out of scope; this is the one real dependency |
| `xfconf` | config store | none | **Kept** — `xfwm4`/`xfsettingsd` read it; Squall writes it too |
| `xfsettingsd` | XSETTINGS daemon | none | **Kept** — GTK apps would lose theme/font/cursor without it |
| `lightdm` + greeter | login | Squall greeter | **Kept** (later) — themeable today via `lightdm-slick-greeter` |
| `plymouth` | boot splash | Squall Plymouth theme | **Replaced** (branding only) |

## What the Squall session actually starts

`session/squall-session` launches exactly:

1. `xfsettingsd` — XSETTINGS for GTK theming
2. `xfwm4` — window manager + compositor
3. `xfce4-notifyd` — notification server (optional but recommended)
4. `squalld` — Python system bridge on `127.0.0.1:9876`
5. `squall` — the shell; when it exits, the session ends

That is the whole list. No `xfce4-session`, no panel, no desktop, no Thunar, no
app finder, no power manager, no applets.

## Path to zero Xfce

| Blocker | Why it stays | What would remove it |
|---|---|---|
| `xfwm4` | WM + compositor + X11 integration | a Wayland compositor (wlroots/smithay) with Squall-drawn decorations |
| `xfconf` + `xfsettingsd` | GTK theming contract on X11 | a small XSETTINGS daemon in Python/GTK, or GTK4 + `gsettings` |
| `xfce4-notifyd` | D-Bus notification service | Squall notification daemon registering `org.freedesktop.Notifications` |
| `lightdm` | display manager | `greetd` + Squall greeter |

Those four are the realistic ceiling for an X11 StormG. Everything above them in
the table is already Squall-owned.

# squall — the StormG desktop environment

StormG's interface: a web-tech shell plus native apps, running on the smallest
possible Xfce substrate. Xfce is not the desktop any more — it is the window
manager and the theming daemon. Everything a user touches is Squall.

```
squall/
├── main.js              Electron shell (overlay) + single-app windows
├── frontend/            bar, dock, launcher, control center (vanilla JS)
├── apps/                Squall apps — files.html (working file manager)
├── backend/squalld.py   Python system bridge, stdlib only, 127.0.0.1:9876
├── session/             squall-session, squall.desktop, xfce-minimize.sh
├── docs/                xfce-replacement-matrix.md
└── gentoo/              substrate atoms + install-gentoo.sh
```

## What Xfce still does

| Kept | Why |
|---|---|
| `xfwm4` | window manager + compositor on X11 — no replacement exists |
| `xfsettingsd` | XSETTINGS daemon GTK apps read theme/font/cursor from |
| `xfconf` | config store those two use |
| `xfce4-notifyd` | implements `org.freedesktop.Notifications` |

Everything else — panel, desktop, app finder, Thunar, settings manager, power
manager UI, tray applets, session manager — is replaced. Full detail:
[`docs/xfce-replacement-matrix.md`](docs/xfce-replacement-matrix.md).

## Run it

```bash
# 1. system bridge
python3 backend/squalld.py &

# 2a. shell, in a browser (no Electron needed)
python3 -m http.server 8080 --directory frontend
# open http://localhost:8080

# 2b. shell, as the real overlay
npm install && npm start

# 2c. one Squall app in its own window
npm start -- --app files

# 3. Squall Files directly
python3 -m http.server 8080 --directory apps   # open /files.html
```

## Session

```bash
sudo install -Dm755 session/squall-session /usr/bin/squall-session
sudo install -Dm644 session/squall.desktop /usr/share/xsessions/squall.desktop
```

Then pick **Squall** in the greeter. On a stock Xfce box, use
`session/xfce-minimize.sh` instead to mask the replaced components.

`squall-key` is installed to `/usr/bin/squall-key`; the session binds the
brightness and volume keys to it.

## Squall Files API (confined to `$HOME`)

## Hardware endpoints

Each returns `{"supported": false}` when its tool is missing, so the Control
Center shows an explicit unavailable state instead of a toggle that lies.

| Method | Endpoint | Backing tool |
|---|---|---|
| GET | `/api/audio` | `pactl` (volume, mute, default sink) |
| POST | `/api/audio` `{volume, muted}` | `pactl set-sink-volume/mute` |
| GET | `/api/network` | `nmcli` (radio, active SSID, connections) |
| POST | `/api/network` `{wifi: bool}` | `nmcli radio wifi on\|off` |
| GET | `/api/bluetooth` | `bluetoothctl show/devices` |
| POST | `/api/bluetooth` `{powered: bool}` | `bluetoothctl power on\|off` |
| GET | `/api/power` | `/sys/class/power_supply`, `brightnessctl` |
| POST | `/api/brightness` `{value}` or `{step}` | `brightnessctl set`; `step` is relative |
| GET | `/api/kbdlight` | keyboard LED class (`*::kbd_backlight`) |
| POST | `/api/kbdlight` `{value}` or `{step}` | `brightnessctl --device`, sysfs fallback |
| GET | `/api/gpu` | `envycontrol -q`, `lspci` |
| POST | `/api/gpu` `{mode: integrated\|hybrid\|nvidia}` | `pkexec envycontrol -s`; needs logout |
| GET | `/api/cpu` | `cpufreq` sysfs: governors, current/max MHz, turbo |
| POST | `/api/cpu` `{governor, turbo}` | sysfs, then `pkexec cpupower` |

## Design language

## Theme and options

`~/.config/squall/settings.json` is the source of truth for the desktop's look:

| Key | Values | Effect |
|---|---|---|
| `theme` | `dark`, `glass`, `light` | surface palette; also mirrored to GTK/xfwm4 when `xfconf-query` exists |
| `accent` | `cyan`, `amber`, `lilac`, `salmon`, `mint` | single saturated accent used across bar, dock, control center |
| `density` | `comfortable`, `compact` | row padding, dock size, bar height |
| `fontScale` | `90`, `100`, `110`, `120` | root type scale |
| `motion` | `true`, `false` | disables transitions/animations |
| `wallpaper` | `true`, `false` | whether the shell draws the desktop layer |

`GET /api/settings` returns the merged set; `POST /api/settings` accepts a
partial patch, rejects unknown keys and invalid values (`rejected` in the
response), writes atomically and applies GTK theming. The shell also caches the
last good set in `localStorage`, so it paints in the right theme before the
daemon answers. Squall Files reads the same endpoint, so it follows the shell's
theme, accent, density and text size.

Options follow the same contract: `GET /api/powerprofile` and
`POST /api/powerprofile {profile}` wrap `powerprofilesctl`, returning
`{"supported": false}` when the tool is absent.

`powerprofilesctl` is preferred; without it squalld falls back to the ACPI
`platform_profile` interface (`low`/`balanced`/`performance`), so most laptops
keep working. The same rule applies to CPU governors (`intel_pstate`/
`cpufreq`), keyboard backlight LEDs and hybrid graphics (`envycontrol`:
integrated / hybrid / nvidia, one logout to apply).

## Hardware keys

`session/squall-key` is a stdlib bridge that POSTs to squalld. `squall-session`
binds `XF86MonBrightnessUp/Down`, `XF86KbdBrightnessUp/Down` and the three
volume keys to it through `xfconf`, so a physical key and a Control Center
slider share one code path, including the root/fallback handling.

## Application index

`GET /api/apps` scans `~/.local/share/applications`, every `$XDG_DATA_DIRS`
entry, and system/user Flatpak exports. It honours `NoDisplay`, `Hidden` and
`TryExec`, dedupes by desktop id and display name, strips field codes, and
returns categories and keywords for search. First sightings live in
`~/.cache/squall/apps.json`: apps installed in the last seven days are flagged
`new`, and an uninstalled app disappears on the next scan. The launcher
refreshes when it opens, so new packages appear without restarting the shell,
and its category tabs and counts come from the apps that actually exist.

Deep-navy glass with a restrained LCARS vocabulary: one amber-to-salmon rail on
the dock, one numbered control-center header (`47 / Squall control`), lilac
section labels, pill caps and mono eyebrows. Everything else stays quiet:
hairline borders, one accent cyan, 120 ms transitions, no glow spam.
Tokens live at the top of `frontend/styles.css`.

`preview/shell.html` is a generated single-file build of the shell (inlined
CSS/JS) for panels that cannot serve sibling assets. It is not shipped in the
package.

| Method | Endpoint | Purpose |
|---|---|---|
| GET | `/api/fs/list?path=` | directory listing |
| GET | `/api/fs/search?path=&q=` | bounded recursive search (2.5 s budget) |
| GET | `/api/fs/read?path=` | text preview, 200 KB cap |
| GET | `/api/fs/raw?path=` | raw bytes for image/PDF preview |
| POST | `/api/fs/mkdir` | `{path, name}` |
| POST | `/api/fs/rename` | `{path, name}` |
| POST | `/api/fs/trash` | `{paths: []}` → `~/.squall-trash` |
| POST | `/api/fs/paste` | `{src: [], dst, mode: copy\|move}` |
| POST | `/api/fs/open` | hand a path to the desktop handler |

Paths outside `$HOME` return 403. This API never builds shell strings.

## Install on Gentoo / StormG

StormG is OpenRC + Portage, so there is no PKGBUILD here. Two paths use the
same files:

```bash
sudo gentoo/install-gentoo.sh    # /usr/bin/squall{,-session,-key},
                                 # /usr/lib/squall, xsessions entry
```

- **Live ISO**: catalyst unpacks `root_overlay/`, which already carries the
  payload, the three binaries, the xsessions entry and `user-session=squall`.
  `autocatalyst.sh` re-copies that overlay from this tree on every build, so
  the two cannot drift.
- **Installed system**: run the script above. Gentoo has no Electron in the
  main tree, so `squall` falls back to a fullscreen browser window on a
  loopback server.

Details (substrate atoms, browser host, no OpenRC daemon unit):
[`gentoo/README.md`](gentoo/README.md).

## Rollout stages

Stage 1 is this folder on any system: squalld plus a browser. Stage 2 is the
session — `squall-session` over the substrate from `gentoo/xfce-minimal.txt`,
with a greeter entry. Stage 3 is the substrate-only image, which is what StormG
ships.

Full write-up: [`docs/stages.md`](docs/stages.md).

## Status

- **Working:** shell overlay, launcher, control center, Squall Files, squalld
  bridge, minimum-Xfce session scripts, packaging.
- **Interim:** terminal is `xfce4-terminal`; the notification server is still
  `xfce4-notifyd`.
- **Not built:** text editor, software center, notification daemon, greeter.

# Rollout stages — putting Squall on a StormG machine

Squall goes on in three stages. Stage 1 is the shell on its own (unpacked
folder, squalld, a browser) — the UI works, nothing is a desktop yet. Stage 2
turns that into a real X session wired to real hardware. Stage 3 makes Squall
the only desktop the image ships.

StormG is OpenRC + Portage: `emerge` replaces `pacman`, `elogind` replaces
`systemd-logind`, and there is no per-user systemd unit. The packages that make
up the substrate are listed in [`../gentoo/xfce-minimal.txt`](../gentoo/xfce-minimal.txt).

## Stage 1 — static shell (done)

Exit criteria on any system:

- `http://127.0.0.1:9876/api/health` answers,
- the shell opens from `frontend/index.html` and renders,
- `/api/apps` returns the expected shape (even if `total: 0` on a bare system),
- hardware reads back honest `{"supported": false}` until the tools exist.

Nothing else happens at this stage. An empty launcher is expected — there are
no `.desktop` files yet.

## Stage 2 — Squall as a session

Goal: a real X session with the shell, live system controls, hardware keys and
a greeter entry.

`gentoo/install-gentoo.sh` does the wiring:

1. **Payload** → `/usr/lib/squall` (frontend, apps, backend, Electron entry
   point), binaries → `/usr/bin/squall`, `squall-session`, `squall-key`, and
   `squall.desktop` → `/usr/share/xsessions`.
2. **Substrate packages**: `xfwm4`, `xfce4-settings`, `xfconf`,
   `xfce4-notifyd`, `dbus`, `python`, plus `xfce4-terminal` as the interim
   terminal and `polkit-gnome` (or `lxpolkit`) for pkexec prompts.
3. **Session wiring**: `squall-session` starts the substrate, `squalld`, the
   polkit agent, binds the XF86 brightness/keyboard-light/volume keys to
   `squall-key` through xfconf, then hands the session to the shell.
4. **Greeter**: lightdm (the live image's greeter) with
   `user-session=squall`. On the ISO it autologins `gentoo` straight into it.

What turns on here, and what to verify:

- bar and dock render as their own window, the substrate is invisible;
- hardware controls become live — brightness, battery, power profile, GPU mode
  and CPU governor read real sysfs/tools instead of `supported: false`;
- XF86 brightness, keyboard backlight and volume keys change actual hardware;
- the launcher starts populating: Portage filling `/usr/share/applications` is
  exactly what `/api/apps` scans, so an `emerge` shows up without restarting
  the shell.

## Stage 3 — Squall as the OS

Goal: image builds and sessions assume Squall; nothing else is user-facing.

On StormG this is the live image itself: `root_overlay` carries the shell,
`lightdm.conf` points at the Squall session, and only the substrate survives
from `xfce4-meta`. OpenRC services the image needs are in the spec's
`livecd/rcadd` (`elogind`, `dbus`, `display-manager`, `NetworkManager`).

Verification:

- `/usr/share/xsessions/squall.desktop` is the session lightdm starts;
- after a reboot the desktop is Squall, with xfwm4 visible only as the window
  manager (Electron is not installed in the image, so the shell runs in a
  fullscreen browser window — see [`../gentoo/README.md`](../gentoo/README.md));
- nothing outside the substrate from the Xfce group is left running;
- a rebuild from scratch (`autocatalyst.sh`) reproduces it with no manual fixes.

## Next steps

Stage 3 is where the remaining Xfce pieces get replaced as the apps land:
`xfce4-terminal` by Squall Terminal, `xfce4-notifyd` by a Squall notification
daemon, and the greeter by a Squall one. The renderer uses no Electron APIs, so
a WebKitGTK host can replace the browser window on low-RAM targets without
touching the shell.

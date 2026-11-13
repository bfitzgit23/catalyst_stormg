# Squall on Gentoo / StormG

StormG is OpenRC + Portage, so the Arch-era packaging (PKGBUILD, `pacman -S`
stage scripts) does not apply and was dropped from this tree. Two install paths
remain, and both use exactly the same files:

| Path | Use it for |
|---|---|
| `../root_overlay/` | the live ISO — catalyst unpacks it into the chroot |
| `./install-gentoo.sh` | an installed system you already booted |

`autocatalyst.sh` refreshes `root_overlay/usr/lib/squall`, `usr/bin/squall*` and
`usr/share/xsessions/squall.desktop` from this tree before the build, so the
overlay copy cannot drift from the source.

## Packages

`xfce-minimal.txt` is the substrate. On the live image everything there comes
from the stage1 package list (`xfce-base/xfce4-meta` pulls the substrate in);
on an installed system:

```sh
sudo emerge --ask xfwm4 xfce4-settings xfconf xfce4-notifyd dbus dev-lang/python \
              xfce4-terminal x11-misc/polkit-gnome
```

## No Electron on the live image

`::gentoo` has no Electron ebuild, so `squall` falls back to the first browser
it finds and runs the shell fullscreen from a loopback server:

```sh
firefox-bin --kiosk http://127.0.0.1:9875/frontend/index.html
```

That is a fullscreen window, not a transparent desktop overlay — the shell
still owns everything the user sees, but Xfwm4 is visibly underneath it. On a
machine where Electron *is* installed (overlay, guru, or a local ebuild), the
launcher prefers it and the overlay mode from `main.js` takes over. The
renderer uses no Electron APIs, so nothing else changes.

## No squalld service unit

`squalld` is a **per-user** daemon: it reads and writes `$HOME`, and the shell
starts it from `squall-session`. OpenRC has no per-user services, and a
system-wide init script running as root would write into the wrong home
directory, so this tree ships no unit at all. The Arch tree's systemd
`squalld.service` was removed for that reason. Start it by hand when scripting:

```sh
python3 /usr/lib/squall/backend/squalld.py --port 9876 &
```

## Session wiring

`root_overlay/etc/lightdm/lightdm.conf` on the live image already sets:

```
user-session=squall
autologin-user=gentoo
autologin-session=squall
```

`/etc/lightdm/Xsession` is the session wrapper (Gentoo's lightdm ships it), and
`squall-session` additionally re-execs under `dbus-run-session` if the wrapper
did not start a bus. Diagnostics land in `~/.squall/session.log`.

### What Calamares leaves behind

`unpackfs` copies the whole live root into the target, so `/usr/bin/squall*`,
`/usr/lib/squall`, `/usr/share/xsessions/squall.desktop` and even the live
`/etc/lightdm/lightdm.conf` arrive with no extra work. Two installer steps then
work against that:

| Step | Effect | Handled by |
|---|---|---|
| `displaymanager` | rewrites `user-session=` in the target's `lightdm.conf` from `defaultDesktopEnvironment.desktopFile` | that key names `squall` in `displaymanager.conf` |
| `removeuser` | deletes the live user `gentoo` | `shellprocess@squall` comments out `autologin-user=` |

`shellprocess@squall` (after `displaymanager`, before `services-openrc`) runs
`/usr/local/bin/stormg-squall-default`, which makes the result deterministic:
`user-session=squall`, `autologin-session=squall` if the key exists, and no
autologin for the removed live user. It is idempotent and only touches those
keys. The installed system therefore boots to the greeter with **Squall** as
the default session; `xfce4-meta` is still installed, so the stock XFCE session
is the fallback both in the greeter and inside `squall-session`.

### A failed start gives a desktop, not a black screen

`squall-session` no longer execs the shell blind. It starts it in the
background and waits up to `SQUALL_BOOT_TIMEOUT` seconds (default 8) for the
launcher's readiness marker — `$SQUALL_READY`, normally
`$XDG_RUNTIME_DIR/squall.ready`, written once a host process (browser or
Electron) is being started. If the launcher exits first, never writes the
marker, or dies within a second of writing it, the session hands itself to
`xfce4-session` under XFCE's own `XDG_*` identity. Every branch is logged:

```
[session] handing session to squall (fallback to XFCE after 8s)
[session] squall is up (pid 1234)
[session] squall did not come up; falling back to the stock XFCE session
[session] exec xfce4-session
```

The stock XFCE session has to be installed for the fallback to have anywhere to
go — on the live image `xfce4-meta` provides it. Without it the session logs
`xfce4-session is not installed: no desktop to fall back to` and returns to the
greeter.

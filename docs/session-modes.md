# StormG session modes after the AetherDE port

Squall is no longer copied into the live image by `autocatalyst.sh`. Its source
tree under `squall/` is kept for reference, but the live root has no Squall
binaries, payload, xsessions entry or Calamares hook.

## Default: AetherDE via LightDM

`root_overlay/etc/lightdm/lightdm.conf`:

```ini
user-session=aether-de
autologin-session=aether-de
autologin-user=gentoo
```

`aether-session` runs the XFCE substrate (`xfsettingsd`, `xfwm4`), starts
`picom`, the Python bridge and the Node gateway, then opens the web shell.
Gentoo's main repo has no Electron atom, so the launcher prefers `electron`
when present and otherwise uses `firefox-bin`/`firefox`. The Firefox fallback is
a normal window rather than an EWMH desktop-layer window, so native apps will
not layer above it exactly as they do with Electron.

## Fallbacks

- **XFCE** is installed from `xfce-base/xfce4-meta` and selectable at the greeter.
- If the Python daemon, Node gateway, or browser fails, `aether-session`
  terminates its children and `exec startxfce4`, logging to
  `$XDG_CACHE_HOME/aether-de/aether-session.log`.
- Calamares fallback installer: `stormos-installer-advanced.desktop`.

## No login manager

`x11-apps/xinit` is installed and `/usr/bin/aether-xinit` is included:

```bash
aether-xinit
# or: startx /usr/bin/aether-session -- -nolisten tcp
```

To boot without LightDM on OpenRC:

1. `rc-update del lightdm default`
2. ensure agetty autologin on tty1 in `/etc/inittab`
3. in the live user's `~/.bash_profile`:

   ```bash
   if [ -z "$DISPLAY" ] && [ "$(tty)" = "/dev/tty1" ]; then
       exec aether-xinit
   fi
   ```

## Installer

`/usr/bin/stormos-installer` starts the Python backend and opens the GUI in
Electron when available, otherwise `firefox-bin`. The backend reads
`/usr/lib/stormos-installer/backend/profile.json` for Gentoo-specific media
globs, `gentoo-chroot` and internally generated fstab, so no `arch-chroot` or
`genfstab` is required.

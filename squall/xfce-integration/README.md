# Xfce integration

Two supported modes.

## 1. Squall as the session (recommended)

`session/squall-session` starts only `xfsettingsd`, `xfwm4`, `xfce4-notifyd`,
`squalld` and `squall`. `xfce4-session` and `xfce4-panel` are not used.

Install:

```bash
sudo install -Dm755 session/squall-session /usr/bin/squall-session
sudo install -Dm644 session/squall.desktop /usr/share/xsessions/squall.desktop
```

Log out, pick **Squall** in the greeter. To undo, pick *Xfce Session* — nothing
about the stock session was modified.

The authoritative list of what is replaced vs kept lives in
[`../docs/xfce-replacement-matrix.md`](../docs/xfce-replacement-matrix.md).

## 2. Squall inside an existing Xfce session

For testing on a normal Xfce install without switching sessions:

```bash
bash session/xfce-minimize.sh          # mask panel, desktop, applets...
# autostart the shell for this user only
cp xfce-integration/squall-shell.desktop ~/.config/autostart/
```

`xfce-minimize.sh --restore` removes the masks and returns stock behaviour.

## ISO wiring

The StormG image already does this: `root_overlay/` ships the payload, the three
binaries and `usr/share/xsessions/squall.desktop`, and
`root_overlay/etc/lightdm/lightdm.conf` sets `user-session=squall`. The
substrate atoms are in [`../gentoo/xfce-minimal.txt`](../gentoo/xfce-minimal.txt).

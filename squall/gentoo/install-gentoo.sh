#!/usr/bin/env bash
# install-gentoo.sh — put Squall on an installed Gentoo / StormG system.
#
# The live ISO does not use this: catalyst unpacks root_overlay, which already
# carries the same files (autocatalyst.sh refreshes that copy from this tree).
# This is the path for a normal install you booted yourself.
#
#   sudo ./install-gentoo.sh            # install into /
#   DESTDIR=/tmp/stage ./install-gentoo.sh   # stage into an image
#
# Then log out and pick Squall in the greeter, or point lightdm at it:
#   user-session=squall
#   autologin-session=squall
set -euo pipefail

src="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
d="${DESTDIR:-}"
lib="$d/usr/lib/squall"
bindir="$d/usr/bin"

install -d -m 0755 "$lib" "$bindir" "$d/usr/share/xsessions"

# Shell payload: the frontend, the apps, the backend and the Electron entry
# point (main.js is unused when Electron is not installed).
install -m 0644 "$src/main.js" "$src/package.json" "$lib/"
for part in frontend apps backend; do
    install -d -m 0755 "$lib/$part"
    cp -a "$src/$part/." "$lib/$part/"
done

install -m 0755 "$src/session/squall" "$bindir/squall"
install -m 0755 "$src/session/squall-session" "$bindir/squall-session"
install -m 0755 "$src/session/squall-key" "$bindir/squall-key"
install -m 0644 "$src/session/squall.desktop" "$d/usr/share/xsessions/squall.desktop"

cat <<'EOF'
Squall installed.

  /usr/bin/squall                 shell launcher (browser host, or Electron)
  /usr/bin/squall-session         the X session
  /usr/bin/squall-key             XF86 brightness/volume bridge
  /usr/lib/squall/                payload
  /usr/share/xsessions/squall.desktop

Xfce substrate needed (docs/xfce-replacement-matrix.md):
  emerge --ask xfwm4 xfce4-settings xfconf xfce4-notifyd dbus python\\
         xfce4-terminal polkit-gnome
EOF

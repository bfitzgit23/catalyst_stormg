#!/usr/bin/env bash
# Copy the canonical AetherDE source tree into the StormOS XFCE airootfs at the
# same paths the PKGBUILD installs to. Run from anywhere before `./build.sh`.
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROFILE_DIR="$(cd -- "$SCRIPT_DIR/.." && pwd)"
ROOT="$PROFILE_DIR/airootfs"
LIB="$ROOT/usr/lib/aether-de"

for directory in \
  "$ROOT/usr/bin" \
  "$LIB" \
  "$ROOT/usr/lib/systemd/user" \
  "$ROOT/usr/share/xsessions" \
  "$ROOT/usr/share/doc/aether-de"
  "$ROOT/etc/skel"
do
  mkdir -p "$directory"
done

cp -a "$SCRIPT_DIR/src/aether_de" "$LIB/aether_de"
cp -a "$SCRIPT_DIR/gateway" "$LIB/gateway"
cp -a "$SCRIPT_DIR/shell" "$LIB/shell"
cp -a "$SCRIPT_DIR/bin/aether-session" "$ROOT/usr/bin/aether-session"
cp -a "$SCRIPT_DIR/bin/aether-de" "$ROOT/usr/bin/aether-de"
cp -a "$SCRIPT_DIR/bin/aether-xinit" "$ROOT/usr/bin/aether-xinit"
cp -a "$SCRIPT_DIR/etc/skel/.xinitrc" "$ROOT/etc/skel/.xinitrc"
cp -a "$SCRIPT_DIR/share/xsessions/aether-de.desktop" "$ROOT/usr/share/xsessions/aether-de.desktop"
cp -a "$SCRIPT_DIR/systemd/aether-de.service" "$ROOT/usr/lib/systemd/user/aether-de.service"
cp -a "$SCRIPT_DIR/README.md" "$ROOT/usr/share/doc/aether-de/README.md"

find "$LIB" -type d -exec chmod 755 {} +
find "$LIB" -type f -exec chmod 644 {} +
chmod 755 "$ROOT/usr/bin/aether-session" "$ROOT/usr/bin/aether-de" "$ROOT/usr/bin/aether-xinit"
chmod 755 "$LIB/gateway/server.js" "$LIB/shell/electron-main.js"

printf 'AetherDE synced into %s\n' "$ROOT"
printf 'Next: sudo rm -rf "%s/work" && sudo ./build.sh -v\n' "$PROFILE_DIR"

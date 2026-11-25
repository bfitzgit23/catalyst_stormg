#!/bin/bash
#
# AetherDE — Calamares post-install hook for the StormOS XFCE profile.
# Runs inside the installed target after the displaymanager module, so any
# LightDM defaults that module wrote are overwritten here.

set -u

LOG=/var/log/aetherde-postinstall.log
exec > >(tee -a "$LOG") 2>&1

echo "=================================================="
echo "AetherDE post-install — $(date)"
echo "=================================================="

if [ "$(id -u)" -ne 0 ]; then
    echo "ERROR: this script must be run as root" >&2
    exit 1
fi

# Calamares chroots before running shellprocess, so ROOT is normally "/".
# The mount-point fallback supports an older non-chrooted caller.
if [ -n "${CALAMARES_TARGET_ROOT:-}" ]; then
    TARGET_ROOT="$CALAMARES_TARGET_ROOT"
elif [ -d /tmp/calamares-root ] && mount | grep -q 'on /tmp/calamares-root'; then
    TARGET_ROOT=/tmp/calamares-root
else
    TARGET_ROOT=/
fi

SESSION="$TARGET_ROOT/usr/share/xsessions/aether-de.desktop"
if [ ! -f "$SESSION" ]; then
    echo "AetherDE session is not present in the target; nothing to configure" >&2
    exit 0
fi

# ---------------------------------------------------------------- LightDM
lightdm="$TARGET_ROOT/etc/lightdm/lightdm.conf"
if [ -f "$lightdm" ]; then
    sed -i 's/^user-session=.*/user-session=aether-de/' "$lightdm"
    sed -i 's/^autologin-session=.*/autologin-session=aether-de/' "$lightdm"
    if ! grep -q '^user-session=aether-de' "$lightdm"; then
        printf '\n[Seat:*]\nuser-session=aether-de\nautologin-session=aether-de\n' >> "$lightdm"
    fi
    echo "LightDM defaults set to AetherDE (XFCE remains selectable)"
fi

# ------------------------------------------------------------- permissions
lib="$TARGET_ROOT/usr/lib/aether-de"
if [ -d "$lib" ]; then
    find "$lib" -type d -exec chmod 755 {} + 2>/dev/null || true
    find "$lib" -type f -exec chmod 644 {} + 2>/dev/null || true
    chmod 755 "$lib/gateway/server.js" "$lib/shell/electron-main.js" 2>/dev/null || true
    chmod 755 "$TARGET_ROOT/usr/bin/aether-session" "$TARGET_ROOT/usr/bin/aether-de" 2>/dev/null || true
fi

# ------------------------------------------------- node dependency self-heal
gateway="$lib/gateway"
if [ -d "$gateway" ] && [ ! -d "$gateway/node_modules" ]; then
    echo "Installing AetherDE gateway dependencies in the installed system..."
    (cd "$gateway" && npm install --omit=dev --no-audit --no-fund) \
        || echo "WARNING: npm install failed in target; the session will retry at login" >&2
fi

# ------------------------------------------------------------------ verify
for relative in \
    usr/bin/aether-session \
    usr/share/xsessions/aether-de.desktop \
    usr/lib/aether-de/aether_de/daemon.py \
    usr/lib/aether-de/gateway/server.js \
    usr/lib/aether-de/shell/index.html
do
    if [ -e "$TARGET_ROOT/$relative" ]; then
        echo "  ok: /$relative"
    else
        echo "  MISSING: /$relative" >&2
    fi
done

echo "AetherDE post-install complete"
exit 0

#!/bin/bash
# Catalyst livecd-stage2 fsscript for the StormG live ISO.
#
# Runs inside the chroot after root_overlay is unpacked and before catalyst's
# rc-update step (livecd/rcadd in livegui-stage2.spec).  The live user is
# created earlier by catalyst's livecdfs-update.sh, which runs *before*
# root_overlay, so its home still holds the stock stage3 skeleton.

set -euo pipefail

# The stage2 chroot from before the root_overlay account-DB copies were
# dropped still has the old four-entry /etc/passwd.  useradd/groupadd left
# the pre-overlay copies in /etc/*-, so fold back any name that is missing.
# On a freshly unpacked stage1 this finds nothing.
for db in passwd group shadow gshadow; do
    [ -f "/etc/${db}" ] && [ -f "/etc/${db}-" ] || continue
    tmp="$(mktemp)"
    awk -F: 'NR == FNR { seen[$1] = 1; next } !($1 in seen)' \
        "/etc/${db}" "/etc/${db}-" > "$tmp"
    [ -s "$tmp" ] && cat "$tmp" >> "/etc/${db}"
    rm -f "$tmp"
done

# A stage2 chroot from an older tree still has the 34 MB duplicate config
# tree that root_overlay used to ship as /xfce-configs.  Keep the one file
# that was not already in /etc/skel, then drop the rest.
if [ -f /xfce-configs/.config/chromium-flags.conf ] \
        && [ ! -f /etc/skel/.config/chromium-flags.conf ]; then
    install -d -m 0755 /etc/skel/.config
    cp -a /xfce-configs/.config/chromium-flags.conf /etc/skel/.config/
fi
rm -rf /xfce-configs

if id -u gentoo >/dev/null 2>&1; then
    # Replace that skeleton with the desktop configuration from
    # root_overlay/etc/skel.
    install -d -m 0755 /home/gentoo /home/gentoo/Desktop
    cp -a /etc/skel/. /home/gentoo/

    # Hardware/session groups the live user needs.  groupadd -f makes a
    # retry safe and covers groups no installed package has created.
    for group in autologin netdev nopasswdlogin plugdev; do
        groupadd -f "$group"
    done

    # livecdfs-update.sh only grants users,wheel,audio,plugdev,games,cdrom,
    # disk,floppy,usb.
    for group in sys adm network power uucp optical rfkill video storage \
                 audio wheel users games cdrom disk floppy usb \
                 autologin nopasswdlogin netdev plugdev; do
        getent group "$group" >/dev/null && usermod -a -G "$group" gentoo
    done

    # Desktop launchers (only for applications that are actually installed).
    for app in calamares gentoo-pkg-manager stormg-welcome firefox-bin gparted gentoo-handbook; do
        desktop="/usr/share/applications/${app}.desktop"
        [ -e "$desktop" ] && ln -sf "$desktop" "/home/gentoo/Desktop/${app}.desktop"
    done

    chown -R gentoo:users /home/gentoo
fi

# root_overlay/etc/locale.gen already enables en_US.UTF-8.
locale-gen

# Keep NetworkManager from rewriting /etc/hostname (breaks xauth) and from
# randomising the WiFi MAC on every scan.
install -d -m 0755 /etc/NetworkManager/conf.d
cat > /etc/NetworkManager/conf.d/90-stormg.conf <<'EOF'
[main]
hostname-mode=none

[device]
wifi.scan-rand-mac-address=no
EOF

# rsync keeps the repo's 0644 mode when it copies root_overlay; sudo refuses
# to run with a group/other-readable sudoers.
chown root:root /etc/sudoers
chmod 0440 /etc/sudoers
if [ -d /etc/sudoers.d ]; then
    chown -R root:root /etc/sudoers.d
    chmod 0755 /etc/sudoers.d
    find /etc/sudoers.d -type f -exec chmod 0440 {} +
fi

# Executed by trust-launch.desktop, 0644 in the repo.
chmod 0755 /usr/local/bin/trust.sh

exit 0

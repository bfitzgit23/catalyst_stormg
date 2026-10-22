#!/bin/bash
# Catalyst fsscript for StormG Linux LiveCD (OpenRC)

# 1. Enable services for the Live CD environment
rc-update add bluetooth default
rc-update add xdm default
rc-update add dbus default
rc-update add NetworkManager default

# 2. Configure LightDM as the default display manager
sed -i 's/DISPLAYMANAGER="xdm"/DISPLAYMANAGER="lightdm"/g' /etc/conf.d/xdm

# 3. Inject explicit autologin rules for the live session user
mkdir -p /etc/lightdm/lightdm.conf.d/
cat << 'EOF' > /etc/lightdm/lightdm.conf.d/80-stormg-live-autologin.conf
[Seat:*]
user-session=xfce
autologin-user=gentoo
autologin-user-timeout=0
autologin-session=xfce
EOF

# 4. Force Blueman applet autostart for the live user skeleton
mkdir -p /etc/skel/.config/autostart
if [ -f /usr/share/applications/blueman-applet.desktop ]; then
    cp /usr/share/applications/blueman-applet.desktop /etc/skel/.config/autostart/
fi

# 5. Assign live session permissions for peripheral hardware management
id -u gentoo &>/dev/null && gpasswd -a gentoo bluetooth
id -u gentoo &>/dev/null && gpasswd -a gentoo plugdev

exit 0

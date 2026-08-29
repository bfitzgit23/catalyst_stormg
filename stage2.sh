#!/bin/bash

echo Running gentoo stage2 fsscript ...

source /etc/profile
env-update
source /tmp/envscript

# No we don't want to run xdm...
sed -e '/^DISPLAYMANAGER=/s/.*/DISPLAYMANAGER="lightdm"/' -i /etc/conf.d/display-manager

locale-gen

# Don't let NM change hostname (this breaks xauth)
echo "[main]
plugins=keyfile 
hostname-mode=none" > /etc/NetworkManager/NetworkManager.conf

# Set up gentoo user
name=$(ls -1 /home/gentoo)
REAL_NAME=/home/gentoo

groupadd vboxusers
groupadd vmware
groupadd vboxguest
groupadd ntp
useradd -M -g messagebus messagebus
groupadd avahi
useradd -M -g avahi avahi
gpasswd -a gentoo avahi

# System groups for the live user. Create them if they don't already exist
# (the desktop-openrc stage3 may ship some), then add 'gentoo' to each.
#  - power : allow reboot/shutdown from the session menu (see polkit rule)
#  - netdev: allow NetworkManager + nm-applet to manage wifi/DHCP
#  - plugdev: allow non-root access to removable devices / network dongles
#  - autologin / nopasswdlogin: allow password-less GUI autologin under lightdm
for g in power netdev plugdev autologin nopasswdlogin; do
	groupadd -f "$g"
	usermod -a -G "$g" gentoo
done

# Make sure gentoo is the primary member of a sane default group too
usermod -g users gentoo 2>/dev/null || true

# CLI/console autologin: OpenRC drops you onto tty1 via agetty --autologin.
# Replace the tty1/tty2 getty lines so a plain console logs in as 'gentoo'.
if [ -f /etc/inittab ]; then
	sed -i 's#^c1:.*tty1.*#c1:   -       respawn:/sbin/agetty --autologin gentoo --noclear 38400 tty1 linux#' /etc/inittab 2>/dev/null || true
	sed -i 's#^c2:.*tty2.*#c2:   -       respawn:/sbin/agetty --autologin gentoo --noclear 38400 tty2 linux#' /etc/inittab 2>/dev/null || true
	grep -q -- '--autologin gentoo' /etc/inittab || \
		echo 'c1:12345:respawn:/sbin/agetty --autologin gentoo --noclear 38400 tty1 linux' >> /etc/inittab
fi
# For elogind VTs we must keep /etc/securetty-style approval for agetty autologin
if [ -f /etc/securetty ]; then
	grep -q '^tty1$' /etc/securetty || echo tty1 >> /etc/securetty
	grep -q '^tty2$' /etc/securetty || echo tty2 >> /etc/securetty
fi

emerge --sync -q && eix-update

pushd /home/gentoo
mkdir -pv .config Desktop .local .oh-my-bash .cache/oh-my-bash

# copy Desktop and other settings

cp -rv /xfce-configs/.config/* /home/gentoo/.config
cp -rv /xfce-configs/.oh-my-bash/* /home/gentoo/.oh-my-bash/
cp -rv /xfce-configs/.cache/oh-my-bash/* /home/gentoo/.cache/oh-my-bash/

cp -r /xfce-configs/.bashrc /home/gentoo/.bashrc
cp -r /xfce-configs/.bashrc /root
cp -rv /xfce-configs/.oh-my-bash/* /root
cp -rv /xfce-configs/.cache/ /root

cp -rv /xfce-configs/.mozilla /home/gentoo/.mozilla
cp -rv /xfce-configs/.nanorc /home/gentoo/.nanorc 

cp -rv /xfce-configs/.profile /home/gentoo/.profile
cp -rv /xfce-configs/.xprofile /home/gentoo/.xprofile
cp -rv /xfce-configs/.bash_profile /home/gentoo/.bash_profile

cp -rv /xfce-configs/.profile /root
cp -rv /xfce-configs/.xprofile /root
cp -rv /xfce-configs/.bash_profile /root

chsh -s /bin/bash root
chsh -s /bin/bash gentoo

mkdir -p /home/gentoo/.config/autostart

chown -R gentoo /home/gentoo/.config

chown -R gentoo /home/gentoo/*

# User face image
cp /xfce-configs/.face /home/gentoo/.face

# Desktop icon setups
DESKTOP_APPS=( firefox-bin stormg-welcome gparted gentoo-handbook )
for i in "${DESKTOP_APPS[@]}"; do
	ln -sv /usr/share/applications/${i}.desktop Desktop/
done

groupadd lightdm

chage -E -1 lightdm

cp -af /usr/share/applications/calamares.desktop /home/gentoo/Desktop/calamares.desktop
chown -R gentoo:users /home/gentoo/Desktop/calamares.desktop
chmod +x /home/gentoo/Desktop/calamares.desktop

cp -af /usr/share/applications/gentoo-pkg-manager.desktop /home/gentoo/Desktop/gentoo-pkg-manager.desktop
chown -R gentoo:users /home/gentoo/Desktop/gentoo-pkg-manager.desktop
chmod +x /home/gentoo/Desktop/gentoo-pkg-manager.desktop

LC_ALL=C xdg-user-dirs-update --force

chown -R gentoo:users /home/gentoo

plymouth-set-default-theme gentoo-logo-new

ln -sf /usr/share/zoneinfo/UTC /etc/localtime

sed -i 's/#\(en_US\.UTF-8\)/\1/' /etc/locale.gen
locale-gen

chmod 0 /etc/sudoers
chown root:root /etc/sudoers
chmod 0440 /etc/sudoers 

rm -rf /usr/share/backgrounds/xfce

chown -R gentoo /tmp


## Wifi not available with networkmanager (BugFix)
echo "" >> /etc/NetworkManager/NetworkManager.conf
echo "[device]" >> /etc/NetworkManager/NetworkManager.conf
echo "wifi.scan-rand-mac-address=no" >> /etc/NetworkManager/NetworkManager.conf

chmod 644 /etc/passwd

chown root:root /etc/sudoers 
chmod 440 /etc/sudoers
chown -R root:root /etc/sudoers.d
chmod  755 /etc/sudoers.d 
chmod  440 /etc/sudoers.d/*

mkdir -p /usr/share/backgrounds/stormg
cp -r /usr/share/backgrounds/.* /usr/share/backgrounds/stormg


# Fix desktop file permissions to prevent "Untrusted application launcher" warnings
find "/home/gentoo/Desktop" -name "*.desktop" -exec chmod +x {} \; 2>/dev/null || true
chown -R "gentoo:gentoo" "/home/gentoo/Desktop"

sudo chmod +x /usr/local/bin/trust.sh
sudo chmod +x /usr/bin/gentoo-pkg-manager.sh
sudo chmod +x /usr/local/bin/stormg-welcome

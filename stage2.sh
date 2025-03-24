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

useradd -m -p "" -G "adm,audio,wheel,cdrom,usb,video,power,games,users,vboxusers,vboxguest,vmware,kvm,storage,rfkill,ntp" -s /bin/bash gentoo
chown -R gentoo:gentoo /home/gentoo
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
cp -v /xfce-configs/.config/autostart/dock.desktop /home/gentoo/.config/autostart/
cp -v /usr/share/applications/calamares.desktop /home/gentoo/.config/autostart/

chown -R gentoo:gentoo /home/gentoo/.config

chown -R gentoo:gentoo /home/gentoo/*

# User face image
cp /xfce-configs/.face /home/gentoo/.face

# Desktop icon setups
DESKTOP_APPS=( firefox chromium calamares )
for i in "${APPS[@]}"; do
	ln -sv /usr/share/applications/${i}.desktop Desktop/
done

groupadd -r autologin
gpasswd -a gentoo autologin

groupadd -r nopasswdlogin
gpasswd -a gentoo nopasswdlogin

cp -af /usr/share/applications/calamares.desktop /home/gentoo/Desktop/calamares.desktop
chown -R gentoo:users /home/gentoo/Desktop/calamares.desktop
chmod +x /home/gentoo/Desktop/calamares.desktop

cp -af /usr/share/applications/gentoo-pkg-manager.desktop /home/gentoo/Desktop/gentoo-pkg-manager.desktop
chown -R gentoo:users /home/gentoo/Desktop/gentoo-pkg-manager.desktop
chmod +x /home/gentoo/Desktop/gentoo-pkg-manager.desktop

groupadd lightdm

chage -E -1 lightdm

LC_ALL=C xdg-user-dirs-update --force

chown -R gentoo:users /home/gentoo

plymouth-set-default-theme natural-gentoo-remastered

ln -sf /usr/share/zoneinfo/UTC /etc/localtime

sed -i 's/#\(en_US\.UTF-8\)/\1/' /etc/locale.gen
locale-gen

chown 0 /etc/sudoers
chown root:root /etc/sudoers

rm -rf /usr/share/backgrounds/xfce

chown -R gentoo /tmp


## Wifi not available with networkmanager (BugFix)
su -c 'echo "" >> /etc/NetworkManager/NetworkManager.conf'
su -c 'echo "[device]" >> /etc/NetworkManager/NetworkManager.conf'
su -c 'echo "wifi.scan-rand-mac-address=no" >> /etc/NetworkManager.conf'

#!/bin/bash
source /etc/profile
export PS1="(chroot) ${PS1}"

BOOT_MODE=$(< /root/boot_mode.conf)
TIMEZONE=$(< /root/timezone.conf)
LOCALE=$(< /root/locale.conf)
USERNAME=$(cut -d':' -f1 < /root/user.conf)
USERPASS=$(cut -d':' -f2 < /root/user.conf)
ROOTPASS=$(cut -d':' -f2 < /root/root.conf)

emerge-webrsync
eselect profile set default/linux/amd64/23.0/desktop
emerge --sync

# Locale and Timezone
if [[ -f /root/timezone.conf ]]; then
  TIMEZONE=$(< /root/timezone.conf)
  echo "$TIMEZONE" > /etc/timezone
  emerge --config sys-libs/timezone-data
fi

if [[ -f /root/locale.conf ]]; then
  LOCALE=$(< /root/locale.conf)
  echo "$LOCALE UTF-8" > /etc/locale.gen
  locale-gen
  eselect locale set "$LOCALE"
  env-update && source /etc/profile
fi

# Hostname
echo "stormos" > /etc/hostname

# Network
dialog --title "Network Setup" --menu "Choose networking type" 10 60 2 \
1 "Ethernet (wired)" \
2 "Wi-Fi (wireless)" 2> /tmp/net_choice
NET_CHOICE=$(< /tmp/net_choice)

if [[ "$NET_CHOICE" == "1" ]]; then
  emerge net-misc/netifrc
  echo 'config_eth0="dhcp"' >> /etc/conf.d/net
  ln -s /etc/init.d/net.lo /etc/init.d/net.eth0
  rc-update add net.eth0 default
else
  emerge net-wireless/wpa_supplicant net-wireless/iw net-misc/dhcpcd
  rc-update add dhcpcd default
fi

# Kernel
emerge sys-kernel/gentoo-kernel-bin

# Microcode and initramfs
CPU_VENDOR=$(lscpu | grep 'Vendor ID' | awk '{print $3}')

if [[ "$CPU_VENDOR" == "GenuineIntel" ]]; then
  emerge sys-kernel/intel-microcode sys-kernel/dracut sys-kernel/genkernel-next
  dracut --force
elif [[ "$CPU_VENDOR" == "AuthenticAMD" ]]; then
  emerge sys-kernel/dracut sys-kernel/genkernel-next
  dracut --force
fi

# Bootloader
emerge sys-boot/grub efibootmgr dosfstools
if [[ "$BOOT_MODE" == "uefi" ]]; then
  grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=gentoo --recheck
else
  grub-install --target=i386-pc /dev/sda
fi

# Update GRUB with microcode if available
sed -i 's/^GRUB_CMDLINE_LINUX="/GRUB_CMDLINE_LINUX="initrd=\/boot\/intel-ucode.img initrd=\/boot\/amd-ucode.img /' /etc/default/grub || true
grub-mkconfig -o /boot/grub/grub.cfg

# Users
useradd -m -G users,wheel,audio,video -s /bin/bash "$USERNAME"
echo "$USERNAME:$USERPASS" | chpasswd
echo "root:$ROOTPASS" | chpasswd

# Desktop
emerge xfce-base/xfce4 lightdm lightdm-gtk-greeter
rc-update add dbus default
rc-update add lightdm default

mkdir -p /etc/lightdm
cat <<EOF > /etc/lightdm/lightdm.conf
[Seat:*]
autologin-user=$USERNAME
autologin-session=xfce
EOF

# Copy postinstall
cp /root/postinstall.sh /home/$USERNAME/
chmod +x /home/$USERNAME/postinstall.sh
chown $USERNAME:$USERNAME /home/$USERNAME/postinstall.sh

echo "✅ Chroot setup complete. You may now reboot and log in."

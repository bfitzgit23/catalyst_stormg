#!/bin/bash -e
#
##############################################################################
#
#  PostInstall is free software; you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation; either version 3 of the License, or
#  (at your discretion) any later version.
#
#  PostInstall is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#
##############################################################################
echo "FONT=ter-p16n" >> /etc/vconsole.conf

#!/bin/bash
# /etc/calamares/scripts/post-install.sh

# Mount live ISO if needed
mkdir -p /mnt/cdrom
mount /dev/sr0 /mnt/cdrom 2>/dev/null || true

# Generate fstab
genfstab -U /mnt >> /mnt/etc/fstab

# Chroot setup
chroot /mnt /bin/bash <<EOF
  # Root password
  echo "root:gentoo" | chpasswd

  # Enable services
  rc-update add elogind boot
  rc-update add dbus default
  rc-update add NetworkManager default
  rc-update add dmcrypt boot  # LUKS

  # GRUB (BIOS + UEFI)
  grub-install --target=i386-pc /dev/sda
  grub-install --target=x86_64-efi --efi-directory=/boot/efi --removable
  grub-mkconfig -o /boot/grub/grub.cfg

  # LUKS crypttab
  if [ -n "\$(lsblk -o FSTYPE | grep crypto_LUKS)" ]; then
    echo "luksroot UUID=\$(blkid -s UUID -o value /dev/sda2) none luks" >> /etc/crypttab
EOF

mkdir -p /usr/share/backgrounds/xfce
cp /usr/share/backgrounds/.* /usr/share/backgrounds/xfce/ || true

sudo chmod +x /usr/local/bin/trust.sh

# Continue cleanup
rm /usr/local/bin/postinstall.sh

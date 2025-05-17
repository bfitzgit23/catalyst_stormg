#!/bin/bash
set -e

echo "⚙️  Welcome to StormOS Gentoo Installer"
lsblk
read -p "Enter the target drive (e.g. /dev/sda): " DRIVE

read -p "WARNING: This will erase all data on $DRIVE. Continue? (y/N): " CONFIRM
[[ "$CONFIRM" != "y" ]] && echo "Cancelled." && exit 1

# Partitioning
cfdisk "$DRIVE"

read -p "Enter root partition: " ROOT_PART
read -p "Enter EFI partition (blank for BIOS): " EFI_PART
read -p "Enter swap partition (optional): " SWAP_PART

# Boot mode
echo "Select boot mode:"
select BOOT_MODE in "UEFI" "BIOS"; do
    case $BOOT_MODE in
        UEFI ) BOOT_MODE="uefi"; break ;;
        BIOS ) BOOT_MODE="bios"; break ;;
    esac
done

mkfs.ext4 "$ROOT_PART"
[[ "$BOOT_MODE" == "uefi" && -n "$EFI_PART" ]] && mkfs.vfat -F 32 "$EFI_PART"
[[ -n "$SWAP_PART" ]] && mkswap "$SWAP_PART" && swapon "$SWAP_PART"

mount "$ROOT_PART" /mnt/gentoo
mkdir -p /mnt/gentoo/boot
[[ "$BOOT_MODE" == "uefi" ]] && mkdir -p /mnt/gentoo/boot/efi && mount "$EFI_PART" /mnt/gentoo/boot/efi

# Stage3
cd /mnt/gentoo
wget https://gentoo.osuosl.org/releases/amd64/autobuilds/current-stage3-amd64-desktop-openrc/stage3-amd64-desktop-openrc-20250511T165428Z.tar.xz
tar xpf stage3-*.tar.xz --xattrs-include='*.*' --numeric-owner
rm stage3-*.tar.xz

cp -L /etc/resolv.conf /mnt/gentoo/etc/
mount --types proc /proc /mnt/gentoo/proc
mount --rbind /sys /mnt/gentoo/sys
mount --make-rslave /mnt/gentoo/sys
mount --rbind /dev /mnt/gentoo/dev
mount --make-rslave /mnt/gentoo/dev

# Prompt for user setup and config
# Use dialog for configuration
emerge -v --root=/mnt/gentoo --ask=n app-misc/dialog sys-libs/ncurses

USER_TIMEZONE=$(dialog --stdout --inputbox "Enter desired timezone (e.g. Europe/London):" 8 60)
USER_LOCALE=$(dialog --stdout --inputbox "Enter desired locale (e.g. en_US.UTF-8):" 8 60)
NEW_USER=$(dialog --stdout --inputbox "Enter new username:" 8 40)
USER_PASS="stormos"
ROOT_PASS="stormos"

echo "$BOOT_MODE" > /mnt/gentoo/boot_mode.conf
echo "$USER_TIMEZONE" > /mnt/gentoo/timezone.conf
echo "$USER_LOCALE" > /mnt/gentoo/locale.conf
echo "$NEW_USER:$USER_PASS" > /mnt/gentoo/user.conf
echo "root:$ROOT_PASS" > /mnt/gentoo/root.conf

# Add basic packages needed in chroot

# Auto-detect GPU type
GPU_TYPE="unknown"

if lspci | grep -iq 'NVIDIA'; then
    GPU_TYPE="nvidia"
fi
if lspci | grep -iq 'AMD'; then
    if [[ "$GPU_TYPE" == "nvidia" ]]; then
        GPU_TYPE="hybrid-amd-nvidia"
    else
        GPU_TYPE="amd"
    fi
fi
if lspci | grep -iq 'Intel'; then
    if [[ "$GPU_TYPE" == "nvidia" ]]; then
        GPU_TYPE="hybrid-intel-nvidia"
    elif [[ "$GPU_TYPE" == "amd" ]]; then
        GPU_TYPE="hybrid-intel-amd"
    else
        GPU_TYPE="intel"
    fi
fi

# Fallback if unknown
if [[ "$GPU_TYPE" == "unknown" ]]; then
    GPU_TYPE="intel amdgpu nvidia"
fi

case "$GPU_TYPE" in
    intel)
        VIDEO_CARDS="intel i965 i915"
        ;;
    amd)
        VIDEO_CARDS="amdgpu radeonsi radeon"
        ;;
    nvidia)
        VIDEO_CARDS="nvidia"
        ;;
    hybrid-intel-nvidia)
        VIDEO_CARDS="intel i965 i915 nvidia"
        ;;
    hybrid-intel-amd)
        VIDEO_CARDS="intel i965 i915 amdgpu radeonsi"
        ;;
    hybrid-amd-nvidia)
        VIDEO_CARDS="amdgpu radeonsi nvidia"
        ;;
    *)
        VIDEO_CARDS="intel i965 i915 amdgpu radeonsi radeon nouveau nvidia"
        ;;
esac

INPUT_DEVICES="libinput synaptics evdev"

# Set make.conf desktop use flags

# Include firmware based on selected GPU
mkdir -p /mnt/gentoo/etc/portage/package.license
cat <<EOF > /mnt/gentoo/etc/portage/package.license/stormos
sys-kernel/linux-firmware @BINARY-REDISTRIBUTABLE
EOF

mkdir -p /mnt/gentoo/etc/portage/package.accept_keywords
cat <<EOF > /mnt/gentoo/etc/portage/package.accept_keywords/firmware
sys-kernel/linux-firmware
EOF

cat <<EOF >> /mnt/gentoo/etc/portage/make.conf
USE="X alsa dbus pulseaudio udev branding wayland vulkan egl pipewire -systemd"
VIDEO_CARDS="$VIDEO_CARDS"
INPUT_DEVICES="$INPUT_DEVICES"
EOF
mkdir -p /mnt/gentoo/etc/portage/package.accept_keywords
mkdir -p /mnt/gentoo/etc/portage/package.use

# Add firmware and required packages
# Conditionally install relevant firmware for selected GPU
case "$GPU_TYPE" in
    intel | hybrid-intel-*)
        FIRMWARE_PACKAGES="sys-kernel/linux-firmware intel-microcode net-wireless/iwlwifi-ax200-firmware"
        FIRMWARE_PACKAGES="sys-kernel/linux-firmware intel-microcode"
        ;;
    amd | hybrid-intel-amd | hybrid-amd-nvidia)
        FIRMWARE_PACKAGES="sys-kernel/linux-firmware amd-ucode"
        ;;
    nvidia | hybrid-*-nvidia)
        FIRMWARE_PACKAGES="sys-kernel/linux-firmware"
        ;;
    *)
        FIRMWARE_PACKAGES="sys-kernel/linux-firmware"
        ;;
esac

echo "Installing firmware packages: $FIRMWARE_PACKAGES"
emerge -v --root=/mnt/gentoo --ask=n $FIRMWARE_PACKAGES

# Automate package.accept_keywords and package.use
cat <<EOF > /mnt/gentoo/etc/portage/package.accept_keywords/stormos
app-misc/dialog
sys-libs/ncurses
gui-wm/hyprland
www-client/firefox-bin
EOF

echo "gui-wm/hyprland" >> /mnt/gentoo/etc/portage/package.accept_keywords
echo "www-client/firefox-bin" >> /mnt/gentoo/etc/portage/package.accept_keywords

# Copy and chroot script detection
SCRIPT_DIR=$(dirname "$(realpath "$0")")

if [[ ! -f "$SCRIPT_DIR/install_inside_chroot.sh" ]]; then
    echo "❌ Error: install_inside_chroot.sh not found in $SCRIPT_DIR"
    exit 1
fi
cp "$SCRIPT_DIR/install_inside_chroot.sh" /mnt/gentoo/root/
chmod +x /mnt/gentoo/root/install_inside_chroot.sh

if [[ ! -f "$SCRIPT_DIR/postinstall.sh" ]]; then
    echo "❌ Error: postinstall.sh not found in $SCRIPT_DIR"
    exit 1
fi
cp "$SCRIPT_DIR/postinstall.sh" /mnt/gentoo/root/
chmod +x /mnt/gentoo/root/postinstall.sh

# Generate fstab
BOOT_UUID=$(blkid -s UUID -o value "$ROOT_PART")
echo "UUID=$BOOT_UUID / ext4 noatime 0 1" >> /mnt/gentoo/etc/fstab
[[ -n "$EFI_PART" ]] && EFI_UUID=$(blkid -s UUID -o value "$EFI_PART") && echo "UUID=$EFI_UUID /boot/efi vfat defaults,noatime 0 2" >> /mnt/gentoo/etc/fstab
[[ -n "$SWAP_PART" ]] && SWAP_UUID=$(blkid -s UUID -o value "$SWAP_PART") && echo "UUID=$SWAP_UUID none swap sw 0 0" >> /mnt/gentoo/etc/fstab

# Chroot
chroot /mnt/gentoo /bin/bash -c "/root/install_inside_chroot.sh"

# Cleanup
umount -l /mnt/gentoo/dev{/shm,/pts,}
umount -R /mnt/gentoo
reboot

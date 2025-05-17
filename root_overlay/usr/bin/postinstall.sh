#!/bin/bash
set -e

source /etc/profile

USER=$(whoami)

if [[ $EUID -ne 0 ]]; then
  echo "❌ Please run this script as root or with sudo."
  exit 1
fi

DIALOG_TITLE="StormOS Postinstall"

# Choose additional packages
exec 3>&1
SELECTIONS=$(dialog --separate-output --checklist "Select components to install:" 20 70 10 \
1 "Bluetooth support (bluez)" off \
2 "Printing (cups, gutenprint, hplip)" off \
3 "VirtualBox Guest additions" off \
4 "VMware support" off \
5 "Firefox-bin web browser" on \
6 "Ja'koolit's Hyprland desktop" off \
7 "XFCE desktop (already installed)" on \
8 "LightDM GTK Greeter" on \
2>&1 1>&3)
exec 3>&-

# Convert selection into packages
PKGS="x11-base/xorg-server x11-drivers/xorg-drivers x11-apps/xinit"
for CHOICE in $SELECTIONS; do
  case $CHOICE in
    1) PKGS+=" net-wireless/bluez bluez-utils blueman";;
    2) PKGS+=" net-print/cups net-print/gutenprint net-print/hplip";;
    3) PKGS+=" app-emulation/virtualbox-guest-additions";;
    4) PKGS+=" app-emulation/open-vm-tools";;
    5) PKGS+=" www-client/firefox-bin";;
    6) PKGS+=" gui-wm/hyprland dev-cpp/sdbus";;
    8) PKGS+=" x11-misc/lightdm-gtk-greeter";;
  esac
done

# Enable GURU overlay
emerge --quiet app-eselect/eselect-repository
eselect repository enable guru
emaint sync -r guru

mkdir -p /etc/portage/package.accept_keywords
cat <<EOF > /etc/portage/package.accept_keywords/guru
*/*::guru
EOF

cat <<EOF > /etc/portage/package.accept_keywords/sdbus
=dev-cpp/sdbus-0.10.0
EOF

# Install selected packages
if [[ -n "$PKGS" ]]; then
  echo "📦 Installing: $PKGS"
  emerge --quiet --update --newuse $PKGS
fi

# Detect VM environment
VM_VENDOR=$(dmidecode -s system-manufacturer 2>/dev/null || echo "")
if echo "$VM_VENDOR" | grep -iq "VirtualBox"; then
  echo "💡 VirtualBox detected, installing guest additions..."
  emerge --quiet app-emulation/virtualbox-guest-additions
  rc-update add virtualbox-guest-additions default
elif echo "$VM_VENDOR" | grep -iq "VMware"; then
  echo "💡 VMware detected, installing open-vm-tools..."
  emerge --quiet app-emulation/open-vm-tools
  rc-update add vmtoolsd default
fi

# Set up Ja'koolit's Hyprland config if selected
if echo "$SELECTIONS" | grep -q "6"; then
  echo "🎨 Applying Ja'koolit's Hyprland config..."
  emerge --quiet \
    dev-vcs/git \
    wayland \
    x11-terms/kitty \
    gui-apps/hyprpaper \
    gui-apps/waybar \
    gui-apps/wlr-randr \
    gui-libs/xdg-desktop-portal-hyprland \
    x11-misc/xdg-utils \
    media-video/pipewire \
    media-video/wireplumber \
    media-fonts/jetbrains-mono \
    media-fonts/noto \
    media-fonts/noto-emoji \
    media-fonts/fontawesome \
    x11-themes/qogir-icon-theme \
    x11-themes/flat-remix-gtk

  su - $USER -c '
    git clone https://github.com/JaKooLit/Hyprland-Dots ~/.config/Hyprland-Dots
    cp -r ~/.config/Hyprland-Dots/hypr ~/.config/hypr
    cp -r ~/.config/Hyprland-Dots/waybar ~/.config/
    cp -r ~/.config/Hyprland-Dots/wofi ~/.config/
    if [ -d ~/.config/Hyprland-Dots/wallpaper ]; then
      mkdir -p ~/.config/wallpaper
      cp ~/.config/Hyprland-Dots/wallpaper/* ~/.config/wallpaper/
    fi
    if [ -d ~/.config/Hyprland-Dots/gtk-3.0 ]; then
      mkdir -p ~/.config/gtk-3.0
      cp -r ~/.config/Hyprland-Dots/gtk-3.0/* ~/.config/gtk-3.0/
    fi
    if [ -f ~/.config/Hyprland-Dots/.bashrc ]; then
      cat ~/.config/Hyprland-Dots/.bashrc >> ~/.bashrc
    fi
    if [ -f ~/.config/Hyprland-Dots/.zshrc ]; then
      cat ~/.config/Hyprland-Dots/.zshrc >> ~/.zshrc
    fi
  '
fi

# Theme and system asset integration
echo "🎨 Installing shared system themes and boot assets..."
git clone https://github.com/bfitzgit23/catalyst_stormg /tmp/stormg-resources

# Copy /usr/share excluding calamares
rsync -a --exclude='calamares' /tmp/stormg-resources/root_overlay/usr/share/ /usr/share/

# GRUB theme
mkdir -p /boot/grub/themes
cp -r /tmp/stormg-resources/root_overlay/boot/grub/themes/* /boot/grub/themes/
echo 'GRUB_THEME="/boot/grub/themes/natural-gentoo-remastered/theme.txt"' >> /etc/default/grub
sed -i 's/GRUB_CMDLINE_LINUX="/GRUB_CMDLINE_LINUX="splash /' /etc/default/grub
grub-mkconfig -o /boot/grub/grub.cfg

# Plymouth theme
mkdir -p /etc/plymouth
cp -r /tmp/stormg-resources/root_overlay/etc/plymouth/* /etc/plymouth/
plymouth-set-default-theme -R natural-gentoo-remastered
rc-update add splash default
echo 'splash' >> /etc/conf.d/rc

# XFCE configs
mkdir -p /etc/skel/.config
cp -r /tmp/stormg-resources/root_overlay/xfce-configs/* /etc/skel/.config/

# Clean up
rm -rf /tmp/stormg-resources

clear
echo "✅ Postinstall complete. You can now log into your system with XFCE or Hyprland."
echo "👉 Tip: To start Hyprland, log into a Wayland session or run \`Hyprland\` from tty."
dialog --msgbox "Postinstall finished. You may now reboot or explore the system."

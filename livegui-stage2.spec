subarch: amd64
version_stamp: stormg-02-04-2025
target: livecd-stage2
rel_type: default
profile: 2default/linux/amd64/23.0/desktop
snapshot_treeish: bd6107dbebe71859f12618eb0669c5d110c9b076
source_subpath: default/livecd-stage1-amd64-stormg-02-04-2025
portage_confdir: /home/ben/Desktop/catalyst_stormg/config/stages
repos: /home/ben/Desktop/catalyst_stormg/overlay/var/db/repos/guru
/home/ben/Desktop/catalyst_stormg/overlay/var/db/repos/tezeta
/home/ben/Desktop/catalyst_stormg/overlay/var/db/repos/tatsh-overlay
/home/ben/Desktop/catalyst_stormg/overlay/var/db/repos/edgets
/home/ben/Desktop/catalyst_stormg/overlay/var/db/repos/steam-overlay


livecd/bootargs: overlayfs nodhcp dokeymap dodetect dousb quiet splash zram.num_devices=1
livecd/depclean: no
livecd/fstype: squashfs
livecd/iso: StormG_latest_xfce_02-04-2025.iso
livecd/type: gentoo-release-livecd
livecd/volid: StormGenZ_LiveDVD_02-04-2025
livecd/readme: Welcome to StormG, making Gentoo GNU/Linux easy for anyone, pro or newbie! Containing the famous calamares installer, a highly customized XFCE desktop, bash aliases in the users .bashrc in their home directory, oh-my-bash to simplify bash usage and more!
livecd/motd: "Welcome to StormG"
livecd/users: gentoo
livecd/root_overlay: /home/ben/Desktop/catalyst_stormg/root_overlay
livecd/overlay: /home/ben/Desktop/catalyst_stormg/overlay

livecd/fsscript: /home/ben/Desktop/catalyst_stormg//stage2.sh
livecd/rcadd: udev|sysinit udev-mount|sysinit acpid|default dbus|default gpm|default NetworkManager|default bluetooth|default elogind|boot alsasound|boot ntpd|default display-manager|default cupsd|default sshd|default ntpd|default syslog-ng|default cronie|default bluetooth|&lt;/nowikidefault samba&lt;nowiki&gt;|default
boot/kernel/gentoo/use: atm png truetype usb plymouth -systemd elogind
livecd/empty:
	/var/db/repos
	/usr/src

boot/kernel: gentoo

boot/kernel/gentoo/sources: gentoo-sources
boot/kernel/gentoo/config: /home/ben/Desktop/catalyst_stormg/kconfig/livegui-amd64-5.15.23.config
boot/kernel/gentoo/packages: net-wireless/broadcom-sta

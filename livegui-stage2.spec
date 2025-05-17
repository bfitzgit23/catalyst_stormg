subarch: amd64
version_stamp: stormg-05-10-2025
target: livecd-stage2
rel_type: 23.0-default
profile: default/linux/amd64/23.0/desktop
snapshot_treeish: 5618e53f3cbb024f1a75815bcd50ceaf98f5d97a
source_subpath: 23.0-default/livecd-stage1-amd64-stormg-05-10-2025
portage_confdir: /home/ben/Desktop/Backups/catalyst_stormg/config/stages
repos: /home/ben/Desktop/Backups/catalyst_stormg/overlay/var/db/repos/guru
/home/ben/Desktop/Backups/catalyst_stormg/overlay/var/db/repos/steam-overlay
/home/ben/Desktop/Backups/catalyst_stormg/overlay/var/db/repos/gentoo


livecd/bootargs: overlayfs nodhcp dokeymap dodetect dousb quiet splash zram.num_devices=1
livecd/depclean: no
livecd/fstype: squashfs
livecd/iso: StormG_latest_xfce_05-10-2025.iso
livecd/type: gentoo-release-livecd
livecd/volid: StormGenZ_LiveDVD_05-10-2025
livecd/readme: Welcome to StormG, making Gentoo GNU/Linux easy for anyone, pro or newbie! Containing the famous calamares installer, a highly customized xfce desktop, bash aliases in the users .bashrc in their home directory, oh-my-bash to simplify bash usage and more!
livecd/motd: "Welcome to StormG"
livecd/users: gentoo
livecd/root_overlay: /home/ben/Desktop/Backups/catalyst_stormg/root_overlay
livecd/overlay: /home/ben/Desktop/Backups/catalyst_stormg/overlay
livecd/gk_mainargs: --plymouth --plymouth-theme=spinfinity

livecd/fsscript: /home/ben/Desktop/Backups/catalyst_stormg/stage2.sh
livecd/rcadd: udev|sysinit udev-mount|sysinit acpid|default dbus|default gpm|default NetworkManager|default bluetooth|default elogind|boot alsasound|boot ntpd|default display-manager|default cupsd|default sshd|default ntpd|default syslog-ng|default cronie|default bluetooth|default samba|default
livecd/empty:
	/var/db/repos
	/usr/src

boot/kernel: gentoo

boot/kernel/gentoo/sources: gentoo-sources
boot/kernel/gentoo/config: /home/ben/Desktop/Backups/catalyst_stormg/kconfig/livegui-amd64-5.15.23.config
boot/kernel/gentoo/packages: net-wireless/broadcom-sta

subarch: amd64
version_stamp: stormg-04-14-2026
target: livecd-stage2
rel_type: 23.0-default
profile: default/linux/amd64/23.0/desktop/plasma
snapshot_treeish: b11812afa107052d72ed03fae60484d90444b091
source_subpath: 23.0-default/livecd-stage1-amd64-stormg-03-09-2026
portage_confdir: /home/bennji/Desktop/catalyst_stormg/config/stages
repos: /home/bennji/Desktop/catalyst_stormg/overlay/var/db/repos/guru
/home/bennji/Desktop/catalyst_stormg/overlay/var/db/repos/steam-overlay
/home/bennji/Desktop/catalyst_stormg/overlay/var/db/repos/gentoo


livecd/bootargs: overlayfs nodhcp dokeymap dodetect dousb quiet splash zram.num_devices=1
livecd/depclean: no
livecd/fstype: squashfs
livecd/iso: StormG_latest_xfce_03-09-2026.iso
livecd/type: gentoo-release-livecd
livecd/volid: StormG_LiveDVD_03-09-2026
livecd/readme: Welcome to StormG, making Gentoo GNU/Linux easy for anyone, pro or newbie! Containing the famous calamares installer, a highly customized xfce desktop, bash aliases in the users .bashrc in their home directory, oh-my-bash to simplify bash usage and more!
livecd/motd: "Welcome to StormG"
livecd/users: gentoo
livecd/root_overlay: /home/bennji/Desktop/catalyst_stormg/root_overlay
livecd/overlay: /home/bennji/Desktop/catalyst_stormg/overlay
livecd/cdtar: /usr/share/catalyst/livecd/cdtar/grub-theme-gentoo_frosted.tar.bz2

livecd/fsscript: /home/bennji/Desktop/catalyst_stormg/stage2.sh
livecd/rcadd: udev|sysinit udev-mount|sysinit acpid|default dbus|default gpm|default NetworkManager|default bluetooth|default elogind|boot alsasound|boot ntpd|default display-manager|default cupsd|default sshd|default ntpd|default syslog-ng|default cronie|default bluetooth|default samba|default
livecd/empty:
	/var/db/repos
	/usr/src

boot/kernel: gentoo

boot/kernel/gentoo/distkernel: yes
boot/kernel/gentoo/dracut_args: --xz --no-hostonly -a dmsquash-live -a dmsquash-live-ntfs -a mdraid -o btrfs -o crypt -o i18n -o usrmount -o lunmask -o qemu -o qemu-net -o nvdimm -o plymouth -o multipath -i /lib/keymaps /lib/keymaps -I busybox
boot/kernel/gentoo/packages: --usepkg n broadcom-sta

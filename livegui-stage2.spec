subarch: amd64
version_stamp: stormg-04-14-2025
target: livecd-stage2
rel_type: default
profile: 2default/linux/amd64/23.0/desktop
snapshot_treeish: bd6107dbebe71859f12618eb0669c5d110c9b076
source_subpath: default/livecd-stage1-amd64-stormg-04-14-2025
portage_confdir: /home/ben/Desktop/catalyst_stormg/config/stages
repos: /home/ben/Desktop/catalyst_stormg/overlay/var/db/repos/guru
/home/ben/Desktop/catalyst_stormg/overlay/var/db/repos/tezeta
/home/ben/Desktop/catalyst_stormg/overlay/var/db/repos/tatsh-overlay
/home/ben/Desktop/catalyst_stormg/overlay/var/db/repos/edgets
/home/ben/Desktop/catalyst_stormg/overlay/var/db/repos/steam-overlay


livecd/bootargs: overlayfs nodhcp dokeymap dodetect dousb quiet splash zram.num_devices=1
livecd/depclean: no
livecd/fstype: squashfs
livecd/iso: StormG_latest_xfce_04-14-2025.iso
livecd/type: gentoo-release-livecd
livecd/volid: StormGenZ_LiveDVD_04-14-2025
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

boot/kernel/gentoo/distkernel: yes
boot/kernel/gentoo/dracut_args: --xz --no-hostonly -a dmsquash-live -a mdraid -o btrfs -o crypt -o i18n -o usrmount -o lunmask -o qemu -o qemu-net -o nvdimm -o multipath -o plymouth -i /lib/keymaps /lib/keymaps -I busybox
boot/kernel/gentoo/packages: net-wireless/broadcom-sta

livecd/unmerge:
	app-admin/eselect-ctags
	app-admin/eselect-vi
	app-admin/perl-cleaner
	app-admin/python-updater
	app-portage/gentoolkit
	app-arch/cpio
	dev-build/libtool
	dev-lang/rust-bin
	dev-libs/gmp
	dev-libs/libxml2
	dev-libs/mpfr
	dev-python/pycrypto
	dev-util/pkgconf
	perl-core/PodParser
	perl-core/Test-Harness
	sys-apps/debianutils
	sys-apps/diffutils
	sys-apps/groff
	sys-apps/man-db
	sys-apps/man-pages
	sys-apps/memtest86+
	sys-apps/miscfiles
	sys-apps/sandbox
	sys-apps/texinfo
	dev-build/autoconf
	dev-build/autoconf-wrapper
	dev-build/automake
	dev-build/automake-wrapper
	sys-devel/binutils
	sys-devel/binutils-config
	sys-devel/bison
	sys-devel/flex
	sys-devel/gcc
	sys-devel/gcc-config
	sys-devel/gettext
	sys-devel/gnuconfig
	sys-devel/m4
	dev-build/make
	sys-devel/patch
	sys-libs/db
	sys-libs/gdbm
	sys-kernel/dracut
	sys-kernel/gentoo-kernel
	sys-kernel/linux-headers

livecd/empty:
	/boot
	/etc/cron.daily
	/etc/cron.hourly
	/etc/cron.monthly
	/etc/cron.weekly
	/etc/kernel/config.d
	/etc/logrotate.d
	/etc/modules.autoload.d
	/etc/rsync
	/etc/runlevels/single
	/etc/skel
	/root/.ccache
	/tmp
	/usr/include
	/usr/local
	/usr/share/aclocal
	/usr/share/baselayout
	/usr/share/binutils-data
	/usr/share/consolefonts/partialfonts
	/usr/share/consoletrans
	/usr/share/dict
	/usr/share/doc
	/usr/share/emacs
	/usr/share/et
	/usr/share/gcc-data
	/usr/share/gettext
	/usr/share/glib-2.0
	/usr/share/gnuconfig
	/usr/share/gtk-doc
	/usr/share/i18n
	/usr/share/info
	/usr/share/lcms
	/usr/share/libtool
	/usr/share/man
	/usr/share/rfc
	/usr/share/ss
	/usr/share/state
	/usr/share/texinfo
	/usr/share/unimaps
	/usr/share/zoneinfo
	/usr/src
	/var/cache
	/var/empty
	/var/lib/portage
	/var/log
	/var/spool
	/var/state
	/var/tmp

livecd/rm:
	/etc/*-
	/etc/*.old
	/etc/default/audioctl
	/etc/dispatch-conf.conf
	/etc/etc-update.conf
	/etc/hosts.bck
	/etc/issue*
	/etc/man.conf
	/etc/resolv.conf
	/root/.bash_history
	/root/.viminfo
	/usr/bin/*.static
	/usr/bin/fsck.cramfs
	/usr/bin/fsck.minix
	/usr/bin/mkfs.bfs
	/usr/bin/mkfs.cramfs
	/usr/bin/mkfs.minix
	/usr/bin/addr2line
	/usr/share/consolefonts/1*
	/usr/share/consolefonts/7*
	/usr/share/consolefonts/8*
	/usr/share/consolefonts/9*
	/usr/share/consolefonts/A*
	/usr/share/consolefonts/C*
	/usr/share/consolefonts/E*
	/usr/share/consolefonts/G*
	/usr/share/consolefonts/L*
	/usr/share/consolefonts/M*
	/usr/share/consolefonts/R*
	/usr/share/consolefonts/a*
	/usr/share/consolefonts/c*
	/usr/share/consolefonts/dr*
	/usr/share/consolefonts/g*
	/usr/share/consolefonts/i*
	/usr/share/consolefonts/k*
	/usr/share/consolefonts/l*
	/usr/share/consolefonts/r*
	/usr/share/consolefonts/s*
	/usr/share/consolefonts/t*
	/usr/share/consolefonts/v*
	/usr/share/misc/*.old

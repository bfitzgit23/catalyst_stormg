# Copyright 1999-2024 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
EAPI=8

RUST_MIN_VER="1.71.1"

inherit systemd cargo git-r3 linux-info udev xdg

_PN="supergfxd"

DESCRIPTION="${PN} (${_PN}) Graphics switching"
HOMEPAGE="https://asus-linux.org"
SRC_URI="
    https://gitlab.com/asus-linux/${PN}/-/archive/${PV}/${PN}-${PV}.tar.gz
    https://gitlab.com/asus-linux/${PN}/uploads/31e1640ed949ba5d9f29e63d8d9ed016/vendor-${PV}.tar.xz -> vendor_${PN}_${PV}.tar.xz
"
LICENSE="MPL-2.0"
IUSE="gnome"
SLOT="5/5.1.2"
KEYWORDS="~amd64"
RESTRICT="mirror"

BDEPEND="
    !!<sys-power/asusctl-4.6.0
    !!<sys-power/${PN}-5.0.0
"
RDEPEND="
    gnome? (
        x11-apps/xrandr
        gnome-base/gdm
        gnome-extra/gnome-shell-extension-supergfxctl-gex
    )
    sys-process/lsof
"
DEPEND="${BDEPEND}
    ${RDEPEND}
    sys-apps/systemd:0=
	sys-apps/dbus
"
PATCHES="
    ${FILESDIR}/${P}-vkicd.patch
"

S="${WORKDIR}/${PN}-${PV}"
QA_PRESTRIPPED="
    /usr/bin/${PN}
    /usr/bin/${_PN}
"

src_unpack() {
    cargo_src_unpack
    unpack ${PN}-${PV}.tar.gz

    # adding vendor-package
    cd ${S} && unpack vendor_${PN}_${PV%%_*}.tar.xz
}

src_prepare() {
    require_configured_kernel

    # checking for needed kernel-modules since v3.2.0
    k_wrn_vfio=""
    linux_chkconfig_module VFIO || k_wrn_vfio="${k_wrn_vfio}> CONFIG_VFIO should be enabled as module\n"
    linux_chkconfig_module VFIO_IOMMU_TYPE1 || k_wrn_vfio="${k_wrn_vfio}> CONFIG_VFIO_IOMMU_TYPE1 should be enabled as module\n"
    linux_chkconfig_module VFIO_MDEV || k_wrn_vfio="${k_wrn_vfio}> CONFIG_VFIO_MDEV should be enabled as module\n"
    linux_chkconfig_module VFIO_PCI || k_wrn_vfio="${k_wrn_vfio}> CONFIG_VFIO_PCI should be enabled as module\n"
    linux_chkconfig_module VFIO_VIRQFD || k_wrn_vfio="${k_wrn_vfio}> CONFIG_VFIO_VIRQFD should be enabled as module\n"
    if [[ ${k_wrn_vfio} != "" ]]; then 
        ewarn "\nKernel configuration issue(s), needed for switching gfx vfio mode (disabled by default):\n\n${k_wrn_vfio}"
    else
        ## enabeling fvio mode
        einfo "Kernel configuration matches FVIO requirements. (enabeling now vfio gfx switch by default)"
        sed -i 's/gfx_vfio_enable:\ false,/gfx_vfio_enable:\ true,/g' ${S}/src/config.rs || die "Could not enable VFIO."
    fi

    # adding vendor package config
    mkdir -p ${S}/.cargo && cp ${FILESDIR}/${P}-vendor_config ${S}/.cargo/config

    # removing Cargo.lock (seems outdated!)
    rm -f ${S}/Cargo.lock

    default
    rust_pkg_setup
}

src_compile() {
    cargo_gen_config
    cargo_src_compile

    # cargo is using a different target-path during compilation (correcting it)
    [ -d `cargo_target_dir` ] && mv -f "`cargo_target_dir`/"* ./target/release/
}

src_install() {
    insinto /lib/udev/rules.d/
    doins data/*${_PN}*.rules
    
    ## mod blacklisting
    insinto /etc/modprobe.d
    doins ${FILESDIR}/90-nvidia-blacklist.conf

    # xrandr settings for nvidia-primary (gnome x11 only, will autofail on non-nvidia as primary or wayland)
    if use gnome; then
        insinto /etc/xdg/autostart
        doins "${FILESDIR}"/xrandr-nvidia.desktop

        insinto /usr/share/gdm/greeter/autostart
        doins "${FILESDIR}"/xrandr-nvidia.desktop
    else
        ewarn "you're not using gnome, please make sure to run the following, when logging into your WM/DM: \n \
\`xrandr --setprovideroutputsource modesetting NVIDIA-0\; xrandr --auto\`\n \
Possible locations are ~/.xinitrc, /etc/sddm/Xsetup, etc.\n"
    fi

    insinto /usr/share/dbus-1/system.d/
    doins data/org.${PN}.Daemon.conf

    systemd_dounit data/${_PN}.service

    insinto /usr/lib/systemd/user-preset/
    doins data/${_PN}.preset

    default
}

pkg_postinst() {
    xdg_icon_cache_update
    udev_reload

    ewarn "Don't forget to reload dbus to enable \"${_PN}\" service, \
by runnning:\n \`systemctl daemon-reload && systemctl enable --now ${_PN}\`\n"

    x11_warn_conf=""
    for c in `grep -il nvidia /etc/X11/xorg.conf.d/*.*`; do 
        if ! `grep -q ${_PN} "$c"` && [[ "$c" != *"90-${_PN}-nvidia-pm.rules" ]]; then
            x11_warn_conf="$x11_warn_conf$c\n";
        fi
    done
    [[ "$x11_warn_conf" == "" ]] || ewarn "WARNING: Potential inteferring files found:\n$x11_warn_conf"
}

pkg_postrm() {
    xdg_icon_cache_update
    udev_reload
}

# Copyright 1999-2024 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
EAPI=8

RUST_MIN_VER="1.71.1"
CRATES="
aho-corasick-0.7.18
async-io-1.7.0
atty-0.2.14
autocfg-1.1.0
bitflags-1.2.1
byteorder-1.4.3
cache-padded-1.2.0
cc-1.0.73
cfg-if-1.0.0
concurrent-queue-1.2.2
derivative-2.2.0
enumflags2-0.6.4
enumflags2_derive-0.6.4
env_logger-0.8.4
fastrand-1.7.0
futures-0.3.21
futures-channel-0.3.21
futures-core-0.3.21
futures-executor-0.3.21
futures-io-0.3.21
futures-lite-1.12.0
futures-macro-0.3.21
futures-sink-0.3.21
futures-task-0.3.21
futures-util-0.3.21
gumdrop-0.8.1
gumdrop_derive-0.8.1
hermit-abi-0.1.19
humantime-2.1.0
instant-0.1.12
itoa-1.0.2
libc-0.2.126
log-0.4.17
logind-zbus-0.7.1
memchr-2.5.0
memoffset-0.6.5
nb-connect-1.2.0
nix-0.20.2
once_cell-1.12.0
parking-2.0.0
pin-project-lite-0.2.9
pin-utils-0.1.0
polling-2.2.0
proc-macro-crate-0.1.5
proc-macro-crate-1.1.3
proc-macro2-1.0.40
quote-1.0.20
regex-1.5.6
regex-syntax-0.6.26
ryu-1.0.10
scoped-tls-1.0.0
serde-1.0.137
serde_derive-1.0.137
serde_json-1.0.81
serde_repr-0.1.8
slab-0.4.6
socket2-0.4.4
static_assertions-1.1.0
syn-1.0.98
termcolor-1.1.3
thiserror-1.0.31
thiserror-impl-1.0.31
toml-0.5.9
unicode-ident-1.0.1
waker-fn-1.1.0
wepoll-ffi-0.1.2
winapi-0.3.9
winapi-i686-pc-windows-gnu-0.4.0
winapi-util-0.1.5
winapi-x86_64-pc-windows-gnu-0.4.0
zbus-1.9.2
zbus_macros-1.9.2
zvariant-2.10.0
zvariant_derive-2.10.0"

inherit systemd cargo git-r3 linux-info udev xdg

_PN="supergfxd"

DESCRIPTION="${PN} (${_PN}) Graphics switching"
HOMEPAGE="https://asus-linux.org"
SRC_URI="
    https://gitlab.com/asus-linux/${PN}/-/archive/${PV}/${PN}-${PV}.tar.gz
    "$(cargo_crate_uris)"
"

LICENSE="MPL-2.0"
IUSE="gnome"
SLOT="4/4.0.5"
KEYWORDS="~amd64"
RESTRICT="mirror"

BDEPEND="
    !!sys-power/${PN}:0
    !!sys-power/${PN}:5
    !!<=sys-power/asusctl-4.0.0
"
RDEPEND="
    gnome? (
        x11-apps/xrandr
        gnome-base/gdm
    )
"
DEPEND="${BDEPEND}
    ${RDEPEND}
    sys-apps/systemd:0=
	sys-apps/dbus
"

S="${WORKDIR}/${PN}-${PV}"
QA_PRESTRIPPED="
    /usr/bin/${PN}
    /usr/bin/${_PN}
"

src_unpack() {
    cargo_src_unpack
    unpack ${PN}-${PV}.tar.gz
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

    # fix nvidia as primary (might be gentoo specific)
    # this enables modesetting modules and nvidia as a device entry in the generated 90-nvidia-primary.conf (if siwtched to nvidia as primary)
    sed -i '/Option\ "PrimaryGPU"\ "true"/c\EndSection\n\nSection\ "Module"\n\tLoad\ "modesetting"\nEndSection\n\nSection\ "Device"\n\tIdentifier\ "nvidia"\n\tDriver\ "nvidia"\n\tOption\ "AllowEmptyInitialConfiguration"\ "true"\n\tOption\ "PrimaryGPU"\ "true""#;' \
        ${S}/src/lib.rs || die "Can't add nvidia device section to the gfx switcher."

    default
    rust_pkg_setup
}

src_compile() {
    cargo_gen_config
    default
}

src_install() {
    insinto /lib/udev/rules.d/
    doins data/*${_PN}*.rules
    
    ## mod blacklisting
    insinto /etc/modprobe.d
    doins ${FILESDIR}/90-nvidia-blacklist.conf

    # xrandr settings for nvidia-primary (gnome only, will autofail on non-nvidia as primary)
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
        # TODO: 
        # should we be backwards compatible? 
        # (! `grep -q asusd "$c"` && [[ "$c" != *"90-asusd-nvidia-pm.rules" ]])
    done
    [[ "$x11_warn_conf" == "" ]] || ewarn "WARNING: Potential inteferring files found:\n$x11_warn_conf"
}

pkg_postrm() {
    xdg_icon_cache_update
    udev_reload
}

# Copyright 1999-2024 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
EAPI=8

RUST_MIN_VER="1.71.1"
CRATES="
aho-corasick-0.7.19
async-broadcast-0.4.1
async-channel-1.7.1
async-executor-1.4.1
async-io-1.9.0
async-lock-2.5.0
async-recursion-0.3.2
async-task-4.3.0
async-trait-0.1.58
atty-0.2.14
autocfg-1.1.0
bitflags-1.3.2
byteorder-1.4.3
bytes-1.2.1
cache-padded-1.2.0
cc-1.0.73
cfg-if-1.0.0
concurrent-queue-1.2.4
derivative-2.2.0
dirs-4.0.0
dirs-sys-0.3.7
enumflags2-0.7.5
enumflags2_derive-0.7.4
env_logger-0.9.1
event-listener-2.5.3
fastrand-1.8.0
futures-core-0.3.25
futures-io-0.3.25
futures-lite-1.12.0
futures-sink-0.3.25
futures-task-0.3.25
futures-util-0.3.25
getrandom-0.2.8
gumdrop-0.8.1
gumdrop_derive-0.8.1
hermit-abi-0.1.19
hex-0.4.3
humantime-2.1.0
instant-0.1.12
itoa-1.0.4
lazy_static-1.4.0
libc-0.2.136
libudev-sys-0.1.4
lock_api-0.4.9
log-0.4.17
logind-zbus-3.0.2
memchr-2.5.0
memoffset-0.6.5
mio-0.8.5
nix-0.24.2
num_cpus-1.13.1
once_cell-1.15.0
ordered-stream-0.0.1
parking-2.0.0
parking_lot-0.12.1
parking_lot_core-0.9.4
pin-project-lite-0.2.9
pin-utils-0.1.0
pkg-config-0.3.25
polling-2.4.0
ppv-lite86-0.2.16
proc-macro-crate-1.2.1
proc-macro2-1.0.47
quote-1.0.21
rand-0.8.5
rand_chacha-0.3.1
rand_core-0.6.4
redox_syscall-0.2.16
redox_users-0.4.3
regex-1.6.0
regex-syntax-0.6.27
remove_dir_all-0.5.3
ryu-1.0.11
scopeguard-1.1.0
serde-1.0.147
serde_derive-1.0.147
serde_json-1.0.87
serde_repr-0.1.9
sha1-0.6.1
sha1_smol-1.0.0
slab-0.4.7
smallvec-1.10.0
socket2-0.4.7
static_assertions-1.1.0
syn-1.0.103
tempfile-3.3.0
termcolor-1.1.3
thiserror-1.0.37
thiserror-impl-1.0.37
tokio-1.21.2
tokio-macros-1.8.0
toml-0.5.9
tracing-0.1.37
tracing-attributes-0.1.23
tracing-core-0.1.30
udev-0.6.3
uds_windows-1.0.2
unicode-ident-1.0.5
waker-fn-1.1.0
wasi-0.11.0+wasi-snapshot-preview1
wepoll-ffi-0.1.2
winapi-0.3.9
winapi-i686-pc-windows-gnu-0.4.0
winapi-util-0.1.5
winapi-x86_64-pc-windows-gnu-0.4.0
windows-sys-0.42.0
windows_aarch64_gnullvm-0.42.0
windows_aarch64_msvc-0.42.0
windows_i686_gnu-0.42.0
windows_i686_msvc-0.42.0
windows_x86_64_gnu-0.42.0
windows_x86_64_gnullvm-0.42.0
windows_x86_64_msvc-0.42.0
zbus-3.3.0
zbus_macros-3.3.0
zbus_names-2.2.0
zvariant-3.7.1
zvariant_derive-3.7.1"

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
SLOT="5/5.0.1"
KEYWORDS="~amd64"
RESTRICT="mirror"

BDEPEND="
    !!<=sys-power/asusctl-4.0.0
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

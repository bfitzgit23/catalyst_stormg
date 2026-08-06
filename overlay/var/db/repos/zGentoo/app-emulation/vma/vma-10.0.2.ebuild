# Copyright 1999-2025 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit unpacker

LPBV="2.0.1" # lib-proxmox-backup version

DESCRIPTION="Extraction tool for proxmox .vma images"
HOMEPAGE="
    https://pve.proxmox.com/wiki/VMA 
    https://github.com/proxmox/pve-qemu
"
SRC_URI="
    http://download.proxmox.com/debian/pve/dists/trixie/pve-no-subscription/binary-amd64/pve-qemu-kvm_${PV}-4_amd64.deb -> ${P}.deb
    http://download.proxmox.com/debian/pve/dists/trixie/pve-no-subscription/binary-amd64/libproxmox-backup-qemu0_${LPBV}_amd64.deb
"

LICENSE="AGPL-3 GPL-2"
SLOT="0"
KEYWORDS="~amd64"

DEPEND="
    app-arch/zstd
    dev-libs/libaio
    net-libs/libiscsi
    net-misc/curl
    sys-cluster/ceph
"
QA_PREBUILT="/usr/bin/vma"
QA_PRESTRIPPED="
    /usr/bin/vma
    /usr/lib64/libproxmox_backup_qemu.so.0
"

S="${WORKDIR}"

src_install() {
    # linking libraries to expected path (debian shizzle)
    dosym libcurl.so.4 /usr/$(get_libdir)/libcurl-gnutls.so.4
    dosym libaio.so.1 /usr/$(get_libdir)/libaio.so.1t64
    dosym libiscsi.so /usr/$(get_libdir)/libiscsi.so.7

	dobin usr/bin/vma
    dolib.so usr/lib/libproxmox_backup_qemu.so.0
}

# Copyright 2023-2025 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit meson

DESCRIPTION="Data Plane Development Kit (DPDK)"
HOMEPAGE="https://www.dpdk.org/"
SRC_URI="https://fast.dpdk.org/rel/${P}.tar.xz"

LICENSE="" # todo
SLOT="0"
KEYWORDS="~amd64 ~arm64"

BDEPEND="sys-process/numactl"

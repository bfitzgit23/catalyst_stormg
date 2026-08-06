# Copyright 2023 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
EAPI=8

inherit cmake

DESCRIPTION="${PN} is a High-performance JSON to GRON (greppable, flattened JSON) converter"
HOMEPAGE="https://github.com/adamritter/${PN}"
SRC_URI="https://github.com/adamritter/${PN}/archive/refs/tags/v${PV}.tar.gz -> ${P}.tar.gz"


LICENSE="GPL-3"
SLOT="0"
KEYWORDS="~amd64"

BDEPEND="
	>=dev-util/cmake-3.5
"

src_prepare() {
	cmake_src_prepare
}

src_configure() {
	cmake_src_configure
}

src_install() {
    cmake_src_install
}
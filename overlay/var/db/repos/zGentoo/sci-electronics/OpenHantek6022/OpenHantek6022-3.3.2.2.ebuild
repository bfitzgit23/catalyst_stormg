# Copyright 2023 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
EAPI=8

inherit udev cmake xdg-utils

DESCRIPTION="${PN} is a free software for Hantek DSO6022 USB digital signal oscilloscopes"
HOMEPAGE="https://github.com/OpenHantek/${PN}"
SRC_URI="https://github.com/OpenHantek/${PN}/archive/refs/tags/${PV}.tar.gz -> ${P}.tar.gz"


LICENSE="GPL-3"
SLOT="0"
KEYWORDS="~amd64"

BDEPEND="
	>=dev-qt/qtwidgets-5.4
	>=sci-libs/fftw-3
	>=dev-libs/libusb-1
	dev-qt/qtopengl
	dev-qt/qtprintsupport
	dev-qt/linguist-tools
	dev-build/cmake
"

src_prepare() {
	sed -i 's:project(OpenHantek CXX)::g' openhantek/CMakeLists.txt || die "couldn't patch CMakeLists.txt"
	cmake_src_prepare
}

src_configure() {
	cmake_src_configure
}

src_install() {
    	cmake_src_install
}

pkg_postinst() {
        xdg_icon_cache_update
	udev_reload
}

pkg_postrm() {
        xdg_icon_cache_update
	udev_reload
}
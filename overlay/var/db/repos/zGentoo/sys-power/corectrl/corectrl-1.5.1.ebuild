# Copyright 1999-2025 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit cmake

DESCRIPTION="CoreCtrl allows you to control with ease your computer hardware using application profiles"
HOMEPAGE="https://gitlab.com/corectrl/corectrl"

SRC_URI="https://gitlab.com/${PN}/${PN}/-/archive/v${PV}/${PN}-v${PV}.tar.gz"
KEYWORDS="~amd64 ~arm64 ~x86"

LICENSE="MIT"
SLOT="0"
IUSE="+pcinames"
RESTRICT="test" # todo

DEPEND="
	dev-qt/qtbase:6[dbus,network,widgets]
	dev-qt/qtcharts:6[qml]
	dev-qt/qtdeclarative:6
	dev-qt/qtsvg:6
	dev-qt/qttools:6[linguist,qml]
	sys-auth/polkit
	dev-libs/quazip[qt6]
	dev-libs/botan:2
	dev-libs/pugixml
	>=dev-libs/spdlog-1.4.0
"
RDEPEND="
	${DEPEND}
	pcinames? ( sys-apps/hwdata )
"
BDEPEND="
	dev-build/cmake
	virtual/pkgconfig
"

S=${WORKDIR}/${PN}-v${PV}

src_configure() {
	local mycmakeargs=(
		-DBUILD_TESTING=OFF
		-WITH_DEBUG_INFO=ON
	)
	cmake_src_configure
}
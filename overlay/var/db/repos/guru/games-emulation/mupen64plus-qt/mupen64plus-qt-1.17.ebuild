# Copyright 2018-2025 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit cmake

DESCRIPTION="A basic launcher for Mupen64Plus"
HOMEPAGE="https://github.com/dh4/mupen64plus-qt"
SRC_URI="https://github.com/dh4/${PN}/archive/${PV}.tar.gz -> ${P}.tar.gz"

LICENSE="BSD"
SLOT="0"

RDEPEND="
	dev-libs/quazip[qt6]
	dev-qt/qtbase:6[gui,network,sql,widgets,xml]
"
DEPEND=">=games-emulation/mupen64plus-core-2.5
		${RDEPEND}"

src_install() {
	cmake_src_install
	rm -rf "${D}"/usr/$(get_libdir)/ \
		"${D}"/usr/plugins/ \
		"${D}"/usr/bin/qt.conf || die
	mkdir -p "${D}"/usr/share/qt6 || die
	mv "${D}"/usr/translations "${D}"/usr/share/qt6/ || die
	for i in "${D}"/usr/share/qt6/translations/*; do
		echo mv "${i}" "${i/qt_/mupen64plus-qt_}"
		mv "${i}" "${i/qt_/mupen64plus-qt_}" || die
	done
}

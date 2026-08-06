# Copyright 1999-2025 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit desktop unpacker xdg

MY_PV=${PN%-bin}

DESCRIPTION="Libation: Liberate your (Audiobook)Library"
HOMEPAGE="https://getlibation.com/"
SRC_URI="https://github.com/rmcrackan/${MY_PV}/releases/download/v${PV}/${MY_PV}.${PV}-linux-chardonnay-amd64.deb"

S="${WORKDIR}"

LICENSE="GPL-3"
SLOT="0"
KEYWORDS="~amd64"

QA_PREBUILT="/usr/lib/${MY_PV}/*"

src_install() {
	insinto /usr/lib/libation
	doins -r usr/lib/libation/*

    exeinto /usr/lib/libation
    doexe usr/lib/libation/Libation

    insinto /usr/bin
    dobin ${FILESDIR}/libation

    # desktop stuff
    doicon usr/share/icons/hicolor/scalable/apps/${MY_PV}.svg
	domenu usr/share/applications/${MY_PV^}.desktop
}

pkg_postinst() {
    xdg_icon_cache_update
    xdg_desktop_database_update
}

pkg_postrm() {
    xdg_icon_cache_update
    xdg_desktop_database_update
}
# Copyright 1999-2025 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit desktop qmake-utils xdg-utils

DESCRIPTION="A plain-text file markdown note taking with Nextcloud/ownCloud integration"
HOMEPAGE="https://www.qownnotes.org/"
SRC_URI="https://github.com/pbek/QOwnNotes/releases/download/v${PV}/${P}.tar.xz"

LICENSE="GPL-2"
SLOT="0"
KEYWORDS="~x86 ~amd64"
IUSE="-qt5 qt6"
REQUIRED_USE="qt6? ( !qt5 )"

DEPEND="
    qt5? (
        dev-qt/qtwidgets:5
        dev-qt/qtgui:5
        dev-qt/qtcore:5
        dev-qt/qtsql:5
        dev-qt/qtsvg:5
        dev-qt/qtnetwork:5
        dev-qt/qtdeclarative:5
        dev-qt/qtxml:5
        dev-qt/qtprintsupport:5
        dev-qt/qtwebsockets:5
        dev-qt/qtx11extras:5
    )
    qt6? (
        dev-qt/qttools
        dev-qt/qtbase
        dev-qt/qtdeclarative:6
        dev-qt/qtsvg:6
        dev-qt/qtwayland:6
        dev-qt/qtwebsockets:6
    )
"
RDEPEND="${DEPEND}"

src_prepare() {
    echo "#define RELEASE \"Gentoo\"" > release.h
    default
}

src_compile() {
    if use qt5 ; then
        eqmake5 QOwnNotes.pro -r
    else
        eqmake6 QOwnNotes.pro -r
    fi
}

src_install() {
    emake
    dobin QOwnNotes

    if use qt5 ; then
        dodir /usr/share/qt5/translations
        insinto /usr/share/qt5/translations
    else
        dodir /usr/share/qt6/translations
        insinto /usr/share/qt6/translations
    fi

    doins languages/*.qm

    insinto /usr/share/applications
    doicon -s 128 "images/icons/128x128/apps/QOwnNotes.png"
    doicon -s 16 "images/icons/16x16/apps/QOwnNotes.png"
    doicon -s 24 "images/icons/24x24/apps/QOwnNotes.png"
    doicon -s 256 "images/icons/256x256/apps/QOwnNotes.png"
    doicon -s 32 "images/icons/32x32/apps/QOwnNotes.png"
    doicon -s 48 "images/icons/48x48/apps/QOwnNotes.png"
    doicon -s 512 "images/icons/512x512/apps/QOwnNotes.png"
    doicon -s 64 "images/icons/64x64/apps/QOwnNotes.png"
    doicon -s 96 "images/icons/96x96/apps/QOwnNotes.png"
    doicon -s scalable "images/icons/scalable/apps/QOwnNotes.svg"
    doins PBE.QOwnNotes.desktop
}

pkg_postinst() {
    xdg_icon_cache_update
}

pkg_postrm() {
    xdg_icon_cache_update
}

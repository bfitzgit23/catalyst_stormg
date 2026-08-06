# Copyright 1999-2025 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2
EAPI=8

MY_PN="${PN/gnome-shell-extension-/}"

DESCRIPTION="Extension for visualizing asusctl-ctrl(asusd) settings and status."
HOMEPAGE="https://gitlab.com/asus-linux/${MY_PN}"
SRC_URI="https://vendors.simple-co.de/gnome-extra/${PN}/${MY_PN}-${PVR}@asus-linux.org.zip -> ${P}.zip"
S="${WORKDIR}/${MY_PN}@asus-linux.org"

LICENSE="MPL-2.0"
SLOT="0/5.2"
KEYWORDS="~amd64"
IUSE=""

RDEPEND="
    !!gnome-extra/gnome-shell-extension-asus-nb-gex
    !!gnome-extra/gnome-shell-extension-asusctl-gex
    !!<gnome-base/gnome-shell-45_alpha
    app-eselect/eselect-gnome-shell-extensions
"
DEPEND="${RDEPEND}
    dev-libs/glib:2
"

src_unpack() {
    mkdir -p "${S}"
    cd "${S}" && unpack "${P}.zip"
}

src_install() {
    insinto "/usr/share/gnome-shell/extensions/${MY_PN}@asus-linux.org"
    doins -r ${S}/*
}

pkg_postinst() {
    ebegin "Updating list of installed extensions"
    eselect gnome-shell-extensions update
    eend $?
}
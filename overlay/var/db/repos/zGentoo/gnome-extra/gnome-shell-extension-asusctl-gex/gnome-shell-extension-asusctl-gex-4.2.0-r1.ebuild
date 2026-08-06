# Copyright 1999-2023 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2
EAPI=8

DESCRIPTION="Extension for visualizing asusctl-ctrl(asusd) settings and status."
HOMEPAGE="https://gitlab.com/asus-linux/asusctl-gex"
SRC_JID="2835289200"
SRC_URI="https://gitlab.com/asus-linux/asusctl-gex/-/jobs/${SRC_JID}/artifacts/download -> ${P}.zip"
S="${WORKDIR}/asusctl-gex@asus-linux.org"

LICENSE="MPL-2.0"
SLOT="0/4"
KEYWORDS="~amd64"
IUSE=""

RDEPEND="
    !!gnome-extra/gnome-shell-extension-asus-nb-gex
    || ( 
        !!<gnome-base/gnome-shell-43.0
        !!>=gnome-base/gnome-shell-45.0
    )
    >=gnome-base/gnome-shell-40.0
    app-eselect/eselect-gnome-shell-extensions
    >=sys-power/supergfxctl-4.0.4
"
DEPEND="${RDEPEND}
    dev-libs/glib:2
"

src_install() {
    insinto /usr/share/gnome-shell/extensions/asusctl-gex@asus-linux.org
    doins -r ${S}/*
}

pkg_postinst() {
    ebegin "Updating list of installed extensions"
    eselect gnome-shell-extensions update
    eend $?
}
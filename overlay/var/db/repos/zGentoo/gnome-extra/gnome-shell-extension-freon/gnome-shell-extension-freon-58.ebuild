# Copyright 1999-2024 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit git-r3

DESCRIPTION="Freon is an extension for displaying sensors data."
HOMEPAGE="https://extensions.gnome.org/extension/841/freon/"
EGIT_REPO_URI="https://github.com/UshakovVasilii/gnome-shell-extension-freon"
EGIT_COMMIT="9379f2c"

LICENSE="GPL-2+"
SLOT="0"
KEYWORDS="amd64 x86"
IUSE=""

# glib for glib-compile-schemas at build time, needed at runtime anyways
DEPEND="
    dev-libs/glib:2
"
RDEPEND="${DEPEND}
    app-eselect/eselect-gnome-shell-extensions
    || ( 
        !!<gnome-base/gnome-shell-45.0
        !!>=gnome-base/gnome-shell-49.0
    )
"
BDEPEND=""

src_prepare() {
    default
    cp ${FILESDIR}/Makefile ${S}
}

src_install() {
    make install INSTALL_PATH="${ED}/usr/share/gnome-shell/extensions/"
    dodoc README.md
}

pkg_postinst() {
    ebegin "Updating list of installed extensions"
    eselect gnome-shell-extensions update
    eend $?
}

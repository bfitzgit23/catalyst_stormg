# Copyright 2024 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit git-r3 toolchain-funcs

EGIT_REPO_URI="https://github.com/Lekensteyn/dmg2img"

DESCRIPTION="Convert Apple disk images to IMG format."
HOMEPAGE="https://github.com/Lekensteyn/dmg2img"
LICENSE="GPL-2"
SLOT="0"

DEPEND="
	app-arch/bzip2
	dev-libs/openssl
	sys-libs/zlib
"
RDEPEND="${DEPEND}"
BDEPEND="${DEPEND}"

src_compile() {
	emake CC="$(tc-getCC)" CFLAGS="${CFLAGS}" LDFLAGS="${LDFLAGS}"
}

src_install() {
	emake DESTDIR="${ED}" install
}

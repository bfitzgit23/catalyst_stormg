# Copyright 1999-2025 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit webapp

DESCRIPTION="Simple, modern and fast web-based email client"
HOMEPAGE="https://snappymail.eu/"
SRC_URI="https://github.com/the-djmaze/snappymail/releases/download/v${PV}/${P}.tar.gz"
LICENSE="AGPL-3"

KEYWORDS="amd64 x86"
IUSE=""

RDEPEND="
	dev-lang/php[curl,iconv,ssl,xml]
	virtual/httpd-php
"
DEPEND="${RDEPEND}"

S=${WORKDIR}

src_prepare() {
	eapply_user
}

src_install() {
	webapp_src_preinst

	insinto "${MY_HTDOCSDIR}"
	doins -r .

	webapp_serverowned -R "${MY_HTDOCSDIR}"/data
	webapp_src_install
}

# Copyright 1999-2025 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

DESCRIPTION="Common interface for logging libraries"
HOMEPAGE="https://github.com/php-fig/log"
SRC_URI="https://github.com/php-fig/log/archive/${PV}.tar.gz -> ${P}.tar.gz"

LICENSE="MIT"
SLOT="0"
KEYWORDS="amd64 ~arm64 x86"

RDEPEND="
	dev-lang/php:*
	dev-php/fedora-autoloader"

S="${WORKDIR}/log-${PV}"

src_install() {
	insinto "/usr/share/php/Psr/Log"
	doins -r src/. "${FILESDIR}"/autoload.php
	dodoc README.md
}

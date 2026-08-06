# Copyright 1999-2025 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

DESCRIPTION="Restart a CLI process without loading the xdebug extension"
HOMEPAGE="https://github.com/composer/xdebug-handler"
SRC_URI="https://github.com/composer/xdebug-handler/archive/${PV}.tar.gz -> ${P}.tar.gz"

LICENSE="MIT"
SLOT="0"
KEYWORDS="amd64 ~arm64 x86"

RDEPEND="
	dev-lang/php:*
	dev-php/fedora-autoloader
	>=dev-php/psr-log-3.0.0"

src_install() {
	insinto /usr/share/php/Composer/XdebugHandler
	doins src/*.php "${FILESDIR}/autoload.php"
	dodoc README.md
}

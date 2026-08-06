# Copyright 1999-2025 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8
PHP_EXT_NAME="xdebug"
PHP_EXT_INI="yes"
PHP_EXT_ZENDEXT="yes"
PHP_EXT_INIFILE="2.5-xdebug.ini"

USE_PHP="php5-6"
PHP_EXT_NEEDED_USE="-threads(-)"

S="${WORKDIR}/${PN}-XDEBUG_2_5_5"

inherit php-ext-source-r3

KEYWORDS="amd64 ~hppa ppc64 x86"

DESCRIPTION="A PHP debugging and profiling extension"
HOMEPAGE="https://xdebug.org/"
SRC_URI="https://github.com/xdebug/xdebug/archive/refs/tags/XDEBUG_2_5_5.tar.gz -> ${P}.tar.gz"
LICENSE="Xdebug"
SLOT="0"
IUSE=""

# Tests are known to fail
RESTRICT="test"

DEPEND=""
RDEPEND="${DEPEND}"
DOCS=( README.rst CREDITS )
PHP_EXT_ECONF_ARGS=()

src_test() {
	local slot
	for slot in $(php_get_slots); do
		php_init_slot_env "${slot}"
		TEST_PHP_EXECUTABLE="${PHPCLI}" \
		TEST_PHP_CGI_EXECUTABLE="${PHPCGI}" \
		TEST_PHPDBG_EXECUTABLE="${PHPCLI}dbg" \
		 "${PHPCLI}" run-xdebug-tests.php
	done
}


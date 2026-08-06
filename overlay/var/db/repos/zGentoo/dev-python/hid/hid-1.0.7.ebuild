# Copyright 1999-2025 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

DISTUTILS_USE_PEP517=setuptools
PYTHON_COMPAT=( pypy3 python3_{11..13} )

inherit edos2unix distutils-r1 pypi

DESCRIPTION="ctypes bindings for hidapi"
HOMEPAGE="https://github.com/apmorton/pyhidapi https://pypi.org/project/hid"

LICENSE="MIT"
SLOT="0"
KEYWORDS="amd64 ~x86"
IUSE="test"
RESTRICT="!test? ( test )"

DEPEND="dev-libs/hidapi"

python_test() {
	"${PYTHON}" setup.py test || die
}

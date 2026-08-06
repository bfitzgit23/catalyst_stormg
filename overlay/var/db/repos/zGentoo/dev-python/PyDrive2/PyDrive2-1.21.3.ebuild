# Copyright 1999-2025 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

DISTUTILS_USE_PEP517=setuptools
PYTHON_COMPAT=( pypy3 python3_{11..13} )

inherit edos2unix distutils-r1 pypi

DESCRIPTION="Wrapper library of google-api-python-client"
HOMEPAGE="https://github.com/iterative/PyDrive2 https://pypi.org/project/PyDrive2"

LICENSE="Apache-2.0"
SLOT="0"
KEYWORDS="amd64 ~x86"
IUSE="test"
RESTRICT="!test? ( test )"

DEPEND="dev-python/google-api-python-client[${PYTHON_USEDEP}]"

python_test() {
	"${PYTHON}" setup.py test || die
}

# Copyright 1999-2025 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

DISTUTILS_USE_PEP517=setuptools
PYTHON_COMPAT=( pypy3 python3_{11..13} )

inherit edos2unix distutils-r1 pypi

DESCRIPTION="Read and modify image EXIF metadata using Python"
HOMEPAGE="https://gitlab.com/TNThieding/exif https://pypi.org/project/exif"

LICENSE="MIT"
SLOT="0"
KEYWORDS="amd64 ~x86"
IUSE="test"
RESTRICT="!test? ( test )"

DEPEND="dev-python/setuptools[${PYTHON_USEDEP}]"
RDEPEND="dev-python/plum-py"

python_test() {
	"${PYTHON}" setup.py test || die
}

# Copyright 1999-2025 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

DISTUTILS_USE_PEP517=setuptools
PYTHON_COMPAT=( pypy3 python3_{11..13} )

inherit distutils-r1

DESCRIPTION="Pack/Unpack Memory"
HOMEPAGE="https://gitlab.com/dangass/plum/ https://pypi.org/project/plum-py/"
SRC_URI="https://gitlab.com/dangass/plum/-/archive/${PV}/plum-${PV}.tar.gz -> ${P}.tar.gz"

LICENSE="MIT"
SLOT="0"
KEYWORDS="amd64 ~x86"
IUSE="test"
RESTRICT="!test? ( test )"

S="${WORKDIR}/plum-${PV}"

DEPEND=""
RDEPEND=""

src_prepare() {
	default
	sed -i 's/3.6.*/3.6.0/g' setup.cfg || die
}

python_test() {
	"${PYTHON}" setup.py test || die
}

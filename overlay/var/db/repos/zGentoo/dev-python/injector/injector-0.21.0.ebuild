# Copyright 1999-2025 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2

EAPI=8

DISTUTILS_USE_PEP517=setuptools
PYTHON_COMPAT=( python3_{11..13} )

inherit distutils-r1

DESCRIPTION="Python dependency injection framework, inspired by Guice"
HOMEPAGE="https://github.com/alecthomas/injector"
SRC_URI="https://github.com/python-injector/injector/archive/refs/tags/${PV}.tar.gz -> ${P}.tar.gz"

SLOT="0"
LICENSE="BSD"
KEYWORDS="~amd64 ~x86"

IUSE="doc test"

RDEPEND="
	test? ( 
		dev-python/pytest
		dev-python/hypothesis 
	)
"
DEPEND="${RDEPEND}
	doc? ( dev-python/sphinx )
"


python_compile_all() {
	use doc && emake -C docs
}

python_test() {
	esetup.py test
}

python_install_all() {
	use doc && local HTML_DOCS=( docs/. )
	distutils-r1_python_install_all
}

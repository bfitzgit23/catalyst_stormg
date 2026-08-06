# Copyright 1999-2025 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

export SETUPTOOLS_SCM_PRETEND_VERSION=${PV}
DISTUTILS_USE_PEP517=setuptools
PYTHON_COMPAT=( python3_{11..13} )

inherit distutils-r1 pypi


DESCRIPTION="Google Photos Sync downloads your Google Photos to the local file system."
HOMEPAGE="https://pypi.org/project/gphotos-sync/ https://github.com/gilesknap/gphotos-sync"

KEYWORDS="~amd64 ~x86"
SLOT="0"
LICENSE="MIT"
IUSE="doc"

BDEPEND="
	dev-python/setuptools[${PYTHON_USEDEP}]
"
DEPEND="
    dev-python/setuptools[${PYTHON_USEDEP}]
	dev-python/appdirs[${PYTHON_USEDEP}]
	media-gfx/exif
	dev-python/exif[${PYTHON_USEDEP}]
	dev-python/pyyaml[${PYTHON_USEDEP}]
	dev-python/requests-oauthlib[${PYTHON_USEDEP}]
	dev-python/selenium[${PYTHON_USEDEP}]
	dev-python/urllib3[${PYTHON_USEDEP}]
"
RDEPEND="${DEPEND}"

RESTRICT="test" # broken since v1.4.3

src_prepare() {
	default
	echo 
}

python_compile_all() {
	use doc && emake -C docs html
}

python_test() {
	cd test || die
	"${EPYTHON}" testall.py || die "Testsuite failed"
}

python_install_all() {
	distutils-r1_python_install_all

	if use doc; then 
        local HTML_DOCS=( docs/_build/html/. )
	    einstalldocs
    fi
}
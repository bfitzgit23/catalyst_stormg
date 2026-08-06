# Copyright 2025 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

DISTUTILS_USE_PEP517="meson-python"
PYTHON_COMPAT=( python3_{10..14} )

inherit distutils-r1 pypi

DESCRIPTION="A Python Library for Generating PDFs and Images from HTML, powered by PlutoBook"
HOMEPAGE="https://github.com/plutoprint/plutoprint"
SRC_URI="$(pypi_sdist_url "${PN^}" "${PV}")"

LICENSE="MIT"
SLOT="0"
KEYWORDS="~amd64"

IUSE="test"

DEPEND="app-text/plutobook"
RDEPEND="${DEPEND}"
BDEPEND=""

distutils_enable_tests pytest
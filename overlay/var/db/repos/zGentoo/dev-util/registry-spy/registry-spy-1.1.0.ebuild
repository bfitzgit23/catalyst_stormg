# Copyright 1999-2025 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

DISTUTILS_USE_PEP517=setuptools
PYTHON_COMPAT=( pypy3 python3_{9..11} )

inherit distutils-r1 git-r3

DESCRIPTION="Cross-Platform Windows Registry Browser"
HOMEPAGE="https://github.com/andyjsmith/Registry-Spy https://pypi.org/project/registryspy"
EGIT_REPO_URI="https://github.com/andyjsmith/Registry-Spy.git"
EGIT_TAG="v${PV}"

LICENSE="GPL-3"
SLOT="0"
KEYWORDS="amd64 ~x86"
IUSE="test"
RESTRICT="!test? ( test )"

DEPEND="
    dev-python/pyside2[${PYTHON_USEDEP}]
    dev-python/python-registry[${PYTHON_USEDEP}]
"
RDEPEND=""

src_prepare() {
    default

    # downgrading to PySide2 (Qt5 instead of Qt6 - as this isn't released yet)
    sed -i 's/PySide6/PySide2/g' setup.py
    sed -i '6 a from PySide2.QtWidgets import QAction'  registryspy/registryspy.py
    sed -i 's/QtGui.QAction/QAction/g' registryspy/*.py
    sed -i 's/self.app.style().name()/self.app.style()/g' registryspy/*.py
    sed -i 's/exec()/exec_()/g' registryspy/*.py
    sed -i 's/PySide6/PySide2/g' registryspy/*.py
}

python_test() {
	"${PYTHON}" setup.py test || die
}
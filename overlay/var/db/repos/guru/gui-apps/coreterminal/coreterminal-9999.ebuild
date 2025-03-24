# Copyright 1999-2025 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit cmake xdg

DESCRIPTION="A terminal emulator for C Suite"
HOMEPAGE="https://gitlab.com/cubocore/coreapps/coreterminal"

if [[ "${PV}" == *9999* ]]; then
	inherit git-r3
	EGIT_REPO_URI="https://gitlab.com/cubocore/coreapps/coreterminal.git"
else
	SRC_URI="https://gitlab.com/cubocore/coreapps/coreterminal/-/archive/v${PV}/${PN}-v${PV}.tar.bz2"
	KEYWORDS="~amd64"
	S="${WORKDIR}/${PN}-v${PV}"
fi

LICENSE="GPL-3+"
SLOT="0"

DEPEND="
	dev-qt/qtbase:6[gui,widgets]
	dev-qt/qtserialport:6
	>=gui-libs/libcprime-5.0.0_pre20240921
	>=x11-libs/qtermwidget-2.0.0:=
"
RDEPEND="${DEPEND}"

# Copyright 1999-2024 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit meson

DESCRIPTION="A Wayland kiosk"
HOMEPAGE="https://www.hjdskes.nl/projects/cage/ https://github.com/cage-kiosk/cage"

if [[ "${PV}" == 9999 ]]; then
	inherit git-r3
	EGIT_REPO_URI="https://github.com/cage-kiosk/cage"
else
	SRC_URI="https://github.com/cage-kiosk/cage/archive/v${PV}.tar.gz -> ${P}.tar.gz"
	KEYWORDS="~amd64 ~x86"
fi

LICENSE="MIT"
SLOT="0"

IUSE="X"

RDEPEND="
	dev-libs/wayland
	x11-libs/libxkbcommon[X?]
	X? ( gui-libs/wlroots:0.18[X,x11-backend] )
	!X? ( gui-libs/wlroots:0.18 )
"
DEPEND="${RDEPEND}"

# Copyright 2024-2025 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

DESCRIPTION="Hyprshot is a utility to easily take screenshot in Hyprland using your mouse"
HOMEPAGE="https://github.com/Gustash/Hyprshot/"
SRC_URI="https://github.com/Gustash/Hyprshot/archive/refs/tags/${PV}.tar.gz -> ${P}.tar.gz"

S="${WORKDIR}"/Hyprshot-${PV}

LICENSE="GPL-3"
SLOT="0"
KEYWORDS="~amd64"

IUSE="+xdg +freeze"

RDEPEND="
	app-misc/jq
	gui-apps/grim
	gui-apps/slurp
	gui-apps/wl-clipboard
	gui-wm/hyprland
	x11-libs/libnotify
	xdg? ( x11-misc/xdg-user-dirs )
	freeze? ( gui-apps/hyprpicker )
"

src_install() {
	dobin hyprshot
	einstalldocs
}

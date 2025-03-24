# Copyright 1999-2024 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

DESCRIPTION="River layout generator powered by guile scheme "
HOMEPAGE="https://git.sr.ht/~leon_plickat/riverguile/"

if [[ ${PV} == *9999* ]]; then
	inherit git-r3
	EGIT_REPO_URI="https://git.sr.ht/~leon_plickat/riverguile"
else
	SRC_URI="https://git.sr.ht/~leon_plickat/riverguile/archive/v${PV}.tar.gz -> ${P}.tar.gz"
	S="${WORKDIR}/${PN}-v${PV}"
	KEYWORDS="~amd64"
fi

LICENSE="GPL-3"
SLOT="0"

RDEPEND="
	~dev-scheme/guile-3.0.9
	>=dev-libs/wayland-1.22.0
"
DEPEND="${RDEPEND}"
BDEPEND=">=dev-libs/wayland-protocols-1.36"

src_install() {
	# Need to install to /usr instead of /usr/local
	# and the Makefile doens't handle DESTDIR properly
	emake PREFIX="${D}"/usr install
}

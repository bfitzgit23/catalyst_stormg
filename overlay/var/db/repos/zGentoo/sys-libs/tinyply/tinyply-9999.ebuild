# Copyright 1999-2022 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit cmake git-r3

DESCRIPTION="A minimal header only C++ logger system"
HOMEPAGE="https://github.com/dominikschnitzer/minilog"
EGIT_REPO_URI="https://github.com/bchretien/tinyply.git"
EGIT_BRANCH="feat/improvements"

LICENSE="BSD2"
SLOT="0"
KEYWORDS="~amd64 ~x86"
IUSE=""

RDEPEND=""

DEPEND="${RDEPEND}"

src_configure() {
        local mycmakeargs=(
		    -DCMAKE_INSTALL_PREFIX=/usr
        )
        cmake_src_configure
}

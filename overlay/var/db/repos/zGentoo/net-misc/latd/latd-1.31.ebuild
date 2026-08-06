# Copyright 2024 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit git-r3 systemd

DESCRIPTION="LAT terminal daemon for Linux and BSD"
HOMEPAGE="https://lab.simple-co.de/zappel/latd"
EGIT_REPO_URI="https://lab.simple-co.de/zappel/latd.git"
EGIT_TAG="v${PV}"

LICENSE="GPL-2"
SLOT="0"
KEYWORDS="~amd64 ~x86"
IUSE="systemd"

DEPEND="systemd? ( sys-apps/systemd )"
RDEPEND="${DEPEND}"
BDEPEND=""

src_install() {
    default
    doman ${S}/*.{1,5,8}

    use systemd && systemd_dounit "${FILESDIR}/latd.service"
    # todo: init.d
}
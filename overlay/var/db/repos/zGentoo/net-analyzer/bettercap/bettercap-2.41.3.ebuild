# Copyright 1999-2025 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit go-module


DESCRIPTION="A complete, modular, portable and easily extensible MITM framework"
HOMEPAGE="https://github.com/${PN}/${PN}/"
SRC_URI="
	https://github.com/${PN}/${PN}/archive/v${PV}.tar.gz -> ${P}.tar.gz
	https://vendors.simple-co.de/${PN}/${P}-vendor.tar.xz
"

LICENSE="GPL-3"
SLOT=0
IUSE=""
KEYWORDS="~amd64 ~arm ~arm64 ~x86"

DEPEND="
	net-libs/libpcap
	net-libs/libnetfilter_queue
	net-libs/libnfnetlink
"
RDEPEND="${DEPEND}"

src_compile() {
	go build -o ${PN} 
}

src_install() {
	dosbin ${PN}
}

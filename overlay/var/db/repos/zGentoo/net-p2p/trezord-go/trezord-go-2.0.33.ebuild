# Copyright 1999-2020 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit go-module systemd udev

TD="trezord"
DESCRIPTION="TREZOR Communication Daemon"
HOMEPAGE="https://github.com/trezor/${TD}-go"
SRC_URI="
	https://github.com/trezor/${TD}-go/archive/v${PV}.tar.gz -> ${P}.tar.gz
	https://vendors.simple-co.de/${PN}/${P}-vendor.tar.xz
"

LICENSE="LGPL-3"
SLOT="0"
KEYWORDS="~amd64"
IUSE="systemd +udev"

DEPEND="
	acct-user/${TD}
	acct-group/plugdev
"

src_prepare() {
	default

	## patching Makefile to match our requirements
	sed -i -e 's/^PLATFORMS.*/PLATFORMS := linux-x64/g' Makefile || die "faild to set build target"
	sed -i -e "s/^GITHASH.*/GITHASH\ :=\ v${PV}/g" Makefile || die "faild to set verison"
	sed -i -e 's/^GOFLAGS.*/GOFLAGS := -mod=vendor/g' Makefile || die "faild to set GOFLAGS"
	sed -i -e 's/)-linux-x64$/)-linux-x64 -a -ldflags="-X main.githash=$(GITHASH)"/g' Makefile || die "faild to set LDFLAGS"
}

src_install() {
	newbin build/${TD}-linux-x64 ${TD}
	newinitd "${FILESDIR}/${TD}-openrc.sh" ${TD}
	keepdir /var/log/${TD}
	fowners ${TD}:root /var/log/${TD}
	einstalldocs

	use systemd && systemd_dounit release/linux/${TD}.service
	use udev && udev_dorules release/linux/trezor.rules
}

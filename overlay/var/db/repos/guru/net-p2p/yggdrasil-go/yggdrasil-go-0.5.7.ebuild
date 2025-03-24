# Copyright 1999-2024 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit fcaps go-module linux-info systemd

DESCRIPTION="An experiment in scalable routing as an encrypted IPv6 overlay network"
HOMEPAGE="https://yggdrasil-network.github.io/"
SRC_URI="
	https://github.com/yggdrasil-network/yggdrasil-go/archive/refs/tags/v${PV}.tar.gz -> ${P}.tar.gz
	https://codeberg.org/BratishkaErik/distfiles/releases/download/yggdrasil-go-${PV}/yggdrasil-go-${PV}-vendor.tar.xz
"

LICENSE="LGPL-3 MIT Apache-2.0 BSD ZLIB"
SLOT="0"
KEYWORDS="~amd64 ~arm64"
RESTRICT="mirror"

DEPEND="
	acct-user/yggdrasil
	acct-group/yggdrasil
"

BDEPEND=">=dev-lang/go-1.21"

DOCS=( README.md CHANGELOG.md )

FILECAPS=(
	cap_net_admin,cap_net_bind_service "usr/bin/yggdrasil"
)

CONFIG_CHECK="~TUN"
ERROR_TUN="Your kernel lacks TUN support."

src_compile() {
	GOFLAGS+=" -mod=vendor -trimpath"

	local ver_config="github.com/yggdrasil-network/yggdrasil-go/src/version"

	local custom_name_version_flags="-X ${ver_config}.buildName=${PN}"
	custom_name_version_flags+=" -X ${ver_config}.buildVersion=git-${EGIT_VERSION}"

	local GO_LDFLAGS
	GO_LDFLAGS="-s -linkmode external -extldflags \"${LDFLAGS}\" ${custom_name_version_flags}"

	local cmd
	for cmd in yggdrasil{,ctl}; do
		ego build ${GOFLAGS} "-ldflags=${GO_LDFLAGS}" ./cmd/"${cmd}"
	done
}

src_install() {
	dobin yggdrasil{,ctl}
	einstalldocs

	systemd_dounit "contrib/systemd/yggdrasil.service"
	systemd_dounit "contrib/systemd/yggdrasil-default-config.service"
	doinitd "contrib/openrc/yggdrasil"
}

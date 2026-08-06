# Copyright 1999-2023 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8
inherit go-module systemd
go-module_set_globals

DESCRIPTION="The plugin-driven server agent for collecting & reporting metrics."
HOMEPAGE="https://www.influxdata.com/time-series-platform/telegraf/"
SRC_URI="
    https://github.com/influxdata/${PN}/archive/v${PV}.tar.gz -> ${P}.tar.gz
    https://vendors.simple-co.de/${PN}/${P}-vendor.tar.xz
"

# creating vendor bundle:
# >> git clone https://github.com/influxdata/telegraf -b v<version> /tmp/telegraf
# >> cd /tmp/telegraf && version=`git describe --tags | sed -E "s/v([0-9.]+)/\1/g"`
# >> go mod vendor && mkdir telegraf-${version} && mv vendor telegraf-${version}/vendor
# >> tar -caf telegraf-${version}-vendor.tar.xz telegraf-${version}/vendor

LICENSE="MIT ISC Apache-2.0 BSD-2 BSD-3 EPL-2.0 MPL-2.0 Unlicense"
SLOT="0"
KEYWORDS="~amd64"

BDEPEND=""
DEPEND="acct-group/${PN}
    acct-user/${PN}"
RDEPEND="${DEPEND}"

src_compile() {
    go build -ldflags="-X main.version=${PV}" -o ${S}/bin/${PN} ${S}/cmd/${PN} || die "compile failed"
}

src_install() {
    dobin bin/${PN}

    insinto /etc/${PN}
    # Needs to be generated manually each update via: go run ./cmd/telegraf config > files/telegraf.conf
    doins "${FILESDIR}/${PN}.conf"
    keepdir /etc/${PN}/${PN}.d

    insinto /etc/logrotate.d
    doins etc/logrotate.d/${PN}

    systemd_dounit scripts/${PN}.service

    # todo: implement openRC

    dodoc -r docs/*

    keepdir /var/log/${PN}
    fowners ${PN}:${PN} /var/log/${PN}
}

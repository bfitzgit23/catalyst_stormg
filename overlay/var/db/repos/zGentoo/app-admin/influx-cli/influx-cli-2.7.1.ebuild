# Copyright 1999-2022 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

## WARN
# Due to the mass of dependencies, LICENSEs might not be complete. (TODO)

EAPI=8
inherit go-module systemd
go-module_set_globals


DESCRIPTION="CLI for managing resources in InfluxDB v2"
HOMEPAGE="https://github.com/influxdata/${PN}"
SRC_URI="
	https://github.com/influxdata/${PN}/archive/v${PV}.tar.gz -> ${P}.tar.gz
	https://vendors.simple-co.de/${PN}/vendor-${P}.tar.xz
"
# >> git clone https://github.com/influxdata/influx-cli -b v<version> /tmp/influx-cli && cd /tmp/influx-cli
# >> go mod vendor && mkdir influx-cli-`git describe --tags | sed -E "s/v([0-9.]+)/\1/g"` && mv vendor influx-cli-`git describe --tags | sed -E "s/v([0-9.]+)/\1/g"`/vendor && \
# >> tar -c -I 'xz -9 -T0' -f vendor-influx-cli-`git describe --tags | sed -E "s/v([0-9.]+)/\1/g"`.tar.xz influx-cli-`git describe --tags | sed -E "s/v([0-9.]+)/\1/g"`/vendor
RESTRICT="mirror"

LICENSE="MIT BSD Apache-2.0 EPL-1.0 MPL-2.0 BSD-2 ISC"
SLOT="0"
KEYWORDS="~amd64"

BDEPEND=""
COMMON_DEPEND=""
DEPEND="${COMMON_DEPEND}"
RDEPEND="${COMMON_DEPEND}"

src_compile() {
	go build -ldflags="-X main.version=${PV}" -o ${S}/bin/influx ${S}/cmd/influx || die "compile failed"
}

src_install() {
	dobin bin/influx
	dosym /usr/bin/influx /usr/bin/influx-cli

	# docs
	dodoc *.md
}

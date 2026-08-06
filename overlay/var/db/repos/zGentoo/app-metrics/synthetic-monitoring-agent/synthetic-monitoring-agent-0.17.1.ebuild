# Copyright 1999-2022 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8
inherit go-module systemd
go-module_set_globals

DESCRIPTION="The plugin-driven server agent for collecting & reporting metrics."
HOMEPAGE="https://github.com/grafana/synthetic-monitoring-agent"
SRC_URI="
    https://github.com/grafana/${PN}/archive/v${PV}.tar.gz -> ${P}.tar.gz
    https://vendors.simple-co.de/${PN}/vendor-${P}.tar.xz
"
# creating vendor bundle:
# git clone https://github.com/grafana/synthetic-monitoring-agent -b v<version> /tmp/synthetic-monitoring-agent && \
# cd /tmp/synthetic-monitoring-agent && version=`git describe --tags | sed -E "s/v([0-9.]+)/\1/g"`; \
# go mod vendor && mkdir synthetic-monitoring-agent-${version} && mv vendor synthetic-monitoring-agent-${version}/vendor && \
# tar -c -I 'xz -9 -T0' -f vendor-synthetic-monitoring-agent-${version}.tar.xz synthetic-monitoring-agent-${version}/vendor
LICENSE="Apache-2.0 BSD-2 BSD-3 MIT"
SLOT="0"
KEYWORDS="~amd64"

BDEPEND=""
DEPEND="acct-group/grafana
    acct-user/grafana"
RDEPEND="${DEPEND}"

src_compile() {
    go build -ldflags="-X main.version=${PV}" -o ${S}/bin/${PN} ${S}/cmd/${PN} || die "compile failed"
}

src_install() {
    dobin bin/${PN}

    # todo: implement config and services

    dodoc -r *.md

    keepdir /var/log/${PN}
    fowners grafana:grafana /var/log/${PN}
}

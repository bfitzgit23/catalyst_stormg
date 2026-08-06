# Copyright 1999-2023 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8
inherit go-module

DESCRIPTION="A tool to scrape a Prometheus client and dump the result as JSON"
HOMEPAGE="https://github.com/prometheus/prom2json"
# creating vendor bundle:
# git clone https://github.com/prometheus/prom2json -b v<version> /tmp/prom2json && \
# cd /tmp/prom2json && version=`git describe --tags | sed -E "s/v([0-9.]+)/\1/g"`; \
# go mod vendor && mkdir prom2json-${version} && mv vendor prom2json-${version}/vendor && \
# tar -c -I 'xz -9 -T0' -f vendor-prom2json-${version}.tar.xz prom2json-${version}/vendor
SRC_URI="
	https://github.com/prometheus/prom2json/archive/v${PV}.tar.gz -> ${P}.tar.gz
	https://vendors.simple-co.de/${PN}/vendor-${P}.tar.xz
"

LICENSE="Apache-2.0"
SLOT="0"
IUSE=""
KEYWORDS="~amd64"

BDEPEND="dev-util/promu"

src_prepare() {
	default
	sed -i \
		-e "s/{{.Revision}}/${PR}/" \
		-e "s/{{.Version}}/${PV}/" \
		.promu.yml || die
}

src_compile() {
	promu build -v --prefix bin || die
}

src_install() {
	dobin bin/*
	dodoc {README,CONTRIBUTING}.md
}

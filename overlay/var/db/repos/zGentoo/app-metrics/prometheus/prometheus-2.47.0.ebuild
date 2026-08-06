# Copyright 1999-2023 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8
inherit go-module systemd

DESCRIPTION="Prometheus monitoring system and time series database"
HOMEPAGE="https://github.com/prometheus/prometheus"

go-module_set_globals
SRC_URI="
	https://github.com/prometheus/prometheus/archive/v${PV/_rc/-rc.}.tar.gz -> ${P}.tar.gz
	https://vendors.simple-co.de/${PN}/vendor-${P}.tar.xz
	https://vendors.simple-co.de/${PN}/node-modules-${P}.tar.xz
	https://vendors.simple-co.de/${PN}/package-lock-${P}.json.gz
"
# default vendor package created using:
# >> git clone https://github.com/prometheus/prometheus/ -b v<version> /tmp/prometheus && \
# >> cd /tmp/prometheus && version=`git describe --tags | sed -E "s/v([0-9.]+)/\1/g"`; \
# >> go mod vendor && tar -c -I 'xz -9 -T0' -f vendor-prometheus-${version}.tar.xz vendor
# default node_modules package-lock created using:
# >> make ui-build; cd web/ui && npm i && version=`git describe --tags | sed -E "s/v([0-9.]+)/\1/g"`; \
# >> tar -c -I 'xz -9 -T0' -f node-modules-prometheus-${version}.tar.xz node_modules && \
# >> gzip -c package-lock.json > package-lock-prometheus-${version}.json.gz
# HINT: something is wrong with their tags (for example, v2.39.0 would be shown as: v0.39.0 ..)
LICENSE="Apache-2.0 MPL-2.0 BSD-2 BSD-3 ISC MIT"
SLOT="0"
KEYWORDS="amd64 ~arm"

COMMON_DEPEND="
	acct-group/prometheus
	acct-user/prometheus"
DEPEND="
	!app-metrics/prometheus-bin
	${COMMON_DEPEND}"
RDEPEND="${COMMON_DEPEND}"
BDEPEND="
	net-libs/nodejs
	dev-util/promu"

RESTRICT+=" test"

src_unpack() {
	default
	mv vendor ${S}/vendor || die
	mv node_modules ${S}/web/ui/node_modules || die
	mv package-lock-${P}.json ${S}/web/ui/package-lock.json
}

src_prepare() {
	default
	sed -i \
		-e "s/{{.Branch}}/HEAD/" \
		-e "s/{{.Revision}}/${PR}/" \
		-e "s/{{.Version}}/${PV}/" \
		.promu.yml || die
	
	# correcting broken build-script (depends on global rollup, we're fixing this)
	sed -i -e "s/rollup/npx rollup/g" web/ui/module/lezer-promql/build.sh \
		|| die couldn\'t patch the broken buildscript
}

src_compile() {
	# building ui and assets (needs node, node_modules are shipped)
	emake assets-compress
	# compiles the final application
	promu build -v --prefix bin || die
}

src_install() {
	dobin bin/*
	dodoc -r {documentation,{README,CHANGELOG,CONTRIBUTING}.md}
	insinto /etc/prometheus
	doins documentation/examples/prometheus.yml
	insinto /usr/share/prometheus
	doins -r console_libraries consoles
	dosym ../../usr/share/prometheus/console_libraries /etc/prometheus/console_libraries
	dosym ../../usr/share/prometheus/consoles /etc/prometheus/consoles

	systemd_dounit "${FILESDIR}"/prometheus.service
	newinitd "${FILESDIR}"/prometheus.initd prometheus
	newconfd "${FILESDIR}"/prometheus.confd prometheus
	keepdir /var/log/prometheus /var/lib/prometheus
	fowners prometheus:prometheus /var/log/prometheus /var/lib/prometheus
}

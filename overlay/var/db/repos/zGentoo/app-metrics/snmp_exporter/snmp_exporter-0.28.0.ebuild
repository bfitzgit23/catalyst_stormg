# Copyright 1999-2023 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8
inherit systemd go-module

DESCRIPTION="Prometheus exporter for snmp metrics"
HOMEPAGE="https://github.com/prometheus/snmp_exporter"

# creating vendor bundle:
# >> git clone https://github.com/prometheus/snmp_exporter -b v<version> /tmp/snmp_exporter
# >> cd /tmp/snmp_exporter && version=`git describe --tags | sed -E "s/v([0-9.]+)/\1/g"`
# >> go mod vendor && mkdir snmp_exporter-${version} && mv vendor snmp_exporter-${version}/vendor
# >> tar -caf snmp_exporter-${version}-vendor.tar.xz snmp_exporter-${version}/vendor

SRC_URI="
	https://github.com/prometheus/snmp_exporter/archive/v${PV/_rc/-rc.}.tar.gz -> ${P}.tar.gz
	https://vendors.simple-co.de/${PN}/${P}-vendor.tar.xz
"

KEYWORDS="~amd64"
LICENSE="Apache-2.0 BSD BSD-2 MIT"
SLOT="0"
IUSE="systemd"
RESTRICT="test"

BDEPEND="dev-util/promu"
DEPEND="
	net-analyzer/net-snmp
	acct-group/${PN}
	acct-user/${PN}
"

src_prepare() {
	default
	sed -i -e "s/{{.Version}}/${PV}/" .promu.yml || die
	sed -i -e "s/{{.Revision}}/${PR}/" .promu.yml || die
}

src_compile() {
	promu build --prefix bin || die
	mv bin/${P} bin/${PN}
	GOPATH="${S}/generator" ego build -o bin/generator
}

src_install() {
	# install binaries
	dobin bin/*

	# install docs (all md's and generator.yml)
	dodoc {*.md,generator/*.{md,yml}}

	# install configurations
	insinto /etc/${PN}
	newins snmp.yml{,.example}

	# install logrotate configuration
	insinto /etc/logrotate.d
	newins "${FILESDIR}/${PN}.logrotated" "${PN}"

	# set lib/log permissions
	keepdir /var/lib/${PN} /var/log/${PN}
	fowners ${PN}:${PN} /var/lib/${PN} /var/log/${PN}

	# installing environment and services (systemd/openrc)
	if use systemd; then
		systemd_newunit "${FILESDIR}"/${PN}.service ${PN}.service
		systemd_install_serviced "${FILESDIR}"/${PN}.conf ${PN}.service
	else
		newconfd "${FILESDIR}"/${PN}.confd ${PN}
		newinitd "${FILESDIR}"/${PN}.initd ${PN}
	fi
}

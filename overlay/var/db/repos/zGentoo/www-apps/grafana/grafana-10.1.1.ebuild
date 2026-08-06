# Copyright 1999-2023 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit check-reqs go-module systemd tmpfiles

MY_PV=${PV/_beta/-beta}
S=${WORKDIR}/${PN}-${MY_PV}

DESCRIPTION="The open-source platform for monitoring and observability"
HOMEPAGE="https://grafana.com"
SRC_URI="
	https://github.com/grafana/grafana/archive/v${MY_PV}.tar.gz -> ${P}.tar.gz
	https://vendors.simple-co.de/${PN}/vendor-${P}.tar.xz
	https://vendors.simple-co.de/${PN}/vendor_yarn-${P}.tar.xz
"
LICENSE="AGPL-3.0 Apache-2.0 BSD-2 BSD-3 BSD-4 BSL-1.0 ImageMagick ISC LGPL-3.0 MIT MPL-2.0 OpenSSL Zlib"
SLOT="10/"${PV}
KEYWORDS="~amd64"
IUSE="systemd"

# needed for webpack (nodejs)
CHECKREQS_MEMORY="8G"

DEPEND="!www-apps/${PN}-bin
	acct-group/${PN}
	acct-user/${PN}
	media-libs/fontconfig
	|| (
		net-libs/nodejs:0/18[icu]
		<net-libs/nodejs-20.6.0[icu]
	)
	sys-apps/yarn
	>=dev-lang/go-1.20
	dev-go/wire"

PN_S="${PN}-${SLOT%/*}"

src_unpack() {
	default
	mv vendor "${S}/vendor"
	mv vendor_yarn "${S}/vendor_yarn"
}

src_prepare() {
	sed -i "s:;reporting_enabled = .*:reporting_enabled = false:" \
		conf/sample.ini || die "prepare failed"
	sed -i "s:;check_for_updates = .*:check_for_updates = false:" \
		conf/sample.ini || die "prepare failed"

	mkdir "plugins-bundled/external"

	## offline/cache installation
	echo -e "enableMirror: true\ncacheFolder: ./vendor_yarn" >> .yarnrc.yml

	## preparing files (and replace the version)
	mkdir -p "files"
	cp -a "${FILESDIR}/${PN}".* files || die "coudln't copy needed files!"
	sed -i "s/~PN_S~/${PN_S}/g" files/* || die "couldn't apply slot-patches!"

	default
}

src_compile() {
	addpredict /etc/npm

	## install yarn deps(offline)..
	CYPRESS_INSTALL_BINARY=0 yarn install >/dev/null 2>&1 || die "prepare failed"

	einfo "Wiring everything up.."
	wire gen -tags oss ./pkg/server ./pkg/cmd/grafana-cli/runner || die "wiring failed"
	einfo "Building binaries using go.."
	go run -mod=vendor build.go build || die "compile failed"
	einfo "Building frontend using webpack.."
	# beware, we need at least 8G RAM (@32T)
	export NODE_OPTIONS="--max-old-space-size=8192"
	yarn run build || die "compile failed"
	yarn run plugins:build-bundled || die "compile failed"
}

src_install() {
	insinto /etc/${PN_S}
	newins conf/sample.ini ${PN}.ini
	newins conf/ldap.toml ldap.toml

	newbin `(find bin -name ${PN})` ${PN_S}
	newbin `(find bin -name ${PN}-cli)` ${PN_S}-cli
	newbin `(find bin -name ${PN}-server)` ${PN_S}-server

	# new since grafana 10..
	# this requires an eselect-grafana plugin when v11 is realeased
	dosym /usr/bin/${PN_S} /usr/bin/${PN}

	insinto "/usr/share/${PN_S}"
	doins -r public conf tools

	newconfd "${S}/files/${PN}.confd" "${PN_S}"
	newinitd "${S}/files/${PN}.initd" "${PN_S}"
	use systemd && systemd_newunit "${S}/files/${PN}.service" "${PN_S}.service"

	newtmpfiles "${S}/files"/${PN}.conf ${PN_S}.conf

	keepdir /var/{lib,log}/${PN_S}
	fowners ${PN}:${PN} /var/{lib,log}/${PN_S}
	fperms 0750 /var/{lib,log}/${PN_S}

	keepdir /var/lib/${PN_S}/{dashboards,plugins}
	fowners ${PN}:${PN} /var/lib/${PN_S}/{dashboards,plugins}
	fperms 0750 /var/lib/${PN_S}/{dashboards,plugins}

	keepdir /etc/${PN_S}
	fowners ${PN}:${PN} /etc/${PN_S}/{${PN}.ini,ldap.toml}
	fperms 0640 /etc/${PN_S}/{${PN}.ini,ldap.toml}
}

pkg_postinst() {
	tmpfiles_process ${PN_S}.conf

	if [ -d /var/lib/${PN} ]; then
		# found non-slotted grafana installation
		ewarn "We found an old ${PN} installation in '/var/lib/${PN}'!"
		ewarn "Make sure to adjust the confs and do a data-migration, the"
		ewarn "new ${PN} data-dir is '/var/lib/${PN_S}'."
	fi

	einfo "${PN} has built-in log rotation. Please see [log.file] section of"
	einfo "/etc/${PN_S}/${PN}.ini for related settings."
	einfo
	einfo "You may add your own custom configuration for app-admin/logrotate if you"
	einfo "wish to use external rotation of logs. In this case, you also need to make"
	einfo "sure the built-in rotation is turned off."
}

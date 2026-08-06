# Copyright 1999-2024 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit check-reqs go-module systemd tmpfiles

MY_PV=${PV/_beta/-beta}
S=${WORKDIR}/${PN}-${MY_PV}

DESCRIPTION="The open-source platform for monitoring and observability"
HOMEPAGE="https://grafana.com"
yarn_version="4.3.1"

## building (yarn_)vendor
# >> git clone https://github.com/grafana/grafana -b v<version> /tmp/grafana
# >> cd /tmp/grafana && version=`git describe --tags | sed -E "s/v([0-9.]+)/\1/g"`
# >> GOWORK=off go mod vendor && go work vendor && mkdir grafana-${version} && mv vendor grafana-${version}/vendor
# >> tar -caf grafana-${version}-vendor.tar.xz grafana-${version}/vendor
# >> echo -e "enableMirror: true\ncacheFolder: ./vendor_yarn" >> .yarnrc.yml
# >> CYPRESS_INSTALL_BINARY=0 yarn set version 4.3.*
# >> CYPRESS_INSTALL_BINARY=0 yarn cache clean --mirror && yarn install
# >> mv vendor_yarn grafana-${version}/vendor_yarn
# >> tar -caf grafana-${version}-vendor_yarn.tar.xz grafana-${version}/vendor_yarn

SRC_URI="
    https://github.com/grafana/grafana/archive/v${MY_PV}.tar.gz -> ${P}.tar.gz
    https://vendors.simple-co.de/${PN}/${P}-vendor.tar.xz
    https://vendors.simple-co.de/${PN}/${P}-vendor_yarn.tar.xz
    https://repo.yarnpkg.com/${yarn_version}/packages/yarnpkg-cli/bin/yarn.js -> yarn-${yarn_version}.cjs
"
LICENSE="AGPL-3.0 Apache-2.0 BSD-2 BSD-3 BSD-4 BSL-1.0 ImageMagick ISC LGPL-3.0 MIT MPL-2.0 OpenSSL Zlib"
SLOT="10/"${PV}
KEYWORDS="~amd64"
IUSE="systemd"
RESTRICT="mirror test" # tests are not working (a proper fix would take to long)

# needed for webpack (nodejs)
CHECKREQS_MEMORY="8G"

DEPEND="!www-apps/${PN}-bin
    acct-group/${PN}
    acct-user/${PN}
    media-libs/fontconfig
    net-libs/nodejs[icu]
    sys-apps/yarn
    >=dev-lang/go-1.20
    >=dev-go/wire-0.6.0"

PN_S="${PN}-${SLOT%/*}"

src_prepare() {
    sed -i "s:;reporting_enabled = .*:reporting_enabled = false:" \
        conf/sample.ini || die "prepare failed"
    sed -i "s:;check_for_updates = .*:check_for_updates = false:" \
        conf/sample.ini || die "prepare failed"

    mkdir "plugins-bundled/external"

    ## offline/cache installation
    echo -e "enableMirror: true\ncacheFolder: ./vendor_yarn" >> .yarnrc.yml
    sed -i '/^yarnPath/d' .yarnrc.yml
    echo "yarnPath: .yarn/releases/yarn-${yarn_version}.cjs" >> .yarnrc.yml
    cp ${DISTDIR}/yarn-${yarn_version}.cjs .yarn/releases/ || die "could not copy yarn-${yarn_version}.cjs"

    ## preparing files (and replace the version)
    mkdir -p "files"
    cp -a "${FILESDIR}/${PN}".* files || die "coudln't copy needed files!"
    sed -i "s/~PN_S~/${PN_S}/g" files/* || die "couldn't apply slot-patches!"

    ## setting build-info
    sed -i 's/unknown-dev/gentoo/g' pkg/build/git.go

    default
}

src_compile() {
    ## install yarn deps(offline)..
    CYPRESS_INSTALL_BINARY=0 yarn install || die "prepare failed"

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

    exeinto /usr/libexec/${PN_S}
    newexe `(find bin -name ${PN})` ${PN}
    ## legacy
    newexe `(find bin -name ${PN}-cli)` ${PN}-cli
    newexe `(find bin -name ${PN}-server)` ${PN}-server

    exeinto /usr/bin
    echo -e "#"'!'"/bin/sh\nPATH=\"/usr/libexec/${PN_S}:\${PATH}\" && ${PN} \$@" >> ${D}/usr/bin/${PN_S}
    echo -e "#"'!'"/bin/sh\nPATH=\"/usr/libexec/${PN_S}:\${PATH}\" && ${PN} cli --homepath /var/lib/${PN_S} --pluginsDir /var/lib/${PN_S}/plugins \$@" >> ${D}/usr/bin/${PN_S}-cli
    echo -e "#"'!'"/bin/sh\nPATH=\"/usr/libexec/${PN_S}:\${PATH}\" && ${PN} server --homepath /var/lib/${PN_S} \$@" >> ${D}/usr/bin/${PN_S}-server

    fperms +x /usr/bin/${PN_S}
    fperms +x /usr/bin/${PN_S}-cli
    fperms +x /usr/bin/${PN_S}-server

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
